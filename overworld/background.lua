require "common.quaternion"
require "common.widget"
require "common.render_texture_3d"

rt.settings.overworld.background = {
    n_particles = 1000,
    min_scale = 0.8,
    max_scale = 2,
    fov = 0.3,
    min_depth = 50,
    max_depth = 200,
    n_point_lights = 3,
    
    min_rotation_speed = 0.02, -- radians per second
    max_rotation_speed = 0.05,

    z_zoom = 0, -- camera position towards z axis
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
    { location = 5, name = "rotation", format = "floatvec4"}, -- quaternion
    { location = 6, name = "color", format = "floatvec4" }
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
    self._scale_transform = rt.Transform()
    self._point_lights = {}
end

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)

    self._canvas = rt.RenderTexture3D(width, height, 8)
    self._canvas:set_fov(rt.settings.overworld.background.fov)
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

        local scale = self:_get_scale_factor()
        transform:scale(scale, scale, 1)
        transform:translate(0, 0, rt.settings.overworld.background.z_zoom)

        self._canvas:set_view_transform(transform)
        self._room_mesh:draw()

        transform:apply(self._offset_transform)

        local cx, cy, cz, _ = self._offset_transform:transform_point(0, 0, 0)
        self._canvas:set_view_transform(transform)
        _particle_shader:bind()
        _particle_shader:send("point_lights", { 0, 0, 150 })
        _particle_shader:send("n_point_lights", 1)
        _particle_shader:send("camera_offset", { cx, cy, cz })
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
    local t = delta * 4
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
            return right + (left - x), true
        elseif x > right then
            return left + (right - x), true
        else
            return x, false
        end
    end

    local inv_sqrt3 = 1 / math.sqrt(3)

    for data_i, data in ipairs(self._data_mesh_data) do
        local aux_data = self._data_mesh_data_aux[data_i]
        
        local x, y, z, r = data[1], data[2], data[3], data[4]

        if is_outside(x, y, z, r) then
            local x_wrap, y_wrap, z_wrap = false, false, false
            x, x_wrap = wrap(x, min_x, max_x)
            y, y_wrap = wrap(y, min_y, max_y)
            z, z_wrap = wrap(z, min_z, max_z)

            -- warp particle to other side of screen, uses
            -- noise for deterministic patterning
            if x_wrap ~= y_wrap then
                if x_wrap then
                    y = math.mix(min_y, max_y, rt.random.noise(x, y))
                end

                if y_wrap then
                    x = math.mix(min_x, max_x, rt.random.noise(x, y))
                end
            end

            data[1], data[2], data[3] = x, y, z
        end

        -- update rotation
        local angle = delta * 2 * math.pi * aux_data.rotation_speed
        local axis_x, axis_y, axis_z = table.unpack(aux_data.rotation_axis)
        data[5], data[6], data[7], data[8] = math.quaternion.normalize(math.quaternion.multiply(
            data[5], data[6], data[7], data[8],
            math.quaternion.from_axis_angle(axis_x, axis_y, axis_z, angle) -- angle delta
        ))
    end

    self._data_mesh:replace_data(self._data_mesh_data)
end

