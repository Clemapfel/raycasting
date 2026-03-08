require "common.contour"
require "overworld.movable_object"

rt.settings.overworld.bubble_field = {
    segment_length = 10,
    n_smoothing_iterations = 2,
    wave_deactivation_threshold = 1 / 1000,
    excitation_amplitude = 0.0001,
    opacity = 0.4,

    particles = {
        min_radius = 2,
        max_radius = 5,

        hue_offset = 0.1,

        min_count = 4,
        max_count = 75,

        min_velocity = 300, -- factor
        max_velocity = 500,

        spread_angle = 0.25 * math.pi,
        upwards_bias = 0.25,

        min_mass = 4,
        max_mass = 10,

        gravity = 40 -- px / s
    }
}

--- @class ow.BubbleField
--- @types Polygon, Rectangle, Ellipse
--- @field inverted Boolean? if false, non-bubble -> bubble, otherwise bubble -> non-bubble
ow.BubbleField = meta.class("BubbleField", ow.MovableObject)

-- shape mesh data members
local _origin_x_index = 1
local _origin_y_index = 2
local _dx_index = 3
local _dy_index = 4
local _magnitude_index = 5

-- data mesh members
local _scale_index = 1

-- wave equation solver parameters
local _dx = 0.2
local _dt = 0.05
local _damping = 0.99
local _courant = _dt / _dx

local _base_shader = rt.Shader("overworld/objects/bubble_field.glsl", { MODE = 0 })
local _outline_shader = rt.Shader("overworld/objects/bubble_field.glsl", { MODE = 1 })

