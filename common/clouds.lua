require "common.texture_format"
require "common.render_texture_volume"
require "common.shader"
require "common.compute_shader"

rt.settings.clouds = {
    volume_texture_format = rt.TextureFormat.RG32F,
    volume_texture_anisotropy = 1,
    n_layers = 1
}

--- @class rt.Clouds
rt.Clouds = meta.class("Clouds")

local _draw_mesh_format = {
    { location = 0, name = "position", format = "floatvec3" },
    { location = 1, name = "texture_coords", format = "floatvec3" },
    { location = 2, name = "color", format = "floatvec4" },
}

local _draw_mesh_shader = rt.Shader("common/clouds_draw_mesh.glsl")

local _compute_shader_defines = {
    WORK_GROUP_SIZE_X = 8,
    WORK_GROUP_SIZE_Y = 8,
    WORK_GROUP_SIZE_Z = 4,
    VOLUME_TEXTURE_FORMAT = rt.settings.clouds.volume_texture_format
}

_compute_shader_defines.MODE = 0
local _fill_volume_texture_shader = rt.ComputeShader(
    "common/clouds_compute.glsl",
    _compute_shader_defines
)

_compute_shader_defines.MODE = 1
local _compute_gradient_shader = rt.ComputeShader(
    "common/clouds_compute.glsl",
    _compute_shader_defines
)

--- @brief
--- @param x Number
--- @param y Number
--- @param z Number
--- @param size_x Number
--- @param size_y Number
--- @param size_z Number
function rt.Clouds:instantiate(x, y, z, size_x, size_y, size_z)
    self._bounds = {
        x = x,
        y = y,
        z = z,
        size_x = size_x,
        size_y = size_y,
        size_z = size_z
    }

    self._noise_offset_x = 0
    self._noise_offset_y = 0
    self._noise_offset_z = 0
    self._noise_offset_time = 0

    self._is_realized = false

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _draw_mesh_shader:recompile()
            _fill_volume_texture_shader:recompile()
        end
    end)
end

--- @brief
function rt.Clouds:realize()
    if self._is_realized == true then return end

    self._draw_mesh = nil -- rt.Mesh
    self:_init_draw_mesh(rt.settings.clouds.n_layers)

    self._volume_texture = nil -- love.VolumeText
    self:_init_volume_texture()

    self:_update_volume_texture()

    self._draw_mesh:set_texture(self._volume_texture)
    self._is_realized = true
end

--- @brief
function rt.Clouds:update(delta)
    if self._is_realized ~= true then return end

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
    end
end

--- @brief
function rt.Clouds:draw(camera_position, view_transform_inverse)
    if self._is_realized ~= true then return end

    _draw_mesh_shader:bind()
    _draw_mesh_shader:send("volume_texture", self._volume_texture:get_native())
    _draw_mesh_shader:send("camera_position", camera_position)
    _draw_mesh_shader:send("view_transform_inverse", view_transform_inverse:get_native())

    love.graphics.setColor(1, 1, 1, 1)
    self._draw_mesh:draw()
    _draw_mesh_shader:unbind()
end

--- @brief
--- @brief
function rt.Clouds:_init_draw_mesh(n_layers)
    local data = {}
    local vertex_map = {}

    local bounds = self._bounds
    local x0, x1 = bounds.x - bounds.size_x / 2, bounds.x + bounds.size_x / 2
    local y0, y1 = bounds.y - bounds.size_y / 2, bounds.y + bounds.size_y / 2
    local z0, z1 = bounds.z - bounds.size_z / 2, bounds.z + bounds.size_z / 2

    -- build vertices for each layer (back to front for proper alpha blending)
    for i = n_layers - 1, 0, -1 do
        local t = (n_layers > 1) and (i / (n_layers - 1)) or 0.5  -- center single layer
        local z = z0 + (z1 - z0) * t
        local w = t  -- normalized texture z coordinate

        -- Each quad: 4 vertices, ordered CCW
        local base_index = #data + 1

        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, i / n_layers, 1)

        -- bottom-left
        table.insert(data, {x0, y0, z, 0, 0, w, r, g, b, a})
        -- bottom-right
        table.insert(data, {x1, y0, z, 1, 0, w, r, g, b, a})
        -- top-right
        table.insert(data, {x1, y1, z, 1, 1, w, r, g, b, a})
        -- top-left
        table.insert(data, {x0, y1, z, 0, 1, w, r, g, b, a})

        -- Triangulation (two triangles per quad)
        table.insert(vertex_map, base_index + 0)
        table.insert(vertex_map, base_index + 1)
        table.insert(vertex_map, base_index + 2)

        table.insert(vertex_map, base_index + 0)
        table.insert(vertex_map, base_index + 2)
        table.insert(vertex_map, base_index + 3)
    end

    local mesh = rt.Mesh(
        data,
        rt.MeshDrawMode.TRIANGLES,
        _draw_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    mesh:set_vertex_map(vertex_map)
    self._draw_mesh = mesh
end

--- @brief
function rt.Clouds:_init_volume_texture()
    local n_voxels = 0.25 * math.sqrt(100^3) --math.sqrt(self._bounds.size_x * self._bounds.size_y * self._bounds.size_z)
    local sum = self._bounds.size_x + self._bounds.size_y + self._bounds.size_z

    local n_layers = rt.settings.clouds.n_layeres
    local texture_config = {
        n_voxels * (self._bounds.size_x / sum),
        n_voxels * (self._bounds.size_y / sum),
        n_voxels * (self._bounds.size_z / sum),
        0, -- msaa
        rt.settings.clouds.volume_texture_format,
        true, -- compute readable
        false -- use mipmaps
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

    local defines = _compute_shader_defines
    local size_x, size_y, size_z = self._volume_texture:get_size()
    local dispatch_x = math.ceil(size_x / defines.WORK_GROUP_SIZE_X)
    local dispatch_y = math.ceil(size_y / defines.WORK_GROUP_SIZE_Y)
    local dispatch_z = math.ceil(size_z / defines.WORK_GROUP_SIZE_Z)

    _fill_volume_texture_shader:dispatch(dispatch_x, dispatch_y, dispatch_z)

    _compute_gradient_shader:send("volume_texture", self._volume_texture:get_native())
    _compute_gradient_shader:dispatch(dispatch_x, dispatch_y, dispatch_z)
end