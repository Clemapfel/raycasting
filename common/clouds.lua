require "common.texture_format"
require "common.render_texture_volume"
require "common.shader"
require "common.compute_shader"

rt.settings.clouds = {
    volume_texture_format = rt.TextureFormat.R32F,
    export_texture_format = rt.TextureFormat.R8,
    volume_texture_anisotropy = 1,
    max_n_slices = 8,
    work_group_size_x = 8,
    work_group_size_y = 8,
    work_group_size_z = 4,

    n_density_steps = 64,
    density_step_size = 0.01, -- in uv space
    n_shadow_steps = 64,
    shadow_step_size = 0.01

}

--- @class rt.Clouds
rt.Clouds = meta.class("Clouds")

local _draw_mesh_format = {
    { location = 0, name = "position", format = "floatvec3" },
    { location = 1, name = "texture_coords", format = "floatvec3" },
    { location = 2, name = "color", format = "floatvec4" },
}

local _fill_volume_texture_shader, _raymarch_shader
do
    local settings = rt.settings.clouds
    _fill_volume_texture_shader = rt.ComputeShader("common/clouds_compute.glsl", {
        MODE = 0,
        WORK_GROUP_SIZE_X = settings.work_group_size_x,
        WORK_GROUP_SIZE_Y = settings.work_group_size_y,
        WORK_GROUP_SIZE_Z = settings.work_group_size_z,
        VOLUME_TEXTURE_FORMAT = settings.volume_texture_format
    })

    _raymarch_shader = rt.ComputeShader("common/clouds_compute.glsl", {
        MODE = 1,
        WORK_GROUP_SIZE_X = settings.work_group_size_x,
        WORK_GROUP_SIZE_Y = settings.work_group_size_y,
        WORK_GROUP_SIZE_Z = settings.work_group_size_z,
        VOLUME_TEXTURE_FORMAT = settings.volume_texture_format,
        EXPORT_TEXTURE_FORMAT = settings.export_texture_format,
        MAX_N_EXPORT_TEXTURES = settings.max_n_slices
    })
end

--- @brief
--- @param x Number
--- @param y Number
--- @param z Number
--- @param size_x Number
--- @param size_y Number
--- @param size_z Number
function rt.Clouds:instantiate(n_slices, resolution_x, resolution_y, resolution_z)
    n_slices = rt.settings.clouds.max_n_slices

    meta.assert(
        n_slices, "Number",
        resolution_x, "Number",
        resolution_y, "Number",
        resolution_z, "Number"
    )

    self._resolution_x = resolution_x
    self._resolution_y = resolution_y
    self._resolution_z = resolution_z

    self._noise_offset_x = 0
    self._noise_offset_y = 0
    self._noise_offset_z = 0
    self._noise_offset_time = 0

    local max_n_slices = rt.settings.clouds.max_n_slices
    if n_slices > max_n_slices then
        rt.critical("In rt.Clouds: argument #1 is `", n_slices, "`, but rt.Clouds can only have a maximum of `", max_n_slices, "` slices")
        n_slices = max_n_slices
    end

    self._is_realized = false
    self._n_slices = n_slices
    self._volume_texture = nil
    self._slices = {}

    self:_init_slices()
    self:_init_volume_texture()

    self:_update_volume_texture()
    self:_update_slice_textures()

    -- TODO
    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _raymarch_shader:recompile()
            _fill_volume_texture_shader:recompile()
        end
    end)
end

--- @brief
function rt.Clouds:get_texture(i)
    if i == nil then i = 1 end

    local entry = self._slices[i]
    if entry == nil then
        rt.error("In rt.Clouds: trying to access texture #", i, " but clouds only has ", self._n_slices, " slices")
    end

    return entry.canvas
end

--- @brief
function rt.Clouds:realize()
    if self._is_realized == true then return end

    self._is_realized = true
end

--- @brief
function rt.Clouds:set_offset(x, y, z, time)
    local recompute = (x ~= nil and self._noise_offset_x ~= x)
        or (y ~= nil and self._noise_offset_y ~= y)
        or (z ~= nil and self._noise_offset_z ~= z)
        or (time ~= nil and self._noise_offset_time ~= time)

    self._noise_offset_x = x or self._noise_offset_x
    self._noise_offset_y = y or self._noise_offset_y
    self._noise_offset_z = z or self._noise_offset_z
    self._noise_offset_time = time or self._noise_offset_time

    if recompute then
        self:_update_volume_texture()
        self:_update_slice_textures()
    end
end

