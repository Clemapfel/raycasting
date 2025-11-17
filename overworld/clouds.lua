require "common.texture_format"
require "common.render_texture_volume"
require "common.render_texture_array"
require "common.shader"
require "common.compute_shader"

rt.settings.overworld.clouds = {
    volume_texture_format = rt.TextureFormat.R32F,
    export_texture_format = rt.TextureFormat.R8,
    volume_texture_anisotropy = 1,
    work_group_size_x = 8,
    work_group_size_y = 8,
    work_group_size_z = 4,

    n_density_steps = 64,
    density_step_size = 0.01, -- in uv space
    n_shadow_steps = 64,
    shadow_step_size = 0.01,
    n_slices = 8,

    whiteness = 10, -- rgb multiplier
    opacity = 0.5, -- a multiplier
    hue_offset = 0.25 -- min/max hue of cloud, +/- player hue
}

--- @class ow.Clouds
ow.Clouds = meta.class("Clouds")

local _draw_mesh_format = {
    { location = 0, name = "position", format = "floatvec3" },
    { location = 1, name = "texture_coords", format = "floatvec3" },
    { location = 2, name = "color", format = "floatvec4" },
}

local _fill_volume_texture_shader, _raymarch_shader, _draw_shader
do
    local settings = rt.settings.overworld.clouds
    _fill_volume_texture_shader = rt.ComputeShader("overworld/clouds_compute.glsl", {
        MODE = 0,
        WORK_GROUP_SIZE_X = settings.work_group_size_x,
        WORK_GROUP_SIZE_Y = settings.work_group_size_y,
        WORK_GROUP_SIZE_Z = settings.work_group_size_z,
        VOLUME_TEXTURE_FORMAT = settings.volume_texture_format
    })

    _raymarch_shader = rt.ComputeShader("overworld/clouds_compute.glsl", {
        MODE = 1,
        WORK_GROUP_SIZE_X = settings.work_group_size_x,
        WORK_GROUP_SIZE_Y = settings.work_group_size_y,
        WORK_GROUP_SIZE_Z = settings.work_group_size_z,
        VOLUME_TEXTURE_FORMAT = settings.volume_texture_format,
        EXPORT_TEXTURE_FORMAT = settings.export_texture_format
    })

    _draw_shader = rt.Shader("overworld/clouds_draw.glsl")
end

--- @brief
function ow.Clouds:instantiate(
    n_slices,
    resolution_x, resolution_y, resolution_z,
    x, y, z,
    size_x, size_y, size_z,
    fov,
    offset_x, offset_y, offset_z, offset_w
)
    self._resolution_x = resolution_x
    self._resolution_y = resolution_y
    self._resolution_z = resolution_z

    self._bounds = {
        x = x,
        y = y,
        z = z,
        size_x = size_x,
        size_y = size_y,
        size_z = size_z
    }

    self._noise_offset_x = offset_x or 0
    self._noise_offset_y = offset_y or 0
    self._noise_offset_z = offset_z or 0
    self._noise_offset_time = offset_w or 0

    self._hue = 0

    self._is_realized = false
    self._n_slices = n_slices
    self._volume_texture = nil
    self._slices = {}

    self:_init_slices()
    self:_init_volume_texture()

    self:_init_draw_mesh(
        self._bounds.size_x,
        self._bounds.size_y,
        fov
    )

    self:_update_volume_texture()
    self:_update_slice_textures()

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            for shader in range(
                _fill_volume_texture_shader,
                _raymarch_shader,
                _draw_shader
            ) do
                shader:recompile()
            end

            self:set_offset(
                self._noise_offset_x,
                self._noise_offset_y,
                self._noise_offset_z,
                self._noise_offset_time,
                true
            )
        end
    end)
end

--- @brief
function ow.Clouds:get_texture(i)
    if i == nil then i = 1 end

    local entry = self._slices[i]
    if entry == nil then
        rt.error("In ow.Clouds: trying to access texture #", i, " but clouds only has ", self._n_slices, " slices")
    end

    return entry.canvas
end

--- @brief
function ow.Clouds:realize()
    if self._is_realized == true then return end
    self._is_realized = true
end

--- @brief
function ow.Clouds:set_offset(x, y, z, time, force_recompute)
    local recompute = (x ~= nil and self._noise_offset_x ~= x)
        or (y ~= nil and self._noise_offset_y ~= y)
        or (z ~= nil and self._noise_offset_z ~= z)
        or (time ~= nil and self._noise_offset_time ~= time)

    self._noise_offset_x = x or self._noise_offset_x
    self._noise_offset_y = y or self._noise_offset_y
    self._noise_offset_z = z or self._noise_offset_z
    self._noise_offset_time = time or self._noise_offset_time

    if recompute or force_recompute == true then
        self:_update_volume_texture()
        self:_update_slice_textures()
    end
end

