require "common.quaternion"
require "common.widget"
require "common.render_texture_3d"

rt.settings.overworld.background = {
    n_particles = 1000,
    min_scale = 0.8,
    max_scale = 1.5,
    fov = 0.3,
    min_depth = 50,
    max_depth = 400,
    cell_size = 2^3,
    cell_occupancy_change = 0.5,

    min_rotation_speed = 0.02, -- radians per second
    max_rotation_speed = 0.05,

    z_zoom = 0, -- camera position towards z axis
    stage_z_position = 1, -- world z coord of stage plane,
    cube_thickness = 0.1, -- fraction

    room_color = rt.Palette.GRAY_9
}

--- @class ow.Background
ow.Background = meta.class("OverworldBackground", rt.Widget)

local _particle_shader = rt.Shader("overworld/background_particles.glsl")
local _room_shader = rt.Shader("overworld/background_room.glsl")

local _instance_mesh_format = {
    { location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec3" },
    { location = 1, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4" }
}

local _data_mesh_format = {
    { location = 3, name = "offset", format = "floatvec3" },
    { location = 4, name = "scale", format = "float" },
    { location = 5, name = "rotation", format = "floatvec4"}, -- quaternion
    { location = 6, name = "color", format = "floatvec4" }
}

--- @brief
function ow.Background:instantiate()
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _particle_shader:recompile()
            _room_shader:recompile()
        end
    end)
end

--- @brief
function ow.Background:realize()
    if self:already_realized() then return end

    self._n_particles = rt.settings.overworld.background.n_particles

    self._instance_mesh = nil -- rt.Mesh
    self:_init_instance_mesh()

    self._data_mesh_data = {}
    self._data_mesh_data_aux = {}
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
    self._scale_transform = rt.Transform() -- xyz offset
end

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)

    self._canvas = rt.RenderTexture3D(width, height, 8)
    self._canvas:set_fov(rt.settings.overworld.background.fov)
    if self._data_mesh == nil then
        self:_init_data_mesh()
    end

    if self._room_mesh == nil then
        self:_init_room_mesh()
    end
end

--- @brief
function ow.Background:draw()
    if self._canvas_needs_update == true then
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        local scale = self:_get_scale_factor()

        -- room drawn unaffected by stage camera
        local room_transform = self._view_transform:clone()
        room_transform:scale(scale, scale, 1)
        room_transform:apply(self._scale_transform)
        room_transform:translate(0, 0, rt.settings.overworld.background.z_zoom)

        self._canvas:set_view_transform(room_transform)
        _room_shader:bind()
        _room_shader:send("elapsed", rt.SceneManager:get_elapsed())
        self._room_mesh:draw()
        _room_shader:unbind()

        -- particles affected
        local particle_transform = self._view_transform:clone()
        particle_transform:scale(scale, scale, 1)
        particle_transform:apply(self._scale_transform)
        particle_transform:translate(0, 0, rt.settings.overworld.background.z_zoom)
        particle_transform:apply(self._offset_transform)

        self._canvas:set_view_transform(particle_transform)
        _particle_shader:bind()
        self._instance_mesh:draw_instanced(self._n_particles)
        _particle_shader:unbind()

        self._canvas:unbind()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.origin()
    self._canvas:draw()
    love.graphics.pop()
end

--- @brief
--- @brief
--- @brief
function ow.Background:notify_camera_changed(camera)
    do
        self._scale_transform:reset()
        local scale = camera:get_final_scale()
        self._scale_transform:scale(scale, scale, 1)
    end

    local offset_x, offset_y = camera:get_offset() -- in screen coords (pixels)

    local aspect = self._bounds.width / self._bounds.height
    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)
    local near_z = rt.settings.overworld.background.stage_z_position

    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local world_offset_x = (offset_x / self._bounds.width) * (2 * half_w_near)
    local world_offset_y = (offset_y / self._bounds.height) * (2 * half_h_near) * -1 -- y points down

    self._offset_transform:reset()
    self._offset_transform:translate(
        world_offset_x,
        world_offset_y,
        0
    )
end