--- @brief
function rt.Clouds:_init_volume_texture()
    local n_layers = rt.settings.clouds.n_layeres
    local texture_config = {
        self._resolution_x,
        self._resolution_y,
        self._resolution_z,
        0, -- msaa
        rt.settings.clouds.volume_texture_format,
        true -- compute writable
    }

    self._volume_texture = rt.RenderTextureVolume(table.unpack(texture_config))

    self._volume_texture:set_scale_mode(
        rt.TextureScaleMode.LINEAR,
        rt.TextureScaleMode.LINEAR,
        rt.settings.clouds.volume_texture_anisotropy
    )

    self._volume_texture:set_wrap_mode(
        rt.TextureWrapMode.ZERO
    )
end

--- @brief
function rt.Clouds:_update_volume_texture()
    _fill_volume_texture_shader:send("noise_offset", {
        self._noise_offset_x,
        self._noise_offset_y,
        self._noise_offset_z
    })
    _fill_volume_texture_shader:send("time_offset", self._noise_offset_time)
    _fill_volume_texture_shader:send("volume_texture", self._volume_texture:get_native())

    local settings = rt.settings.clouds
    local size_x, size_y, size_z = self._volume_texture:get_size()
    local dispatch_x = math.ceil(size_x / settings.work_group_size_x)
    local dispatch_y = math.ceil(size_y / settings.work_group_size_y)
    local dispatch_z = math.ceil(size_z / settings.work_group_size_z)
    _fill_volume_texture_shader:dispatch(dispatch_x, dispatch_y, dispatch_z)

    --[[
    _compute_gradient_shader:send("volume_texture", self._volume_texture:get_native())
    _compute_gradient_shader:dispatch(dispatch_x, dispatch_y, dispatch_z)
    ]]--
end

--- @brief
function rt.Clouds:_create_draw_mesh(slice_i)
    local data = {}
    local vertex_map = {}

    local bounds = self._bounds
    local x, y = 0, 0
    local x0, x1 = x, x + self._resolution_x
    local y0, y1 = y, y + self._resolution_y

    local t = (self._n_slices > 1) and (slice_i / (self._n_slices - 1)) or 0.5
    local z = 0
    local w = t -- normalized texture z coordinate

    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, slice_i / self._n_slices, 1)

    table.insert(data, {x0, y0, z, 0, 0, w, r, g, b, a})
    table.insert(data, {x1, y0, z, 1, 0, w, r, g, b, a})
    table.insert(data, {x1, y1, z, 1, 1, w, r, g, b, a})
    table.insert(data, {x0, y1, z, 0, 1, w, r, g, b, a})

    local mesh = rt.Mesh(
        data,
        rt.MeshDrawMode.TRIANGLES,
        _draw_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    mesh:set_vertex_map({ 1, 2, 3, 1, 3, 4 })
    return mesh
end

--- @brief
function rt.Clouds:_init_slices()
    self._slices = {}
    self._export_textures = {}
    for slice_i = 1, self._n_slices do
        local entry = {
            canvas = rt.RenderTexture(
                self._resolution_x,
                self._resolution_y,
                0, -- msaa
                rt.settings.clouds.export_texture_format,
                true -- computewrite
            ),

            mesh = self:_create_draw_mesh(
                slice_i
            ),

            needs_update = true
        }

        entry.mesh:set_texture(entry.canvas)
        entry.canvas:set_scale_mode(
            rt.TextureScaleMode.LINEAR,
            rt.TextureScaleMode.LINEAR,
            4 -- anisotropy
        )
        table.insert(self._slices, entry)
        table.insert(self._export_textures, entry.canvas:get_native())
    end

    self._export_texture = love.graphics.newArrayImage(
        self._resolution_x,
        self._resolution_y,
        self._n_slices, {
            msaa = 0,
            format = rt.settings.clouds.export_texture_format,
            computewrite = true,
            mipmaps = false,
            canvas = true
        }
    )
end

--- @brief
function rt.Clouds:_update_slice_textures()
    local settings = rt.settings.clouds
    _raymarch_shader:send("volume_texture", self._volume_texture:get_native())
    _raymarch_shader:send("export_textures", table.unpack(self._export_textures))
    _raymarch_shader:send("n_export_textures", #self._export_textures)
    _raymarch_shader:send("ray_direction", { 0, 0, 1 }) -- ray offset is 3d texture coords
    _raymarch_shader:send("n_density_steps", settings.n_density_steps)
    _raymarch_shader:send("density_step_size", settings.density_step_size)
    _raymarch_shader:send("n_shadow_steps", settings.n_shadow_steps)
    _raymarch_shader:send("shadow_step_size", settings.shadow_step_size)

    local settings = rt.settings.clouds
    local size_x, size_y, size_z = self._volume_texture:get_size()
    local dispatch_x = math.ceil(size_x / settings.work_group_size_x)
    local dispatch_y = math.ceil(size_y / settings.work_group_size_y)
    local dispatch_z = math.ceil(size_z / settings.work_group_size_z)
    _raymarch_shader:dispatch(dispatch_x, dispatch_y, dispatch_z)
end

--- @brief
function rt.Clouds:get_n_slices()
    return self._n_slices
end