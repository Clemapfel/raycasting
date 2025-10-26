require "common.quaternion"
require "common.widget"
require "common.render_texture_3d"

rt.settings.overworld.background = {
    n_particles = 10000,
    min_scale = 1,
    max_scale = 2,
    min_depth = 0,
    max_depth = 100,

    room_depth = 10
}

--- @class ow.Background
ow.Background = meta.class("OverworldBackground", rt.Widget)

local _particle_shader = rt.Shader("overworld/background_particles.glsl")

local _instance_mesh_format = {
    { location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec3" },
    { location = 1, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4" }
}

local _data_mesh_format = {
    { location = 3, name = "offset", format = "floatvec3" },
    { location = 4, name = "scale", format = "float" },
    { location = 5, name = "rotation", format = "floatvec4"} -- quaternion
}

--- @brief
function ow.Background:instantiate()
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _particle_shader:recompile()
        end
    end)
end

--- @brief
function ow.Background:realize()
    if self:already_realized() then return end

    self._n_particles = rt.settings.overworld.background.n_particles

    self._cube_mesh = nil -- rt.Mesh
    self:_init_cube_mesh()

    self._data_mesh_data = {}
    self._data_mesh = nil -- rt.Mesh

    self._canvas = nil -- rt.RenderTexture3D
    self._canvas_needs_update = true
    self._view_transform = rt.Transform()
end

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)

    self._canvas = rt.RenderTexture3D(width, height)
    self:_init_data_mesh()
    self:_init_room_mesh()
end

--- @brief
function ow.Background:draw()
    if self._canvas_needs_update == true then
        self._canvas:bind()
        self._canvas:set_view_transform(self._view_transform)
        self._canvas:reset_model_transform()

        --self._room_mesh:draw()

        _particle_shader:bind()
        self._cube_mesh:draw_instanced(self._n_particles)
        _particle_shader:unbind()

        self._canvas:unbind()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.translate(self._bounds.x, self._bounds.y)
    self._canvas:draw()
    love.graphics.pop()
end

--- @brief
function ow.Background:update(delta)
    self._canvas_needs_update = true
end