--- @brief compute 3d aabb that is visible given view transform and fov
--- @return Number, Number, Number, Number, Number, Number min_x, max_x, min_y, max_y, min_z, max_z
function ow.Background:_get_3d_bounds()
    local aspect = self._bounds.width / self._bounds.height
    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)

    local settings = rt.settings.overworld.background
    local near_z = settings.min_depth
    local far_z = settings.max_depth
    local z_zoom = settings.z_zoom
    local z_back_eff = far_z + z_zoom

    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local min_x, max_x = -half_w_near, half_w_near
    local min_y, max_y = -half_h_near, half_h_near
    local min_z, max_z = near_z, far_z

    return min_x, max_x, min_y, max_y, min_z, max_z
end

--- @brief scale factor such that only back wall is visible
function ow.Background:_get_scale_factor()
    local aspect = self._bounds.width / self._bounds.height

    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)

    local settings = rt.settings.overworld.background
    local near_z = settings.min_depth
    local far_z = settings.max_depth
    local z_zoom = settings.z_zoom or 0

    local z_back_eff = far_z + z_zoom

    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local s_norm = 1 / math.sqrt(3)
    local max_radius = s_norm * settings.max_scale

    local room_half_w = math.max(half_w_near - max_radius, math.eps)
    local room_half_h = math.max(half_h_near - max_radius, math.eps)

    local half_h_back = tan_half * z_back_eff
    local half_w_back = half_h_back * aspect

    local sx = half_w_back / room_half_w
    local sy = half_h_back / room_half_h
    return math.max(sx, sy)
end

--- @brief
--- @brief
function ow.Background:update(delta)
    self._canvas_needs_update = true

    --[[
    if self._input:get_is_down(rt.InputAction.RIGHT) then
        self._offset_transform:translate(10 * delta, 0, 0)
    elseif self._input:get_is_down(rt.InputAction.LEFT) then
        self._offset_transform:translate(-10 * delta, 0, 0)
    elseif self._input:get_is_down(rt.InputAction.UP) then
        self._offset_transform:translate(0, -10 * delta, 0)
    elseif self._input:get_is_down(rt.InputAction.DOWN) then
        self._offset_transform:translate(0, 10 * delta, 0)
    end
    ]]--

    local min_x, max_x, min_y, max_y, min_z, max_z = table.unpack(self._room_bounds)

    local transform = self._offset_transform:clone()
    min_x, min_y, min_z = transform:inverse_transform_point(min_x, min_y, min_z)
    max_x, max_y, max_z = transform:inverse_transform_point(max_x, max_y, max_z)

    for data_i, data in ipairs(self._data_mesh_data) do
        local aux_data = self._data_mesh_data_aux[data_i]
        local x, y, z = data[1], data[2], data[3]
        local bx, by, bz = x, y, z

        -- wrap when moving out of visible box
        local x_wrapped, y_wrapped, z_wrapped = false, false, false

        local width = max_x - min_x
        if x > max_x then
            x = min_x + (x - max_x) % width
            x_wrapped = true
        elseif x < min_x then
            x = max_x - (min_x - x) % width
            x_wrapped = true
        end

        local height = max_y - min_y
        if y > max_y then
            y = min_y + (y - max_y) % height
            y_wrapped = true
        elseif y < min_y then
            y = max_y - (min_y - y) % height
            y_wrapped = true
        end

        local depth = max_z - min_z
        if z > max_z then
            z = min_z + (z - max_z) % depth
            z_wrapped = true
        elseif z < min_z then
            z = max_z - (min_z - z) % depth
            z_wrapped = true
        end

        -- if wrapped, teleport to new deterministic position
        if x_wrapped then
            y = math.mix(min_y, max_y, rt.random.noise(x, y))
        end

        if y_wrapped then
            x = math.mix(min_x, max_x, rt.random.noise(y, x))
        end

        data[1], data[2], data[3] = x, y, z

        -- rotate
        local angle = delta * 2 * math.pi * aux_data.rotation_speed
        local axis_x, axis_y, axis_z = table.unpack(aux_data.rotation_axis)
        data[5], data[6], data[7], data[8] = math.quaternion.normalize(math.quaternion.multiply(
            data[5], data[6], data[7], data[8],
            math.quaternion.from_axis_angle(axis_x, axis_y, axis_z, angle)
        ))
    end

    self._data_mesh:replace_data(self._data_mesh_data)
