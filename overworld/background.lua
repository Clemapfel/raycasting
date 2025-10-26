require "common.quaternion"
require "common.widget"
require "common.render_texture_3d"

rt.settings.overworld.background = {
    n_particles = 1000,
    min_scale = 0.5,
    max_scale = 1,
    min_depth = 50,
    max_depth = 150,
    n_point_lights = 3,

    room_depth = 10,
    z_zoom = -10, -- camera position towards z axis
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
    self._view_transform:look_at(
        0,  0,  0, -- eye xyz
        0,  0,  1, -- target xyz
        0, -1,  0  -- up xyz
    )

    self._offset_transform = rt.Transform() -- xyz offset
    self._point_lights = {}
end

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)

    self._canvas = rt.RenderTexture3D(width, height, 8)
    self._canvas:set_fov(0.1)
    self:_init_data_mesh()
    self:_init_room_mesh()
    self:_init_point_lights()
end

--- @brief
function ow.Background:draw()
    if self._canvas_needs_update == true then
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        local transform = self._view_transform:clone()
        transform:translate(0, 0, rt.settings.overworld.background.z_zoom)

        self._canvas:set_view_transform(transform)
        self._room_mesh:draw()

        transform:apply(self._offset_transform)

        self._canvas:set_view_transform(transform)
        _particle_shader:bind()
        _particle_shader:send("point_lights", table.unpack(self._point_lights))
        _particle_shader:send("n_point_lights", #self._point_lights)
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
    -- TODO
    local t = delta * 10
    if self._input:get_is_down(rt.InputAction.LEFT) then
        self._offset_transform:translate(-t, 0, 0)
    end
    if self._input:get_is_down(rt.InputAction.RIGHT) then
        self._offset_transform:translate(t, 0, 0)
    end
    if self._input:get_is_down(rt.InputAction.UP) then
        self._offset_transform:translate(0, -t, 0)
    end
    if self._input:get_is_down(rt.InputAction.DOWN) then
        self._offset_transform:translate(0, t, 0)
    end
    if self._input:get_is_down(rt.InputAction.A) then
        self._offset_transform:translate(0, 0, t)
    end
    if self._input:get_is_down(rt.InputAction.B) then
        self._offset_transform:translate(0, 0, -t)
    end
    -- TODO

    self._canvas_needs_update = true

    -- boxing
    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()
    min_x, max_x, min_y, max_y, min_z, max_z = math.min(min_x, max_x),
        math.max(min_x, max_x),
        math.min(min_y, max_y),
        math.max(min_y, max_y),
        math.min(min_z, max_z),
        math.max(min_z, max_z)

    function is_outside(x, y, z, r)
        local closest_x = math.max(min_x, math.min(x, max_x))
        local closest_y = math.max(min_y, math.min(y, max_y))
        local closest_z = math.max(min_z, math.min(z, max_z))

        local dx = x - closest_x
        local dy = y - closest_y
        local dz = z - closest_z
        local distance_squared = dx * dx + dy * dy + dz * dz

        return distance_squared > r * r
    end

    function wrap(x, left, right)
        if x < left then
            return right + (left - x)
        elseif x > right then
            return left + (right - x)
        else
            return x
        end
    end

    -- rotation
    local angle = delta * 2 * math.pi * 0.05
    local inv_sqrt3 = 1 / math.sqrt(3)
    local ax, ay, az = inv_sqrt3, inv_sqrt3, inv_sqrt3
    local dx, dy, dz, dw = math.quaternion.from_axis_angle(ax, ay, az, angle)

    local projection_inverse = self._canvas:get_projection_transform():inverse()

    for data in values(self._data_mesh_data) do
        local x, y, z, r = data[1], data[2], data[3], data[4]

        if is_outside(x, y, z, r) then
            x = wrap(x, min_x, max_x)
            y = wrap(y, min_y, max_y)
            z = wrap(z, min_z, max_z)
            data[1], data[2], data[3] = x, y, z
        end

        -- update rotation
        local qx, qy, qz, qw = data[5], data[6], data[7], data[8]
        data[5], data[6], data[7], data[8] = math.quaternion.normalize(math.quaternion.multiply(
            dx, dy, dz, dw,
            qx, qy, qz, qw
        ))
    end

    self._data_mesh:replace_data(self._data_mesh_data)
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

--- @brief compute 3d aabb that is visible given view transform and fov
function ow.Background:_get_3d_bounds()
    local aspect = self._bounds.width / self._bounds.height
    local settings = rt.settings.overworld.background

    local near_z = settings.min_depth
    local far_z  = settings.max_depth

    local half_h = math.tan(math.pi * self._canvas:get_fov() * 0.5) * near_z
    local half_w = half_h * aspect

    local s_norm = 1 / math.sqrt(3)
    local max_radius = s_norm * settings.max_scale

    local min_x = -half_w + max_radius
    local max_x =  half_w - max_radius
    local min_y = -half_h + max_radius
    local max_y =  half_h - max_radius

    local inv = self._offset_transform:inverse()
    local wmin_x, wmin_y, wfar_z  = inv:transform_point(min_x, min_y, far_z)
    local wmax_x, wmax_y, wnear_z = inv:transform_point(max_x, max_y, near_z)

    return wmin_x, wmax_x, wmin_y, wmax_y, wfar_z, wnear_z
end

--- @brief
function ow.Background:_init_data_mesh()
    local aspect = self._bounds.width / self._bounds.height

    local settings = rt.settings.overworld.background
    local n_particles = settings.n_particles
    local min_scale = settings.min_scale * rt.get_pixel_scale()
    local max_scale = settings.max_scale * rt.get_pixel_scale()

    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()
    min_x, max_x, min_y, max_y, min_z, max_z = math.min(min_x, max_x),
        math.max(min_x, max_x),
        math.min(min_y, max_y),
        math.max(min_y, max_y),
        math.min(min_z, max_z),
        math.max(min_z, max_z)

    min_x = min_x - max_scale
    max_x = max_x + max_scale
    min_y = min_y - max_scale
    max_y = max_y + max_scale
    min_z = min_z - max_scale
    max_z = max_z + max_scale
    
    self._data_mesh_data = {}
    for i = 1, n_particles do
        local scale = math.mix(min_scale, max_scale, rt.random.number(0, 1))
        local x = rt.random.number(min_x, max_x)
        local y = rt.random.number(min_y, max_y)
        local z = rt.random.number(min_z, max_z)

        local qx, qy, qz, qw = math.quaternion.random()

        table.insert(self._data_mesh_data, {
            x, y, z,
            scale,
            qx, qy, qz, qw
        })
    end

    -- sort by z (front to back)
    table.sort(self._data_mesh_data, function(a, b)
        return a[3] < b[3]
    end)

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

--- @brief
function ow.Background:_init_room_mesh()
    local room_mesh_data = {}
    local settings = rt.settings.overworld.background

    -- get 3D visible bounds
    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()
    local hue = 0

    local function add_vertex(x, y, z, u, v)
        table.insert(room_mesh_data, {
            x, y, z,
            u, v,
            rt.lcha_to_rgba(0.5, 1, hue, 1)
        })
    end

    -- back wall (farthest from camera)
    hue = 0 / 6
    add_vertex(min_x, min_y, min_z, 0, 0)
    add_vertex(max_x, min_y, min_z, 1, 0)
    add_vertex(max_x, max_y, min_z, 1, 1)
    add_vertex(min_x, max_y, min_z, 0, 1)

    -- top wall
    hue = 1 / 6
    add_vertex(min_x, min_y, min_z, 0, 0)
    add_vertex(max_x, min_y, min_z, 1, 0)
    add_vertex(max_x, min_y, max_z, 1, 1)
    add_vertex(min_x, min_y, max_z, 0, 1)

    -- bottom wall
    hue = 2 / 6
    add_vertex(min_x, max_y, max_z, 0, 0)
    add_vertex(max_x, max_y, max_z, 1, 0)
    add_vertex(max_x, max_y, min_z, 1, 1)
    add_vertex(min_x, max_y, min_z, 0, 1)

    -- right wall
    hue = 3 / 6
    add_vertex(max_x, min_y, min_z, 0, 0)
    add_vertex(max_x, max_y, min_z, 1, 0)
    add_vertex(max_x, max_y, max_z, 1, 1)
    add_vertex(max_x, min_y, max_z, 0, 1)

    -- left wall
    hue = 4 / 6
    add_vertex(min_x, min_y, max_z, 0, 0)
    add_vertex(min_x, max_y, max_z, 1, 0)
    add_vertex(min_x, max_y, min_z, 1, 1)
    add_vertex(min_x, min_y, min_z, 0, 1)

    self._room_mesh = rt.Mesh(
        room_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    -- define triangles (no front wall)
    self._room_mesh:set_vertex_map({
        1, 2, 3, -- back wall
        1, 3, 4,

        5, 6, 7, -- top wall
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
function ow.Background:_init_point_lights()
    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()

    local offset = 0.2
    local width, height, depth = max_x - min_x, max_y - min_y, max_z - min_z
    min_x = min_x + offset * width
    max_x = max_x - offset * width
    min_y = min_y + offset * height
    max_y = max_y - offset * height
    min_z = min_z + offset * depth
    max_z = max_z - offset * depth

    self._point_lights = {}
    for i = 1, rt.settings.overworld.background.n_point_lights do
        table.insert(self._point_lights, {
            rt.random.number(min_x, max_x),
            rt.random.number(min_y, max_y),
            rt.random.number(min_z, max_z)
        })
    end
end