function ow.Background:_init_cube_mesh()
    local cube_mesh_data = {}
    local s = 1 / math.sqrt(3)

    local hue = 0
    function add_vertex(x, y, z, u, v)
        table.insert(cube_mesh_data, { x, y, z, u, v, rt.lcha_to_rgba(0.8, 1, hue, 1) })
    end

    -- front
    hue = 0 / 6
    add_vertex(-s, -s,  s, 0, 0)
    add_vertex( s, -s,  s, 1, 0)
    add_vertex( s,  s,  s, 1, 1)
    add_vertex(-s,  s,  s, 0, 1)

    -- back
    hue = 1 / 6
    add_vertex( s, -s, -s, 0, 0)
    add_vertex(-s, -s, -s, 1, 0)
    add_vertex(-s,  s, -s, 1, 1)
    add_vertex( s,  s, -s, 0, 1)

    -- top
    hue = 2 / 6
    add_vertex(-s, -s, -s, 0, 0)
    add_vertex( s, -s, -s, 1, 0)
    add_vertex( s, -s,  s, 1, 1)
    add_vertex(-s, -s,  s, 0, 1)

    -- bottom
    hue = 3 / 6
    add_vertex(-s,  s,  s, 0, 0)
    add_vertex( s,  s,  s, 1, 0)
    add_vertex( s,  s, -s, 1, 1)
    add_vertex(-s,  s, -s, 0, 1)

    -- right
    hue = 4 / 6
    add_vertex( s, -s,  s, 0, 0)
    add_vertex( s, -s, -s, 1, 0)
    add_vertex( s,  s, -s, 1, 1)
    add_vertex( s,  s,  s, 0, 1)

    -- left
    hue = 5 / 6
    add_vertex(-s, -s, -s, 0, 0)
    add_vertex(-s, -s,  s, 1, 0)
    add_vertex(-s,  s,  s, 1, 1)
    add_vertex(-s,  s, -s, 0, 1)

    self._cube_mesh = rt.Mesh(
        cube_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    self._cube_mesh:set_vertex_map({
        1, 2, 3, -- front
        1, 3, 4,

        5, 6, 7, -- back
        5, 7, 8,

        9, 10, 11, -- top
        9, 11, 12,

        13, 14, 15, -- bottom
        13, 15, 16,

        17, 18, 19, -- right
        17, 19, 20,

        21, 22, 23, -- left
        21, 23, 24
    })
end

--- @brief
function ow.Background:_init_room_mesh()
    local room_mesh_data = {}

    local bounds = self._bounds
    local width, height = bounds.width, bounds.height
    local offset_x, offset_y = bounds.x, bounds.y

    -- half dimensions for centering
    local w = width / 2
    local h = height / 2
    local d = rt.settings.overworld.background.room_depth

    local hue = 0
    function add_vertex(x, y, z, u, v)
        table.insert(room_mesh_data, {
            offset_x + x, offset_y + y, z,
            u, v,
            rt.lcha_to_rgba(0.8, 1, hue, 1)
        })
    end

    -- back wall
    hue = 0 / 5
    add_vertex(-w, -h, -d, 0, 0)
    add_vertex( w, -h, -d, 1, 0)
    add_vertex( w,  h, -d, 1, 1)
    add_vertex(-w,  h, -d, 0, 1)

    -- top wall
    hue = 1 / 5
    add_vertex(-w, -h, 0, 0, 0)
    add_vertex( w, -h, 0, 1, 0)
    add_vertex( w, -h, -d, 1, 1)
    add_vertex(-w, -h, -d, 0, 1)

    -- bottom wall
    hue = 2 / 5
    add_vertex(-w,  h, -d, 0, 0)
    add_vertex( w,  h, -d, 1, 0)
    add_vertex( w,  h, 0, 1, 1)
    add_vertex(-w,  h, 0, 0, 1)

    -- right wall
    hue = 3 / 5
    add_vertex( w, -h, 0, 0, 0)
    add_vertex( w, -h, -d, 1, 0)
    add_vertex( w,  h, -d, 1, 1)
    add_vertex( w,  h, 0, 0, 1)

    -- left wall
    hue = 4 / 5
    add_vertex(-w, -h, -d, 0, 0)
    add_vertex(-w, -h, 0, 1, 0)
    add_vertex(-w,  h, 0, 1, 1)
    add_vertex(-w,  h, -d, 0, 1)

    self._room_mesh = rt.Mesh(
        room_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    self._room_mesh:set_vertex_map({
        1, 2, 3, -- back wall
        1, 3, 4,

        5, 6, 7,   -- top wall
        5, 7, 8,

        9, 10, 11, -- bottom wall
        9, 11, 12,

        13, 14, 15, -- right wall
        13, 15, 16,

        17, 18, 19, -- left wall
        17, 19, 20
    })
end

--- @brief
function ow.Background:_init_data_mesh()
    local min_x, max_x, min_y, max_y
    do
        local x, y, width, height = self._bounds:unpack()
        x = x - 0.5 * width
        y = y - 0.5 * height
        min_x, max_x = x, x + width
        min_y, max_y = y, y + height
    end

    local settings = rt.settings.overworld.background
    local n_particles = settings.n_particles
    local min_scale = settings.min_scale * rt.get_pixel_scale()
    local max_scale = settings.max_scale * rt.get_pixel_scale()
    local min_z, max_z = settings.min_depth, settings.max_depth

    self._data_mesh_data = {}
    for i = 1, n_particles do
        local scale = math.mix(min_scale, max_scale, rt.random.number(0, 1))
        local x = math.mix(min_x, max_x, rt.random.number(0, 1))
        local y = math.mix(min_y, max_y, rt.random.number(0, 1))
        local z = math.mix(min_y, max_y, rt.random.number(0, 1))

        local qx, qy, qz, qw = math.quaternion_identity()--math.quaternion_random()

        table.insert(self._data_mesh_data, {
            x, y, z,
            scale,
            qx, qy, qz, qw
        })
    end

    self._data_mesh = rt.Mesh(
        self._data_mesh_data,
        rt.MeshDrawMode.POINTS,
        _data_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    assert(self._cube_mesh ~= nil)

    for entry in values(_data_mesh_format) do
        self._cube_mesh:attach_attribute(
            self._data_mesh,
            entry.name,
            rt.MeshAttributeAttachmentMode.PER_INSTANCE
        )
    end
end