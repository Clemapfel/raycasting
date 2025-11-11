require "common.texture_format"
require "common.render_texture_volume"
require "common.shader"
require "common.compute_shader"

rt.settings.clouds = {
    volume_texture_format = rt.TextureFormat.RGBA16F,
    volume_texture_anisotropy = 4
}

--- @class rt.Clouds
rt.Clouds = meta.class("Clouds")

local _draw_mesh_format = {
    { location = 0, name = "position", format = "floatvec3" },
    { location = 1, name = "texture_coords", format = "floatvec2" },
    { location = 2, name = "color", format = "floatvec4" },
}

local _draw_mesh_shader = rt.Shader("common/clouds_draw_mesh.glsl")

local _fill_volume_texture_shader_defines = {
    WORK_GROUP_SIZE_X = 8,
    WORK_GROUP_SIZE_Y = 8,
    WORK_GROUP_SIZE_Z = 4,
    VOLUME_TEXTURE_FORMAT = rt.settings.clouds.volume_texture_format
}

local _fill_volume_texture_shader = rt.ComputeShader(
    "common/clouds_fill_volume_texture.glsl",
    _fill_volume_texture_shader_defines
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

    self._is_realized = false
end

--- @brief
function rt.Clouds:realize()
    if self._is_realized == true then return end

    self._draw_mesh = nil -- rt.Mesh
    self:_init_draw_mesh()

    self._volume_texture = nil -- love.VolumeText
    self:_init_volume_texture()

    self:_fill_volume_texture(
        self._noise_offset_x,
        self._noise_offset_y,
        self._noise_offset_z
    )

    self._is_realized = true
end

--- @brief
function rt.Clouds:update(delta)
    if self._is_realized ~= true then return end

end

--- @brief
function rt.Clouds:draw()
    if self._is_realized ~= true then return end

    _draw_mesh_shader:bind()
    _draw_mesh_shader:send("volume_texture", self._volume_texture:get_native())
    love.graphics.setColor(1, 1, 1, 1)
    self._draw_mesh:draw()
    _draw_mesh_shader:unbind()
end

--- @brief
function rt.Clouds:_init_draw_mesh()
    local data = {}

    local bounds = self._bounds
    local x0, x1 = bounds.x - bounds.size_x / 2, bounds.x + bounds.size_x / 2
    local y0, y1 = bounds.y - bounds.size_y / 2, bounds.y + bounds.size_y / 2
    local z0, z1 = bounds.z - bounds.size_z / 2, bounds.z + bounds.size_z / 2

    local function add_vertex(x, y, z, u, v, w)
        table.insert(data, {
            x, y, z, u, v, w,
            rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1)
        })
    end

    local function add_quad(v1, v2, v3, v4)
        add_vertex(table.unpack(v1))
        add_vertex(table.unpack(v2))
        add_vertex(table.unpack(v3))
        add_vertex(table.unpack(v1))
        add_vertex(table.unpack(v3))
        add_vertex(table.unpack(v4))
    end

    -- front face (z1)
    add_quad(
        {x0, y0, z1, 0, 0, 1},
        {x1, y0, z1, 1, 0, 1},
        {x1, y1, z1, 1, 1, 1},
        {x0, y1, z1, 0, 1, 1}
    )

    -- back face (z0)
    add_quad(
        {x1, y0, z0, 1, 0, 0},
        {x0, y0, z0, 0, 0, 0},
        {x0, y1, z0, 0, 1, 0},
        {x1, y1, z0, 1, 1, 0}
    )

    -- left face (x0)
    add_quad(
        {x0, y0, z0, 0, 0, 0},
        {x0, y0, z1, 0, 0, 1},
        {x0, y1, z1, 0, 1, 1},
        {x0, y1, z0, 0, 1, 0}
    )

    -- right face (x1)
    add_quad(
        {x1, y0, z1, 1, 0, 1},
        {x1, y0, z0, 1, 0, 0},
        {x1, y1, z0, 1, 1, 0},
        {x1, y1, z1, 1, 1, 1}
    )

    -- top face (y0, since y goes downward)
    add_quad(
        {x0, y0, z0, 0, 0, 0},
        {x1, y0, z0, 1, 0, 0},
        {x1, y0, z1, 1, 0, 1},
        {x0, y0, z1, 0, 0, 1}
    )

    -- bottom face (y1)
    add_quad(
        {x0, y1, z1, 0, 1, 1},
        {x1, y1, z1, 1, 1, 1},
        {x1, y1, z0, 1, 1, 0},
        {x0, y1, z0, 0, 1, 0}
    )

    self._draw_mesh = rt.Mesh(
        data,
        rt.MeshDrawMode.TRIANGLES,
        _draw_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
end

--- @brief
function rt.Clouds:_init_volume_texture()
    self._volume_texture = rt.RenderTextureVolume(
        self._bounds.size_x,
        self._bounds.size_y,
        self._bounds.size_z,
        0, -- msaa
        rt.settings.clouds.volume_texture_format,
        true, -- compute readable
        false -- use mipmaps
    )

    self._volume_texture:set_scale_mode(
        rt.TextureScaleMode.LINEAR,
        rt.TextureScaleMode.LINEAR,
        rt.settings.clouds.volume_texture_anisotropy
    )
end

--- @brief
function rt.Clouds:_fill_volume_texture(offset_x, offset_y, offset_z)
    _fill_volume_texture_shader:send("noise_offset", { offset_x, offset_y, offset_z })
    _fill_volume_texture_shader:send("volume_texture", self._volume_texture:get_native())

    local defines = _fill_volume_texture_shader_defines
    local size_x, size_y, size_z = self._volume_texture:get_size()
    _fill_volume_texture_shader:dispatch(
        math.ceil(size_x / defines.WORK_GROUP_SIZE_X),
        math.ceil(size_y / defines.WORK_GROUP_SIZE_Y),
        math.ceil((size_z or 0) / defines.WORK_GROUP_SIZE_Z)
    )
end