local _noise_texture = rt.NoiseTexture(64, 64, 8,
    rt.NoiseType.GRADIENT, 16
)

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    -- collision
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._x, self._y = self._body:get_position()

    self._inverted = object:get_boolean("inverted")
    if self._inverted == nil then self._inverted = false end

    local start_b = not self._inverted
    local end_b = self._inverted

    self._collision_start = function(self)
        local player = self._scene:get_player()
        if player:get_is_bubble() == (not start_b) then
            player:request_is_bubble(self, start_b)
            self._is_active = true

            local x, y = player:get_position()
            local vx, vy = player:get_velocity()
            self:_excite_wave(x, y, vx, vy, -1, false) -- inward
        end
    end

    self._collision_end = function(self)
        local player = scene:get_player()
        if player:get_is_bubble() == (not end_b) then
            player:request_is_bubble(self, end_b)
            local x, y = player:get_position()
            local vx, vy = player:get_velocity()
            self:_excite_wave(x, y, vx, vy, 1, true) -- outwards
            self._is_active = true
        end
    end

    self._is_colliding = false

    -- contour
    local contour = object:create_contour() -- flat array: {x1, y1, x2, y2, ..., xn, yn}

    -- subdivide contour
    local subdivided = rt.contour.subdivide(contour, rt.settings.overworld.bubble_field.segment_length * rt.get_pixel_scale())

    -- laplacian smoothing
    local n_smoothing_iterations = rt.settings.overworld.bubble_field.n_smoothing_iterations
    local points = rt.contour.smooth(subdivided, n_smoothing_iterations)

    -- compute center and mesh data
    self._contour = points

    local center_x, center_y, n = 0, 0, 0
    for i = 1, #points, 2 do
        local x, y = points[i], points[i+1]
        center_x = center_x + x
        center_y = center_y + y
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n

    -- meshes
    self._shape_mesh_data = {} -- constant
    self._data_mesh_data = {} -- uploaded each frame

    local triangulation = rt.DelaunayTriangulation(points, points):get_triangle_vertex_map()

    local shape_mesh_format = {
        { location = 0, name = "origin", format = "floatvec2" }, -- absolute xy
        { location = 1, name = "contour_vector", format = "floatvec3" } -- normalized xy, magnitude
    }

    local data_mesh_format = {
        { location = 2, name = "scale", format = "float" }
    }

    -- construct contour vectors
    local target_magnitude = 100
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i+0], self._contour[i+1]
        local origin_x, origin_y = center_x, center_y
        local dx, dy = x - origin_x, y - origin_y

        -- rescale origin such that each point has same magnitude, while
        -- mainting end point x, y
        dx, dy = math.normalize(dx, dy)
        local magnitude = target_magnitude
        origin_x = x - dx * magnitude
        origin_y = y - dy * magnitude

        table.insert(self._shape_mesh_data, {
            [_origin_x_index] = origin_x,
            [_origin_y_index] = origin_y,
            [_dx_index] = dx,
            [_dy_index] = dy,
            [_magnitude_index] = magnitude
        })

        table.insert(self._data_mesh_data, {
            [_scale_index] = 1
        })
    end

    self._contour_center_x, self._contour_center_y = center_x, center_y

    self._shape_mesh = rt.Mesh(
        self._shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    self._shape_mesh:set_vertex_map(triangulation)

    self._data_mesh = rt.Mesh(
        self._data_mesh_data,
        rt.MeshDrawMode.POINTS,
        data_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    self._shape_mesh:attach_attribute(self._data_mesh, "scale", "pervertex")

    -- wave equation solver
    self._elapsed = 0
    self._n_points = #self._shape_mesh_data
    self._wave = {
        previous = table.rep(0, self._n_points),
        current = table.rep(0, self._n_points),
        next = {}
    }

    -- particles
    self._batches = {}
end

local _x_offset = 0
local _y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _radius_offset = 4
local _mass_offset = 5
local _r_offset = 6
local _g_offset = 7
local _b_offset = 8
local _is_disabled_offset = 9

local FALSE, TRUE = 0, 1

local _stride = _is_disabled_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

--- @brief
function ow.BubbleField:_excite_wave(x, y, velocity_x, velocity_y, sign, spawn_particles)
    local min_distance, min_i = math.huge, nil
    for i = 1, self._n_points do
        local data = self._shape_mesh_data[i]
        local dx, dy, magnitude = data[_dx_index], data[_dy_index], data[_magnitude_index]
        local vx = self._contour_center_x + dx * magnitude
        local vy = self._contour_center_y + dy * magnitude
        local distance = math.distance(x, y, vx, vy)
        if distance < min_distance then
            min_distance = distance
            min_i = i
        end
    end

    local center_index, amplitude, width = min_i, sign * math.magnitude(velocity_x, velocity_y) * rt.settings.overworld.bubble_field.excitation_amplitude, 5
    for i = 1, self._n_points do
        local distance = math.abs(i - center_index)
        distance = math.min(distance, self._n_points - distance)
        self._wave.current[i] = self._wave.current[i] + amplitude * math.exp(-((distance / width) ^ 2))
    end

    self._is_active = true

    if not spawn_particles then return end

    local settings = rt.settings.overworld.bubble_field.particles
    do
        local base_hue = self._scene:get_player():get_hue()
        local batch = {}
        local magnitude = math.magnitude(velocity_x, velocity_y)
        local dx, dy = math.normalize(velocity_x, velocity_y)

        local n_particles = rt.random.integer(
            settings.min_count,
            settings.max_count,
            math.min(1, magnitude / rt.settings.player.bubble_target_velocity)
        )

        batch.n_particles = n_particles
        batch.data = {}

        local data = batch.data
        -- perpendicular axis for angular spread (rotate direction 90 degrees)
        local perp_x, perp_y = -dy, dx

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)  -- use the same stride fn as the update loop
            data[i + _x_offset] = x
            data[i + _y_offset] = y

            local speed = rt.random.number(settings.min_velocity, settings.max_velocity)
            local spread = rt.random.number(-settings.spread_angle, settings.spread_angle)
            local cos_s, sin_s = math.cos(spread), math.sin(spread)
            local vx = (dx * cos_s - dy * sin_s) * speed
            local vy = (dx * sin_s + dy * cos_s) * speed

            -- bias upward slightly so particles arc against gravity instead of drooping immediately
            local gravity = rt.settings.overworld.bubble_field.particles.gravity
            local mass = rt.random.number(settings.min_mass, settings.max_mass)
            vy = vy - gravity * mass * settings.upwards_bias  -- upward_bias ~0.1–0.3 s, tune freely

            data[i + _velocity_x_offset] = vx
            data[i + _velocity_y_offset] = vy

            data[i + _radius_offset] = rt.random.number(settings.min_radius, settings.max_radius)
            data[i + _mass_offset] = mass

            local hue = base_hue + rt.random.number(-settings.hue_offset, settings.hue_offset)
            local r, g, b = rt.lcha_to_rgba(0.8, 1, hue, 1)
            data[i + _r_offset] = r
            data[i + _g_offset] = g
            data[i + _b_offset] = b

            data[i + _is_disabled_offset] = FALSE
        end

        table.insert(self._batches, batch)
    end
end

--- @brief
function ow.BubbleField:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end


    local current = self._is_colliding
    local next = self._body:test_point(self._scene:get_player():get_position())
    if current == false and next == true then
        self:_collision_start()
    elseif current == true and next == false then
        self:_collision_end()
    end

    self._is_colliding = next

    self._elapsed = self._elapsed + delta

    if self._is_active and not rt.GameState:get_is_performance_mode_enabled() then
        local n_points = self._n_points
        local offset_max = 0
        local wave_previous, wave_current, wave_next = self._wave.previous, self._wave.current, self._wave.next

        for i = 1, n_points do
            local left = math.wrap(i-1, n_points)
            local right = math.wrap(i+1, n_points)

            local new = 2 * wave_current[i] - wave_previous[i] + _courant^2 * (wave_current[left] - 2 * wave_current[i] + wave_current[right])
            new = new * _damping
            wave_next[i] = new

            local abs_new = math.abs(new)
            offset_max = math.max(offset_max, abs_new)

            local data = self._shape_mesh_data[i]
            local dx, dy, magnitude = data[_dx_index], data[_dy_index], data[_magnitude_index]
            local origin_x, origin_y = data[_origin_x_index], data[_origin_y_index]
            local idx = (i - 1) * 2
            local scale = 1 + new
            self._contour[idx + 1] = origin_x + scale * dx * magnitude
            self._contour[idx + 2] = origin_y + scale * dy * magnitude
            self._data_mesh_data[i][_scale_index] = scale
        end

        self._wave.previous, self._wave.current, self._wave.next = wave_current, wave_next, wave_previous
        self._data_mesh:replace_data(self._data_mesh_data)

        if offset_max < rt.settings.overworld.bubble_field.wave_deactivation_threshold then
            self._is_active = false
        end
    end

    local to_remove = {}
    local bounds = self._scene:get_camera():get_world_bounds()
    local gravity_dx, gravity_dy = 0, 1

    for batch_i, batch in ipairs(self._batches) do
        local data = batch.data
        local gravity = rt.settings.overworld.bubble_field.particles.gravity
        local should_remove = true


        for particle_i = 1, batch.n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            if data[i + _is_disabled_offset] == FALSE then
                local vx = data[i + _velocity_x_offset]
                local vy = data[i + _velocity_y_offset]
                local x  = data[i + _x_offset]
                local y  = data[i + _y_offset]
                local mass = data[i + _mass_offset]

                vx = vx + gravity * gravity_dx * mass * delta
                vy = vy + gravity * gravity_dy * mass * delta

                x = x + vx * delta
                y = y + vy * delta

                data[i + _x_offset]                = x
                data[i + _y_offset]                = y
                data[i + _velocity_x_offset]       = vx
                data[i + _velocity_y_offset]       = vy

                data[i + _is_disabled_offset] = ternary(bounds:contains(x, y), FALSE, TRUE)

                should_remove = false
            end
        end

        if should_remove then
            table.insert(to_remove, 1, batch_i)  -- insert in reverse so removals don't shift indices
        end
    end

    for i in values(to_remove) do
        table.remove(self._batches, i)
    end
end

--- @brief
function ow.BubbleField:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local transform = self._scene:get_camera():get_transform():inverse()

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(-self._x + offset_x, -self._y + offset_y)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")

    local elapsed = rt.SceneManager:get_elapsed() + meta.hash(self)
    local hue = self._scene:get_player():get_hue()

    love.graphics.setColor(1, 1, 1, rt.settings.overworld.bubble_field.opacity)
    _base_shader:bind()
    _base_shader:send("noise_texture", _noise_texture)
    _base_shader:send("screen_to_world_transform", transform)
    _base_shader:send("elapsed", elapsed)
    _base_shader:send("hue", hue)
    _base_shader:send("hue_offset", rt.settings.overworld.bubble_field.particles.hue_offset)
    love.graphics.draw(self._shape_mesh:get_native())

    _base_shader:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")
    _outline_shader:bind()
    _outline_shader:send("noise_texture", _noise_texture)
    _outline_shader:send("screen_to_world_transform", transform)
    _outline_shader:send("elapsed", elapsed)
    _outline_shader:send("hue", hue)

    -- Draw a closed outline without duplicating vertices in the solver/mesh data
    local closed_contour = {}
    for i = 1, #self._contour do
        closed_contour[i] = self._contour[i]
    end
    rt.contour.close(closed_contour)
    love.graphics.line(closed_contour)

    _outline_shader:unbind()


    for batch in values(self._batches) do
        local data = batch.data
        for particle_i = 1, batch.n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            if data[i + _is_disabled_offset] == FALSE then
                love.graphics.setColor(
                    data[i + _r_offset],
                    data[i + _g_offset],
                    data[i + _b_offset],
                    1
                )
                love.graphics.circle("fill",
                    data[i + _x_offset],
                    data[i + _y_offset],
                    data[i + _radius_offset]
                )
            end
        end
    end

    love.graphics.pop()
end

--- @brief
function ow.BubbleField:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    local transform = self._scene:get_camera():get_transform():inverse()

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(-self._x + offset_x, -self._y + offset_y)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")

    _outline_shader:bind()
    -- Keep shader inputs consistent with main draw to avoid undefined behavior in the bloom pass
    local elapsed = rt.SceneManager:get_elapsed() + meta.hash(self)
    local hue = self._scene:get_player():get_hue()
    _outline_shader:send("noise_texture", _noise_texture)
    _outline_shader:send("screen_to_world_transform", transform)
    _outline_shader:send("elapsed", elapsed)
    _outline_shader:send("hue", hue)

    local closed_contour = {}
    for i = 1, #self._contour do
        closed_contour[i] = self._contour[i]
    end
    rt.contour.close(closed_contour)
    love.graphics.line(closed_contour)

    _outline_shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.BubbleField:reset()
    self._wave.next = {}
    for i = 1, self._n_points do
        self._wave.previous[i] = 0
        self._wave.current[i] = 0
    end
    self:update(0)
end