--- @brief
function ow.Clouds:_init_volume_texture()
    local n_layers = rt.settings.overworld.clouds.n_layeres
    local texture_config = {
        self._resolution_x,
        self._resolution_y,
        self._resolution_z,
        0, -- msaa
        rt.settings.overworld.clouds.volume_texture_format,
        true -- compute writable
    }

    self._volume_texture = rt.RenderTextureVolume(table.unpack(texture_config))

    self._volume_texture:set_scale_mode(
        rt.TextureScaleMode.LINEAR,
        rt.TextureScaleMode.LINEAR,
        rt.settings.overworld.clouds.volume_texture_anisotropy
    )

    self._volume_texture:set_wrap_mode(
        rt.TextureWrapMode.ZERO
    )
end

--- @brief
function ow.Clouds:_update_volume_texture()
    _fill_volume_texture_shader:send("noise_offset", {
        self._noise_offset_x,
        self._noise_offset_y,
        self._noise_offset_z
    })
    _fill_volume_texture_shader:send("time_offset", self._noise_offset_time)
    _fill_volume_texture_shader:send("volume_texture", self._volume_texture:get_native())

    local settings = rt.settings.overworld.clouds
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
function ow.Clouds:_init_draw_mesh(size_x, size_y, fov)
    -- Build a layered mesh where each slice is scaled to fill the camera frustum
    -- using the provided vertical FOV. If self._view_from_world (4x4) is present,
    -- we transform slice centers into view space and use the view-space depth for scaling.
    --
    -- Assumptions:
    -- - The camera looks along -Z in view space.
    -- - size_x,size_y correspond to the near-plane rectangle that fills the screen.
    -- - Slices are centered around the same on-screen center and expand with depth.
    local data = {}
    local vertex_map = {}

    local bounds = self._bounds
    local aspect = size_x / size_y
    local tan_half_fov = math.tan(fov / 2) * 0.5

    -- Compute an equivalent near distance from provided plane sizes so that
    -- scaled size at near equals size_x/size_y. Using both X and Y-derived near distances
    -- and picking the larger ensures coverage in both axes.
    local near_d_y = size_y / (2 * tan_half_fov)
    local near_d_x = size_x / (2 * tan_half_fov * aspect)
    local near_d = math.max(near_d_x, near_d_y, 1e-6)

    -- Optional view transform support (4x4, column-major expected). If not provided, identity.
    local view_from_world = self._view_from_world
    local function transform_to_view_space(x, y, z)
        if type(view_from_world) ~= "table" then
            return x, y, z
        end
        -- Column-major 4x4 multiplication with vec4(x,y,z,1)
        local m = view_from_world
        local vx = m[1] * x + m[5] * y + m[9]  * z + m[13]
        local vy = m[2] * x + m[6] * y + m[10] * z + m[14]
        local vz = m[3] * x + m[7] * y + m[11] * z + m[15]
        local vw = m[4] * x + m[8] * y + m[12] * z + m[16]
        if vw ~= nil and vw ~= 0 then
            vx, vy, vz = vx / vw, vy / vw, vz / vw
        end
        return vx, vy, vz
    end

    -- Center of the near plane in world space; we keep all slices centered around this.
    local plane_cx = bounds.x + size_x * 0.5
    local plane_cy = bounds.y + size_y * 0.5

    local min_uv_u, max_uv_u = 0, 1-- -1, 1
    local min_uv_v, max_uv_v = 0, 2

    for i = self._n_slices, 1, -1 do
        -- Slice depth in world space
        local z_normalized = (i - 0.5) / self._n_slices
        local z_world = bounds.z + z_normalized * bounds.size_z
        local layer_index = i - 1

        -- Determine view-space depth for scaling. We only need |z| to compute scale,
        -- assuming camera looks down -Z; abs handles both conventions robustly.
        local _, _, z_view = transform_to_view_space(plane_cx, plane_cy, z_world)
        local depth = math.max(math.abs(z_view), 1e-6)

        -- Scale factor so that at near depth we have size_x/size_y, and it grows linearly with depth.
        local s = depth / near_d
        local scaled_width = size_x * s
        local scaled_height = size_y * s

        local left_x = -scaled_width
        local right_x = scaled_width

        local top_y = 0
        local bottom_y = -scaled_height

        -- Position the quad so its center stays fixed on the near-plane center.
        local x0 = plane_cx - scaled_width * 0.5
        local y0 = plane_cy - scaled_height * 0.5

        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, i / self._n_slices, 1)
        local base_index = #data

        -- Note: texture coords range from (1,1) top-left to (0,0) bottom-right as before
        table.insert(data, { x0 + left_x,                  y0 + bottom_y,                  z_world, max_uv_u, max_uv_v, layer_index, r, g, b, a })
        table.insert(data, { x0 + scaled_width + right_x,  y0 + bottom_y,                   z_world, min_uv_u, max_uv_v, layer_index, r, g, b, a })
        table.insert(data, { x0 + scaled_width + right_x,  y0 + scaled_height + top_y,  z_world, min_uv_u, min_uv_v, layer_index, r, g, b, a })
        table.insert(data, { x0 + left_x,                  y0 + scaled_height + top_y,  z_world, max_uv_u, min_uv_v, layer_index, r, g, b, a })

        table.insert(vertex_map, base_index + 1)
        table.insert(vertex_map, base_index + 2)
        table.insert(vertex_map, base_index + 3)

        table.insert(vertex_map, base_index + 1)
        table.insert(vertex_map, base_index + 3)
        table.insert(vertex_map, base_index + 4)
    end

    local mesh = rt.Mesh(
        data,
        rt.MeshDrawMode.TRIANGLES,
        _draw_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    mesh:set_vertex_map(vertex_map)
    mesh:set_texture(self._export_texture)
    self._draw_mesh = mesh
    return mesh
end

--[[
function ow.Clouds:_init_draw_mesh()
    local data = {}
    local vertex_map = {}

    local bounds = self._bounds
    local z_step = bounds.size_z / self._n_slices

    local function add_vertex(x, y, z, u, v, w, r, g, b, a)
        table.insert(data, { x, y, z, u, v, w, r, g, b, a })
    end

    for i = self._n_slices, 1, -1 do
        -- Calculate z position for this slice (centered within its slice region)
        local z_normalized = (i - 0.5) / self._n_slices
        local z = bounds.z + z_normalized * bounds.size_z
        local w = (i - 1) / self._n_slices

        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, i / self._n_slices, 1)
        local base_index = #data

        local x, y, width, height = self._bounds.x, self._bounds.y, self._bounds.size_x, self._bounds.size_y
        add_vertex(x, y, z, 1, 1, width, r, g, b, a)
        add_vertex(x + width, y, z, 0, 1, width, r, g, b, a)
        add_vertex(x + width, y + height, z, 0, 0, width, r, g, b, a)
        add_vertex(x, y + height, z, 1, 0, width, r, g, b, a)

        table.insert(vertex_map, base_index + 1)
        table.insert(vertex_map, base_index + 2)
        table.insert(vertex_map, base_index + 3)

        table.insert(vertex_map, base_index + 1)
        table.insert(vertex_map, base_index + 3)
        table.insert(vertex_map, base_index + 4)
    end

    local mesh = rt.Mesh(
        data,
        rt.MeshDrawMode.TRIANGLES,
        _draw_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    mesh:set_vertex_map(vertex_map)
    mesh:set_texture(self._export_texture)
    self._draw_mesh = mesh
    return mesh
end
]]--

--- @brief
function ow.Clouds:_init_slices()
    self._export_texture = rt.RenderTextureArray(
        self._resolution_x,
        self._resolution_y,
        self._n_slices,
        0, -- msaa,
        rt.settings.overworld.clouds.export_texture_format,
        true -- computewrite
    )

    self._export_texture:set_scale_mode(
        rt.TextureScaleMode.LINEAR,
        rt.TextureScaleMode.LINEAR,
        4 -- anisotropy
    )

    self._export_texture:set_wrap_mode(
        rt.TextureWrapMode.MIRROR
    )
end

--- @brief
function ow.Clouds:_update_slice_textures()
    local settings = rt.settings.overworld.clouds
    _raymarch_shader:send("volume_texture", self._volume_texture:get_native())
    _raymarch_shader:send("export_texture", self._export_texture)
    _raymarch_shader:send("export_texture_n_layers", self._n_slices)
    _raymarch_shader:send("ray_direction", { 0, 0, 1 }) -- ray offset is 3d texture coords
    _raymarch_shader:send("n_density_steps", settings.n_density_steps)
    _raymarch_shader:send("density_step_size", settings.density_step_size)
    _raymarch_shader:send("n_shadow_steps", settings.n_shadow_steps)
    _raymarch_shader:send("shadow_step_size", settings.shadow_step_size)

    local settings = rt.settings.overworld.clouds
    local size_x, size_y, size_z = self._volume_texture:get_size()
    local dispatch_x = math.ceil(size_x / settings.work_group_size_x)
    local dispatch_y = math.ceil(size_y / settings.work_group_size_y)
    local dispatch_z = math.ceil(size_z / settings.work_group_size_z)
    _raymarch_shader:dispatch(dispatch_x, dispatch_y, 1)
end

--- @brief
function ow.Clouds:set_hue(hue)
    self._hue = hue
end

--- @brief
function ow.Clouds:draw()
    _draw_shader:bind()
    _draw_shader:send("export_texture", self._export_texture)
    _draw_shader:send("hue", self._hue)
    _draw_shader:send("n_layers", self._n_slices)
    _draw_shader:send("whiteness", rt.settings.overworld.clouds.whiteness)
    _draw_shader:send("opacity", rt.settings.overworld.clouds.opacity)
    _draw_shader:send("hue_offset", rt.settings.overworld.clouds.hue_offset)
    self._draw_mesh:draw()
    _draw_shader:unbind()
end

--- @brief
function ow.Clouds:get_n_slices()
    return self._n_slices
end