function ow.Background:_init_cube_mesh()
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
--- Compute a scale factor such that, when applied to X and Y (not Z),
--- the back wall of the room fills the view frustum and no side/top/bottom walls are visible.
--- Returns a scalar s; apply as scale(s, s, 1).
function ow.Background:_get_scale_factor()
    local aspect = self._bounds.width / self._bounds.height

    -- Use the same FOV convention as RenderTexture3D (stored as fraction of pi)
    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)

    local settings = rt.settings.overworld.background
    local near_z = settings.min_depth
    local far_z = settings.max_depth
    local z_zoom = settings.z_zoom or 0

    -- Effective back-wall depth after the z translation applied during draw
    local z_back_eff = far_z + z_zoom

    -- Room dimensions were derived from the near plane extents with a margin for max cube radius.
    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local s_norm = 1 / math.sqrt(3)
    local max_radius = s_norm * settings.max_scale

    -- Half sizes of the room opening (constructed once, independent of camera zoom)
    local room_half_w = math.max(half_w_near - max_radius, 1e-6)
    local room_half_h = math.max(half_h_near - max_radius, 1e-6)

    -- Frustum half sizes at the effective back-wall depth
    local half_h_back = tan_half * z_back_eff
    local half_w_back = half_h_back * aspect

    -- Uniform XY scale so the back wall fills in both dimensions
    local sx = half_w_back / room_half_w
    local sy = half_h_back / room_half_h
    return math.max(sx, sy)
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

    min_z = min_z + max_scale -- sic, prevent cubes spawning such that they would keep warping
    max_z = max_z - max_scale

    -- Spatial hashing parameters
    local cell_size = max_scale * 2  -- Ensure cells can accommodate the largest possible cube
    local spatial_grid = {}

    -- Helper function to get grid key from position
    local function get_grid_key(x, y, z)
        local cx = math.floor(x / cell_size)
        local cy = math.floor(y / cell_size)
        local cz = math.floor(z / cell_size)
        return string.format("%d,%d,%d", cx, cy, cz)
    end

    -- Helper function to check if position is valid (no overlaps)
    local function is_position_valid(x, y, z, scale, max_attempts)
        max_attempts = max_attempts or 100

        -- Get all neighboring cells to check
        local neighbors = {}
        local search_radius = math.ceil(scale / cell_size) + 1

        for dx = -search_radius, search_radius do
            for dy = -search_radius, search_radius do
                for dz = -search_radius, search_radius do
                    local key = get_grid_key(x + dx * cell_size, y + dy * cell_size, z + dz * cell_size)
                    if spatial_grid[key] then
                        for _, existing_cube in ipairs(spatial_grid[key]) do
                            table.insert(neighbors, existing_cube)
                        end
                    end
                end
            end
        end

        -- Check distance to all neighboring cubes
        for _, cube in ipairs(neighbors) do
            local dx = x - cube.x
            local dy = y - cube.y
            local dz = z - cube.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            local min_distance = scale + cube.scale

            if distance < min_distance then
                return false
            end
        end

        return true
    end

    self._data_mesh_data = {}
    self._data_mesh_data_aux = self._data_mesh_data_aux or {}

    local placed_cubes = 0
    local attempts = 0
    local max_attempts = n_particles * 10  -- Prevent infinite loops

    while placed_cubes < n_particles and attempts < max_attempts do
        local scale = math.mix(min_scale, max_scale, rt.random.number(0, 1))
        local x = rt.random.number(min_x, max_x)
        local y = rt.random.number(min_y, max_y)
        local z = rt.random.number(min_z, max_z)

        attempts = attempts + 1

        -- Check if this position is valid (no overlaps)
        if is_position_valid(x, y, z, scale) then
            -- Add to spatial grid
            local key = get_grid_key(x, y, z)
            if not spatial_grid[key] then
                spatial_grid[key] = {}
            end
            table.insert(spatial_grid[key], {x = x, y = y, z = z, scale = scale})

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

            placed_cubes = placed_cubes + 1
            attempts = 0  -- Reset attempts counter after successful placement
        end
    end

    -- Log placement statistics
    if placed_cubes < n_particles then
        print(string.format("Warning: Only placed %d out of %d cubes due to spatial constraints", placed_cubes, n_particles))
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
            0, 0, 0, 1 --1, 1, 1, 1 --rt.lcha_to_rgba(0.5, 1, hue, 1)
        })
    end

    -- back wall (farthest from camera)
    -- front wall
    hue = 0 / 6
    add_vertex(min_x, min_y, min_z, 0, 1) -- Flipped
    add_vertex(max_x, min_y, min_z, 1, 1) -- Flipped
    add_vertex(max_x, max_y, min_z, 1, 0) -- Flipped
    add_vertex(min_x, max_y, min_z, 0, 0) -- Flipped

    -- top wall
    hue = 1 / 6
    add_vertex(min_x, min_y, min_z, 0, 1) -- Flipped
    add_vertex(max_x, min_y, min_z, 1, 1) -- Flipped
    add_vertex(max_x, min_y, max_z, 1, 0) -- Flipped
    add_vertex(min_x, min_y, max_z, 0, 0) -- Flipped

    -- bottom wall
    hue = 2 / 6
    add_vertex(min_x, max_y, max_z, 0, 1) -- Flipped
    add_vertex(max_x, max_y, max_z, 1, 1) -- Flipped
    add_vertex(max_x, max_y, min_z, 1, 0) -- Flipped
    add_vertex(min_x, max_y, min_z, 0, 0) -- Flipped

    -- right wall
    hue = 3 / 6
    add_vertex(max_x, min_y, min_z, 0, 1) -- Flipped
    add_vertex(max_x, max_y, min_z, 1, 1) -- Flipped
    add_vertex(max_x, max_y, max_z, 1, 0) -- Flipped
    add_vertex(max_x, min_y, max_z, 0, 0) -- Flipped

    -- left wall
    hue = 4 / 6
    add_vertex(min_x, min_y, max_z, 0, 1) -- Flipped
    add_vertex(min_x, max_y, max_z, 1, 1) -- Flipped
    add_vertex(min_x, max_y, min_z, 1, 0) -- Flipped
    add_vertex(min_x, min_y, min_z, 0, 0) -- Flipped

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
