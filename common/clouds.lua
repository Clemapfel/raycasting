require "common.texture_format"
require "common.render_texture_volume"
require "common.shader"
require "common.compute_shader"

rt.settings.clouds = {
    volume_texture_format = rt.TextureFormat.R32F,
    volume_texture_anisotropy = 1
}

--- @class rt.Clouds
rt.Clouds = meta.class("Clouds")

local _draw_mesh_format = {
    { location = 0, name = "position", format = "floatvec3" },
    { location = 1, name = "texture_coords", format = "floatvec3" },
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
    self:_init_draw_mesh()

    self._volume_texture = nil -- love.VolumeText
    self:_init_volume_texture()

    self:_fill_volume_texture()
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
        self:_fill_volume_texture()
    end
end

--- @brief
--- @brief
--- @brief
function rt.Clouds:draw(camera_position, view_transform_inverse)
    if self._is_realized ~= true then return end

    local b = self._bounds
    local x0, y0, z0 = b.x - b.size_x / 2, b.y - b.size_y / 2, b.z - b.size_z / 2

    _draw_mesh_shader:bind()
    _draw_mesh_shader:send("volume_texture", self._volume_texture:get_native())
    _draw_mesh_shader:send("camera_position", camera_position)
    _draw_mesh_shader:send("view_transform_inverse", view_transform_inverse:get_native())

    love.graphics.setColor(1, 1, 1, 1)
    self._draw_mesh:draw()
    _draw_mesh_shader:unbind()

    local dim = 0.75
    love.graphics.setColor(dim, dim, dim, dim)
    love.graphics.setWireframe(true)
    self._draw_mesh:draw()
    love.graphics.setWireframe(false)
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
            1, 1, 1, 1
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

    -- Texture coordinates now map to 3D position in unit cube [0,1]³
    -- u = normalized X position (0 at x0, 1 at x1)
    -- v = normalized Y position (0 at y0, 1 at y1)
    -- w = normalized Z position (0 at z0, 1 at z1)

    -- front face (z1, w=1)
    add_quad(
        {x0, y0, z1, 0, 0, 1},
        {x1, y0, z1, 1, 0, 1},
        {x1, y1, z1, 1, 1, 1},
        {x0, y1, z1, 0, 1, 1}
    )

    -- back face (z0, w=0)
    add_quad(
        {x1, y0, z0, 1, 0, 0},
        {x0, y0, z0, 0, 0, 0},
        {x0, y1, z0, 0, 1, 0},
        {x1, y1, z0, 1, 1, 0}
    )

    -- left face (x0, u=0)
    add_quad(
        {x0, y0, z0, 0, 0, 0},
        {x0, y0, z1, 0, 0, 1},
        {x0, y1, z1, 0, 1, 1},
        {x0, y1, z0, 0, 1, 0}
    )

    -- right face (x1, u=1)
    add_quad(
        {x1, y0, z1, 1, 0, 1},
        {x1, y0, z0, 1, 0, 0},
        {x1, y1, z0, 1, 1, 0},
        {x1, y1, z1, 1, 1, 1}
    )

    -- top face (y0, v=0)
    add_quad(
        {x0, y0, z0, 0, 0, 0},
        {x1, y0, z0, 1, 0, 0},
        {x1, y0, z1, 1, 0, 1},
        {x0, y0, z1, 0, 0, 1}
    )

    -- bottom face (y1, v=1)
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
    local n_voxels = 0.25 * math.sqrt(100^3) --math.sqrt(self._bounds.size_x * self._bounds.size_y * self._bounds.size_z)
    local sum = self._bounds.size_x + self._bounds.size_y + self._bounds.size_z

    self._volume_texture = rt.RenderTextureVolume(
        n_voxels * (self._bounds.size_x / sum),
        n_voxels * (self._bounds.size_y / sum),
        n_voxels * (self._bounds.size_z / sum),
        0, -- msaa
        rt.settings.clouds.volume_texture_format,
        true, -- compute readable
        false -- use mipmaps
    )

    dbg(n_voxels * (self._bounds.size_x / sum) *
        n_voxels * (self._bounds.size_y / sum) *
        n_voxels * (self._bounds.size_z / sum)
    )

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
function rt.Clouds:_fill_volume_texture()
    _fill_volume_texture_shader:send("noise_offset", {
        self._noise_offset_x,
        self._noise_offset_y,
        self._noise_offset_z
    })
    _fill_volume_texture_shader:send("time_offset", self._noise_offset_time)
    _fill_volume_texture_shader:send("volume_texture", self._volume_texture:get_native())

    local defines = _fill_volume_texture_shader_defines
    local size_x, size_y, size_z = self._volume_texture:get_size()
    _fill_volume_texture_shader:dispatch(
        math.ceil(size_x / defines.WORK_GROUP_SIZE_X),
        math.ceil(size_y / defines.WORK_GROUP_SIZE_Y),
        math.ceil(size_z / defines.WORK_GROUP_SIZE_Z)
    )

end