end

--[[
function ow.Background:_init_instance_mesh()
    local cube_mesh_data = {}
    local s = 1 / math.sqrt(3)

    local hue = 0
    function add_vertex(x, y, z, u, v)
        table.insert(cube_mesh_data, { x, y, z, u, v, 1, 1, 1, 1 }) --rt.lcha_to_rgba(0.8, 1, hue, 1) })
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

    self._instance_mesh = rt.Mesh(
        cube_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    self._instance_mesh:set_vertex_map({
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
]]--

function ow.Background:_init_instance_mesh()
    local mesh_data = {}
    local indices = {}
    local vertex_count = 0

    local s = 1 / math.sqrt(3)  -- outer radius
    local t = rt.settings.overworld.background.cube_thickness * s
    local si = s - t

    function add_vertex(x, y, z, u, v)
        table.insert(mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        vertex_count = vertex_count + 1
        return vertex_count
    end

    function add_quad(v1, v2, v3, v4)
        -- Add two triangles for a quad (v1-v2-v3-v4 in CCW order)
        table.insert(indices, v1)
        table.insert(indices, v2)
        table.insert(indices, v3)
        table.insert(indices, v1)
        table.insert(indices, v3)
        table.insert(indices, v4)
    end

    -- Helper to add a rectangular strip (frame segment)
    -- outer: 4 corners of outer edge (CCW), inner: 4 corners of inner edge (CCW)
    function add_frame_strip(o1, o2, i1, i2)
        add_quad(o1, o2, i2, i1)
    end

    -- +Z face (front) - looking at face from outside
    local v = {}
    v[1] = add_vertex(-s, -s, s, 0, 0)
    v[2] = add_vertex(s, -s, s, 1, 0)
    v[3] = add_vertex(s, s, s, 1, 1)
    v[4] = add_vertex(-s, s, s, 0, 1)
    v[5] = add_vertex(-si, -si, s, 1 / 4, 1 / 4)
    v[6] = add_vertex(si, -si, s, 3 / 4, 1 / 4)
    v[7] = add_vertex(si, si, s, 3 / 4, 3 / 4)
    v[8] = add_vertex(-si, si, s, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- -Z face (back)
    v = {}
    v[1] = add_vertex(s, -s, -s, 0, 0)
    v[2] = add_vertex(-s, -s, -s, 1, 0)
    v[3] = add_vertex(-s, s, -s, 1, 1)
    v[4] = add_vertex(s, s, -s, 0, 1)
    v[5] = add_vertex(si, -si, -s, 1 / 4, 1 / 4)
    v[6] = add_vertex(-si, -si, -s, 3 / 4, 1 / 4)
    v[7] = add_vertex(-si, si, -s, 3 / 4, 3 / 4)
    v[8] = add_vertex(si, si, -s, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- +Y face (top)
    v = {}
    v[1] = add_vertex(-s, s, s, 0, 0)
    v[2] = add_vertex(s, s, s, 1, 0)
    v[3] = add_vertex(s, s, -s, 1, 1)
    v[4] = add_vertex(-s, s, -s, 0, 1)
    v[5] = add_vertex(-si, s, si, 1 / 4, 1 / 4)
    v[6] = add_vertex(si, s, si, 3 / 4, 1 / 4)
    v[7] = add_vertex(si, s, -si, 3 / 4, 3 / 4)
    v[8] = add_vertex(-si, s, -si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- -Y face (bottom)
    v = {}
    v[1] = add_vertex(-s, -s, -s, 0, 0)
    v[2] = add_vertex(s, -s, -s, 1, 0)
    v[3] = add_vertex(s, -s, s, 1, 1)
    v[4] = add_vertex(-s, -s, s, 0, 1)
    v[5] = add_vertex(-si, -s, -si, 1 / 4, 1 / 4)
    v[6] = add_vertex(si, -s, -si, 3 / 4, 1 / 4)
    v[7] = add_vertex(si, -s, si, 3 / 4, 3 / 4)
    v[8] = add_vertex(-si, -s, si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- +X face (right)
    v = {}
    v[1] = add_vertex(s, -s, s, 0, 0)
    v[2] = add_vertex(s, -s, -s, 1, 0)
    v[3] = add_vertex(s, s, -s, 1, 1)
    v[4] = add_vertex(s, s, s, 0, 1)
    v[5] = add_vertex(s, -si, si, 1 / 4, 1 / 4)
    v[6] = add_vertex(s, -si, -si, 3 / 4, 1 / 4)
    v[7] = add_vertex(s, si, -si, 3 / 4, 3 / 4)
    v[8] = add_vertex(s, si, si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- -X face (left)
    v = {}
    v[1] = add_vertex(-s, -s, -s, 0, 0)
    v[2] = add_vertex(-s, -s, s, 1, 0)
    v[3] = add_vertex(-s, s, s, 1, 1)
    v[4] = add_vertex(-s, s, -s, 0, 1)
    v[5] = add_vertex(-s, -si, -si, 1 / 4, 1 / 4)
    v[6] = add_vertex(-s, -si, si, 3 / 4, 1 / 4)
    v[7] = add_vertex(-s, si, si, 3 / 4, 3 / 4)
    v[8] = add_vertex(-s, si, -si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- Now add the interior faces for all 12 edge beams
    -- each beam needs: 2 side faces (already added above as frame strips)
    -- + 1 inner face (the face pointing toward the hollow center)

    -- 4 edges parallel to Z axis (vertical when looking at XY plane)

    -- edge at (-s, -s, z): beam from back to front
    v = {}
    v[1] = add_vertex(-si, -s, -si, 0, 0)
    v[2] = add_vertex(-s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(-s, -si, si, 0, 2 / 3)
    v[4] = add_vertex(-si, -s, si, 0, 1)
    v[5] = add_vertex(-si, -si, -s, 1, 0)
    v[6] = add_vertex(-si, -si, s, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[2], v[5], v[6], v[3])

    -- edge at (s, -s, z)
    v = {}
    v[1] = add_vertex(si, -s, -si, 0, 0)
    v[2] = add_vertex(s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(s, -si, si, 0, 2 / 3)
    v[4] = add_vertex(si, -s, si, 0, 1)
    v[5] = add_vertex(si, -si, -s, 1, 0)
    v[6] = add_vertex(si, -si, s, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[3], v[6], v[5], v[2])

    -- edge at (s, s, z)
    v = {}
    v[1] = add_vertex(si, s, -si, 0, 0)
    v[2] = add_vertex(s, si, -si, 0, 1 / 3)
    v[3] = add_vertex(s, si, si, 0, 2 / 3)
    v[4] = add_vertex(si, s, si, 0, 1)
    v[5] = add_vertex(si, si, -s, 1, 0)
    v[6] = add_vertex(si, si, s, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[5], v[2], v[3], v[6])

    -- edge at (-s, s, z)
    v = {}
    v[1] = add_vertex(-si, s, -si, 0, 0)
    v[2] = add_vertex(-s, si, -si, 0, 1 / 3)
    v[3] = add_vertex(-s, si, si, 0, 2 / 3)
    v[4] = add_vertex(-si, s, si, 0, 1)
    v[5] = add_vertex(-si, si, -s, 1, 0)
    v[6] = add_vertex(-si, si, s, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[6], v[3], v[2], v[5])

    -- 4 edges parallel to X axis

    -- edge at (x, -s, -s)
    v = {}
    v[1] = add_vertex(-si, -s, -si, 0, 0)
    v[2] = add_vertex(-si, -si, -s, 0, 1 / 3)
    v[3] = add_vertex(si, -si, -s, 0, 2 / 3)
    v[4] = add_vertex(si, -s, -si, 0, 1)
    v[5] = add_vertex(-s, -si, -si, 1, 0)
    v[6] = add_vertex(s, -si, -si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[2], v[5], v[6], v[3])

    -- edge at (x, s, -s)
    v = {}
    v[1] = add_vertex(-si, s, -si, 0, 0)
    v[2] = add_vertex(-si, si, -s, 0, 1 / 3)
    v[3] = add_vertex(si, si, -s, 0, 2 / 3)
    v[4] = add_vertex(si, s, -si, 0, 1)
    v[5] = add_vertex(-s, si, -si, 1, 0)
    v[6] = add_vertex(s, si, -si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[3], v[6], v[5], v[2])

    -- edge at (x, s, s)
    v = {}
    v[1] = add_vertex(-si, s, si, 0, 0)
    v[2] = add_vertex(-si, si, s, 0, 1 / 3)
    v[3] = add_vertex(si, si, s, 0, 2 / 3)
    v[4] = add_vertex(si, s, si, 0, 1)
    v[5] = add_vertex(-s, si, si, 1, 0)
    v[6] = add_vertex(s, si, si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[5], v[2], v[3], v[6])

    -- edge at (x, -s, s)
    v = {}
    v[1] = add_vertex(-si, -s, si, 0, 0)
    v[2] = add_vertex(-si, -si, s, 0, 1 / 3)
    v[3] = add_vertex(si, -si, s, 0, 2 / 3)
    v[4] = add_vertex(si, -s, si, 0, 1)
    v[5] = add_vertex(-s, -si, si, 1, 0)
    v[6] = add_vertex(s, -si, si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[6], v[3], v[2], v[5])

    -- 4 edges parallel to Y axis

    -- edge at (-s, y, -s)
    v = {}
    v[1] = add_vertex(-si, -si, -s, 0, 0)
    v[2] = add_vertex(-s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(-s, si, -si, 0, 2 / 3)
    v[4] = add_vertex(-si, si, -s, 0, 1)
    v[5] = add_vertex(-si, -s, -si, 1, 0)
    v[6] = add_vertex(-si, s, -si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[2], v[5], v[6], v[3])

    -- edge at (s, y, -s)
    v = {}
    v[1] = add_vertex(si, -si, -s, 0, 0)
    v[2] = add_vertex(s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(s, si, -si, 0, 2 / 3)
    v[4] = add_vertex(si, si, -s, 0, 1)
    v[5] = add_vertex(si, -s, -si, 1, 0)
    v[6] = add_vertex(si, s, -si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[3], v[6], v[5], v[2])

    -- edge at (s, y, s)
    v = {}
    v[1] = add_vertex(si, -si, s, 0, 0)
    v[2] = add_vertex(s, -si, si, 0, 1 / 3)
    v[3] = add_vertex(s, si, si, 0, 2 / 3)
    v[4] = add_vertex(si, si, s, 0, 1)
    v[5] = add_vertex(si, -s, si, 1, 0)
    v[6] = add_vertex(si, s, si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[5], v[2], v[3], v[6])

    -- edge at (-s, y, s)
    v = {}
    v[1] = add_vertex(-si, -si, s, 0, 0)
    v[2] = add_vertex(-s, -si, si, 0, 1 / 3)
    v[3] = add_vertex(-s, si, si, 0, 2 / 3)
    v[4] = add_vertex(-si, si, s, 0, 1)
    v[5] = add_vertex(-si, -s, si, 1, 0)
    v[6] = add_vertex(-si, s, si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[6], v[3], v[2], v[5])

    self._instance_mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    self._instance_mesh:set_vertex_map(indices)
end

--- @brief
function ow.Background:_init_data_mesh()
    local aspect = self._bounds.width / self._bounds.height

    local settings = rt.settings.overworld.background
    local min_scale = settings.min_scale
    local max_scale = settings.max_scale

    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()

    min_x = min_x - max_scale
    max_x = max_x + max_scale
    min_y = min_y - max_scale
    max_y = max_y + max_scale

    min_z = min_z + max_scale
    max_z = max_z - max_scale

    self._room_bounds = {
        min_x, max_x,
        min_y, max_y,
        min_z, max_z
    }

    local cell_size = rt.settings.overworld.background.cell_size
    local spawn_probability = rt.settings.overworld.background.cell_occupancy_change

    self._data_mesh_data = {}
    self._data_mesh_data_aux = self._data_mesh_data_aux or {}

    local grid_x_count = math.ceil((max_x - min_x) / cell_size)
    local grid_y_count = math.ceil((max_y - min_y) / cell_size)
    local grid_z_count = math.ceil((max_z - min_z) / cell_size)

    for ix = 0, grid_x_count - 1 do
        for iy = 0, grid_y_count - 1 do
            for iz = 0, grid_z_count - 1 do
                if rt.random.toss_coin(spawn_probability) then
                    local scale = math.mix(min_scale, max_scale, rt.random.number(0, 1))

                    local cell_min_x = min_x + ix * cell_size
                    local cell_max_x = math.min(cell_min_x + cell_size, max_x)
                    local cell_min_y = min_y + iy * cell_size
                    local cell_max_y = math.min(cell_min_y + cell_size, max_y)
                    local cell_min_z = min_z + iz * cell_size
                    local cell_max_z = math.min(cell_min_z + cell_size, max_z)

                    -- prevent cube from reaching outside cell
                    local spawn_min_x = cell_min_x + scale
                    local spawn_max_x = cell_max_x - scale
                    local spawn_min_y = cell_min_y + scale
                    local spawn_max_y = cell_max_y - scale
                    local spawn_min_z = cell_min_z + scale
                    local spawn_max_z = cell_max_z - scale

                    local x = rt.random.number(spawn_min_x, spawn_max_x)
                    local y = rt.random.number(spawn_min_y, spawn_max_y)
                    local z = rt.random.number(spawn_min_z, spawn_max_z)

                    local qx, qy, qz, qw = math.quaternion.random()

                    local hue = rt.random.number(0, 1)
                    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue, 1)

                    table.insert(self._data_mesh_data, {
                        x, y, z,
                        scale,
                        qx, qy, qz, qw,
                        r, g, b, a
                    })

                    table.insert(self._data_mesh_data_aux, {
                        rotation_speed = rt.random.choose(-1, 1) * rt.random.number(
                            settings.min_rotation_speed,
                            settings.max_rotation_speed
                        ),

                        rotation_axis = { math.normalize(
                            rt.random.number(-1, 1),
                            rt.random.number(-1, 1),
                            rt.random.number(-1, 1)
                        )}
                    })
                end
            end
        end
    end
    
    table.sort(self._data_mesh_data, function(a, b)
        return a[3] < b[3]
    end)

    self._data_mesh = rt.Mesh(
        self._data_mesh_data,
        rt.MeshDrawMode.POINTS,
        _data_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    assert(self._instance_mesh ~= nil)

    for entry in values(_data_mesh_format) do
        self._instance_mesh:attach_attribute(
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

    local r, g, b, a = settings.room_color:unpack()
    local function add_vertex(x, y, z, u, v)
        table.insert(room_mesh_data, {
            x, y, z,
            u, v,
            hue * r, hue * g, hue * b, 1
        })
    end

    -- back wall
    hue = 1
    add_vertex(min_x, min_y, max_z, 0, 1)
    add_vertex(max_x, min_y, max_z, 1, 1)
    add_vertex(max_x, max_y, max_z, 1, 0)
    add_vertex(min_x, max_y, max_z, 0, 0)

    -- top wall
    hue = 2
    add_vertex(min_x, min_y, min_z, 0, 1)
    add_vertex(max_x, min_y, min_z, 1, 1)
    add_vertex(max_x, min_y, max_z, 1, 0)
    add_vertex(min_x, min_y, max_z, 0, 0)

    -- bottom wall
    hue = 2
    add_vertex(min_x, max_y, max_z, 0, 1)
    add_vertex(max_x, max_y, max_z, 1, 1)
    add_vertex(max_x, max_y, min_z, 1, 0)
    add_vertex(min_x, max_y, min_z, 0, 0)

    -- right wall
    hue = 1.5
    add_vertex(max_x, min_y, min_z, 0, 1)
    add_vertex(max_x, max_y, min_z, 1, 1)
    add_vertex(max_x, max_y, max_z, 1, 0)
    add_vertex(max_x, min_y, max_z, 0, 0)

    -- left wall
    hue = 1.5
    add_vertex(min_x, min_y, max_z, 0, 1)
    add_vertex(min_x, max_y, max_z, 1, 1)
    add_vertex(min_x, max_y, min_z, 1, 0)
    add_vertex(min_x, min_y, min_z, 0, 0)

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
