require "overworld.tether"

rt.settings.overworld.objects.portal = {
    mesh_w = 100, -- px
    pulse_duration = 1, -- s
    transition_min_speed = 400,
    transition_speed_factor = 1.5,
    particle = {
        radius = 20,
        min_speed = 10, -- px / s
        max_speed = 20,
        min_scale = 0.3,
        max_scale = 0.6,
        coverage = 5,
        collapse_speed = 10, -- fraction
    },

    min_velocity_magnitude = 500, -- px/s, when exiting portal
    impulse_max_scale = 1.2,
    velocity_angle_min_threshold = math.degrees_to_radians(15)
}

--- @class ow.Portal
--- @types Point
--- @field target ow.Portal! other portal to teleport to
--- @field other ow.PortalNode! second node of line, winding order matters
--- @field left_or_right Boolean? override winding order
ow.Portal = meta.class("Portal", ow.MovableObject)

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _particle_texture -- rt.RenderTexture

local _pulse_shader = rt.Shader("overworld/objects/portal.glsl")
local _particle_shader = rt.Shader("overworld/objects/portal_particles.glsl")

-- orientation of portal (line vertex winding order)
local _LEFT = true
local _RIGHT = not _LEFT

-- particle directions
local _FORWARD = true
local _BACKWARDS = not _FORWARD

-- particle properties
local _x = 1
local _y = 2
local _direction = 3
local _speed = 4
local _scale = 5
local _t = 6

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    if _particle_texture == nil then
        local radius = rt.settings.overworld.objects.portal.particle.radius
        local padding = 3
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))

        local mesh = rt.MeshCircle(0, 0, radius)
        mesh:set_vertex_color(1, 1, 1, 1)
        for i = 2, mesh:get_n_vertices() do
            mesh:set_vertex_color(i, 1, 1, 1, 0)
        end

        love.graphics.push()
        love.graphics.origin()
        _particle_texture:bind()
        love.graphics.translate(0.5 * _particle_texture:get_width(), 0.5 * _particle_texture:get_width())
        mesh:draw()
        _particle_texture:unbind()
        love.graphics.pop()
    end

    self._stage = stage
    self._world = self._stage:get_physics_world()
    self._scene = scene
    self._object = object

    self._pulse_elapsed = math.huge
    self._pulse_value = 0
    self._impulse = rt.ImpulseSubscriber()

    self._hue = 0
    self._hue_set = false

    self._direction = object:get_boolean("left_or_right", false)
    if self._direction == nil then self._direction = _LEFT end

    self._transition_active = false
    self._transition_elapsed = math.huge
    self._transition_velocity_x, self._transition_velocity_y = 0, 0
    self._transition_speed = 0

    -- collapse point where player enters, normalized to 0, 1
    self._entry_t = 0.5

    -- particles
    self._particles = {}
    self._static_canvas = nil
    self._canvas_x, self._canvas_y, self._canvas_angle = 0, 0, 0
    self._canvas_needs_update = false
    self._collapse_active = false

    self._stage:signal_connect("respawn", function()
        self._transition_active = false
        self._collapse_active = false
    end)

    -- wait for initialization, then set up geometry
    self._ax, self._ay, self._bx, self._by = nil, nil, nil, nil
    self._offset_x, self._offset_y = 0, 0

    stage:signal_connect("initialized", function()
        do -- read segment position, move to origin
            if not object:get_type() == ow.ObjectType.POINT then
                rt.error("In ow.Portal: object `", object:get_id(), "` is not a point")
            end
            local ax, ay = object.x, object.y

            local other = object:get_object("other", true)
            if not other:get_type() == ow.ObjectType.POINT then
                rt.error("In ow.Portal: object `", other:get_id(), "` is not a point")
            end

            if not other:get_class() == meta.get_typename(ow.PortalNode) then
                rt.error("In ow.Portal: object `", other:get_id(), "` is not a `PortalNode`, despite being the `target` of portal `", object:get_id(), "`")
            end
            local bx, by = other.x, other.y

            self._offset_x, self._offset_y = math.mix2(ax, ay, bx, by, 0.5)
            self._ax = ax - self._offset_x
            self._ay = ay - self._offset_y
            self._bx = bx - self._offset_x
            self._by = by - self._offset_y
        end

        self._target = stage:object_wrapper_to_instance(object:get_object("target", true))
        assert(self._target ~= nil and meta.isa(self._target, ow.Portal), "In ow.Portal: `target` of object `" .. object:get_id() .. "` is not another portal")

        -- synch hue between portals, whoever gets initialized first decides
        if self._hue_set == false and self._target._hue_set == true then
            self._hue = self._target._hue
        elseif self._hue_set == true and self._target._hue_set == false then
            self._target._hue = self._hue
        elseif self._hue_set == false and self._target._hue_set == false then
            self._hue = (object:get_id() % 16) / 16
            self._target._hue = self._hue
        end

        self._hue_set = true
        self._target._hue_set = true
        self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }
        self._target._color = self._color

        -- setup geometry
        local dx, dy = math.normalize(self._ax - self._bx, self._ay - self._by)
        local left_x, left_y = math.turn_left(dx, dy)
        local right_x, right_y = math.turn_right(dx, dy)

        if self._direction == _LEFT then
            self._normal_x, self._normal_y = left_x, left_y
        else
            self._normal_x, self._normal_y = right_x, right_y
        end

        self._is_disabled = false

        -- sensor that triggers teleportation sequence
        local segment_w = rt.settings.player.radius * rt.settings.player.bubble_radius_factor * 0.5
        self._segment_sensor = b2.Body(
            self._world,
            object:get_physics_body_type(),
            self._offset_x, self._offset_y,
            b2.Polygon(
                self._ax, self._ay,
                self._ax + self._normal_x * segment_w, self._ay + self._normal_y * segment_w ,
                self._bx + self._normal_x * segment_w, self._by + self._normal_y * segment_w,
                self._bx, self._by
            )
        )

        self._segment_sensor:set_use_continuous_collision(true)
        self._segment_sensor:set_collides_with(rt.settings.player.bounce_collision_group)
        self._segment_sensor:set_collision_group(rt.settings.player.bounce_collision_group)
        self._segment_sensor:add_tag("unjumpable", "slippery")
        self._segment_sensor:add_tag("segment_light_source")
        self._segment_sensor:set_user_data(self)
        self._segment_sensor:set_is_sensor(true)

        -- area sensor, used to detect if player exited area so portal can reset
        local sensor_w = rt.settings.player.radius
        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w, self._ay +  left_y * sensor_w,
            self._ax + right_x * sensor_w, self._ay + right_y * sensor_w,
            self._bx + right_x * sensor_w, self._by + right_y * sensor_w,
            self._bx +  left_x * sensor_w, self._by +  left_y * sensor_w
        )

        self._area_sensor = b2.Body(
            self._world,
            object:get_physics_body_type(),
            self._offset_x, self._offset_y,
            sensor_shape
        )
        self._area_sensor:set_is_sensor(true)

        local transition_stencil_shape
        do -- transition stencil and mesh, at origin
            local outer = function() return 0, 0, 0, 0 end
            local inner = function() return 1, 1, 1, 1 end

            local w = rt.settings.overworld.objects.portal.mesh_w
            local stencil_w = 2 * rt.settings.native_height
            -- long enough to hide player moving off-screen during transition

            local padding = rt.settings.player.radius * rt.settings.player.bubble_radius_factor
            local ax, ay = self._ax + dx * padding, self._ay + dy * padding
            local bx, by = self._bx - dx * padding, self._by - dy * padding

            if self._direction == _LEFT then
                local left_mesh_data = {
                    { ax + left_x * w, ay + left_y * w, 0, 1, outer() },
                    { ax, ay, 0, 0, inner() },
                    { bx, by, 1, 0, inner() },
                    { bx + left_x * w, by + left_y * w, 1, 1, outer() }
                }

                self._left_mesh = rt.Mesh(left_mesh_data)
            else
                local right_mesh_data = {
                    { ax, ay, 1, 0, inner() },
                    { ax + right_x * w, ay + right_y * w, 1, 1, outer() },
                    { bx + right_x * w, by + right_y * w, 0, 1, outer() },
                    { bx, by, 0, 0, inner() }
                }

                self._right_mesh = rt.Mesh(right_mesh_data)
            end
        end

        local stencil_r = 2 * rt.settings.player.radius * rt.settings.player.bubble_radius_factor
        self._transition_stencil = b2.Body(
            self._world,
            self._object:get_physics_body_type(),
            -b2.huge, -b2.huge,
            b2.Rectangle(
                -stencil_r, -stencil_r,
                2 * stencil_r, 2 * stencil_r
            )
        )
        self._transition_stencil_radius = stencil_r
        self._transition_stencil:set_collides_with(0x0)
        self._transition_stencil:set_collision_group(0x0)
        self._transition_stencil:add_tag("unjumpable", "stencil", "core_stencil")
        self:_set_stencil_enabled(false)

        -- start teleportation sequence
        self._segment_sensor:signal_connect("collision_start", function(self_body, other_body, nx, ny, contact_x, contact_y)

            -- check if directed vector points towards or away from line
            local function velocity_towards_line(ax, ay, bx, by, vx, vy)
                local dx, dy = math.normalize(ax - bx, ay - by)
                local left_x, left_y = math.turn_left(dx, dy)
                local proj = math.dot(vx, vy, left_x, left_y)

                -- normalize velocity to get accurate angle calculation
                local vx_norm, vy_norm = math.normalize(vx, vy)
                local dot_parallel = math.abs(math.dot(vx_norm, vy_norm, dx, dy))

                -- check if angle is shallower than 15 degrees
                local threshold = math.cos(rt.settings.overworld.objects.portal.velocity_angle_min_threshold)
                if dot_parallel > threshold then
                    return nil
                end

                local eps = 1e-5
                if proj < -eps then
                    return _LEFT
                elseif proj > eps then
                    return _RIGHT
                else
                    return nil  -- parallel case
                end
            end

            -- get t in 0, 1 of closest point on line to px, py
            local function t_on_line(x1, y1, x2, y2, px, py)
                local segment_vec_x = x2 - x1
                local segment_vec_y = y2 - y1
                local point_vec_x = px - x1
                local point_vec_y = py - y1

                local t = math.dot(point_vec_x, point_vec_y, segment_vec_x, segment_vec_y) /
                    math.dot(segment_vec_x, segment_vec_y, segment_vec_x, segment_vec_y)

                return 1 - math.clamp(t, 0, 1), math.mix2(x1, y1, x2, y2, t)
            end

            if not self._is_disabled then
                local player = self._scene:get_player()
                local offset_x, offset_y = self._offset_x, self._offset_y
                local ax, ay = self._ax + offset_x, self._ay + offset_y
                local bx, by = self._bx + offset_x, self._by + offset_y

                local player_vx, player_vy = player:get_physics_body():get_velocity() -- use sim velocity

                -- if player moves towards portal on the correct side
                if self._direction == velocity_towards_line(
                    ax, ay, bx, by,
                    player_vx, player_vy
                ) then -- use sim velocity
                    do -- compute closest point
                        local ab_x = bx - ax
                        local ab_y = by - ay
                        local ap_x, ap_y = player:get_position()
                        ap_x = ap_x - ax
                        ap_y = ap_y - ay

                        local ab_length_squared = math.dot(ab_x, ab_y, ab_x, ab_y)
                        if ab_length_squared == 0 then
                            contact_x, contact_y = ax, ay
                        else
                            local t = math.clamp(math.dot(ap_x, ap_y, ab_x, ab_y) / ab_length_squared, 0, 1)
                            contact_x = ax + t * ab_x
                            contact_y = ay + t * ab_y
                        end
                    end

                    -- find where to contract particles to on this portal
                    self._entry_t = t_on_line(ax, ay, bx, by, contact_x, contact_y)

                    -- on target, always choose center
                    self._target._entry_t = 0.5

                    -- animation tied to player velocity magnitude
                    self._pulse_elapsed = 0
                    self._collapse_active = true

                    self._transition_active = true
                    self:_set_stencil_enabled(true)
                    self._target:_set_stencil_enabled(true)


                    self._transition_elapsed = 0
                    self._transition_speed = math.max(
                        rt.settings.overworld.objects.portal.transition_speed_factor * math.magnitude(player_vx, player_vy),
                        rt.settings.overworld.objects.portal.transition_min_speed
                    )
                    self._transition_velocity_x, self._transition_velocity_y = player_vx, player_vy

                    -- disable player
                    self:_set_player_disabled(true)
                end
            end
        end)

        -- setup tether, wait for first update since both portals need to have been fully initialized
        self._world:signal_connect("step", function(_)
            if self._has_tether == nil then
                local other = self._target

                self._has_tether = true
                other._has_tether = false

                local from_x, from_y = self._offset_x, self._offset_y
                local to_x, to_y = other._offset_x, other._offset_y

                self._tether = ow.Tether():tether(
                    from_x, from_y,
                    to_x, to_y
                )
            end

            return meta.DISCONNECT_SIGNAL
        end)

        -- particles
        local settings = rt.settings.overworld.objects.portal.particle
        local min_radius = settings.radius * settings.min_scale
        local max_radius = settings.radius * settings.max_scale

        local length = math.distance(self._ax, self._ay, self._bx, self._by)
        local n_particles = length / min_radius * settings.coverage

        local padding = 2 * max_radius
        self._static_canvas = rt.RenderTexture(
            2 * padding,
            length
        )
        self._canvas_x, self._canvas_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        self._canvas_angle = math.angle(self._bx - self._ax, self._by - self._ay) + 0.5 * math.pi

        local canvas_w, canvas_h = self._static_canvas:get_size()
        self._particle_axis = {
            0.5 * canvas_w, min_radius,
            0.5 * canvas_w, length - 2 * min_radius
        }

        if self._direction == _LEFT then
            self._particle_stencil = {
                0.5 * canvas_w, 0,
                0.5 * canvas_w, length
            }
        else
            self._particle_stencil = {
                0, 0,
                0.5 * canvas_w, length
            }
        end

        -- distribute evenly across line
        local ax, ay, bx, by = table.unpack(self._particle_axis)
        local t, direction = 0, 1
        for i = 1, n_particles do
            local x, y = math.mix2(ax, ay, bx, by, t)
            local particle = {
                [_x] = x,
                [_y] = y,
                [_speed] = rt.random.number(settings.min_speed, settings.max_speed),
                [_direction] = rt.random.choose(_FORWARD, _BACKWARDS),
                [_scale] = rt.random.number(settings.min_scale, settings.max_scale),
                [_t] = t
            }

            if direction == _FORWARD then
                t = t + min_radius / length
            else
                t = t - min_radius / length
            end

            if t > 1 then
                t = 1
                direction = not direction
            elseif t < 0 then
                t = 0
                direction = not direction
            end

            table.insert(self._particles, particle)
        end

        self._canvas_needs_update = true
    end)
end

--- @brief
function ow.Portal:_set_stencil_enabled(b)
    if b == true then
        self._transition_stencil:set_is_enabled(true)
    else
        self._transition_stencil:set_is_enabled(false)
        self._transition_stencil:set_position(-b2.huge, -b2.huge)
    end
end

--- @brief
function ow.Portal:_set_player_disabled(b)
    local player = self._scene:get_player()
    player:set_is_ghost(b)
    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
end

local function _clamp_point_to_line(ax, ay, bx, by, normal_x, normal_y, x, y)
    -- Get the line direction vector
    local line_dx = bx - ax
    local line_dy = by - ay

    -- Normalize the line direction
    line_dx, line_dy = math.normalize(line_dx, line_dy)
    local line_length = math.magnitude(bx - ax, by - ay)

    -- Normalize the normal vector
    normal_x, normal_y = math.normalize(normal_x, normal_y)

    -- Vector from line start to the point
    local to_point_x = x - ax
    local to_point_y = y - ay

    -- Distance from the point to the line (signed, positive on normal side)
    local distance = math.dot(to_point_x, to_point_y, normal_x, normal_y)

    -- If the point is on the wrong side (distance < 0), clamp it to the line
    if distance < 0 then
        -- Project the point onto the line
        local projection = math.dot(to_point_x, to_point_y, line_dx, line_dy)

        -- Clamp the projection to the line segment
        projection = math.clamp(projection, 0, line_length)

        -- Calculate the clamped point on the line
        x = ax + line_dx * projection
        y = ay + line_dy * projection
    end

    return x, y
end

--- @brief
function ow.Portal:update(delta)
    local target = self._target

    if self._object:get_physics_body_type() ~= b2.BodyType.STATIC then
        self._offset_x, self._offset_y = self._segment_sensor:get_position()
    end

    local player = self._scene:get_player()

    -- transition animation
    if self._transition_active then
        self._transition_elapsed = self._transition_elapsed + delta
        local distance_traveled = self._transition_elapsed * self._transition_speed
        local distance = math.distance(self._offset_x, self._offset_y, target._offset_x, target._offset_y)
        local t = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(distance_traveled / distance)

        local transition_x, transition_y, path
        if self._tether ~= nil then
            path = rt.Path(self._tether:get_points())
            transition_x, transition_y = path:at(t)
        else
            path = rt.Path(self._target._tether:get_points())
            transition_x, transition_y = path:at(1 - t)
        end
        self._scene:get_camera():move_to(transition_x, transition_y)

        if self._tether ~= nil then
            self:_set_buldge(t, path)
        else
            self._target:_set_buldge(t, path)
        end

        -- reposition stencil body
        do
            local player_x, player_y = player:get_position()
            local ax, ay, bx, by = self._ax + self._offset_x, self._ay + self._offset_y,
            self._bx + self._offset_x, self._by + self._offset_y

            local normal_x, normal_y = self._normal_x, self._normal_y
            local r = self._transition_stencil_radius

            -- prevent stencil from extending past line, so only that part of player is stenciled
            self._transition_stencil:set_position(_clamp_point_to_line(
                ax - normal_x * r, ay - normal_y * r, bx - normal_x * r, by - normal_y * r,
                -normal_x, -normal_y,
                player_x, player_y
            ))

            self._transition_stencil:set_rotation(math.angle(bx - ax, by - ay))
        end

        -- move player towards portal
        local magnitude = math.magnitude(self._transition_velocity_x, self._transition_velocity_y)
        magnitude = math.max(rt.settings.overworld.objects.portal.min_velocity_magnitude, magnitude)
        local dx, dy = -self._normal_x, -self._normal_y
        local portal_vx, portal_vy = math.flip(self._segment_sensor:get_velocity())
        player:set_velocity(dx * magnitude + portal_vx, dy * magnitude + portal_vy)

        -- once camera arrives, properly teleport
        if t >= 1 then
            self:_teleport()
            self:_set_player_disabled(false)
            self._scene:set_camera_mode(ow.CameraMode.AUTO)

            self._transition_active = false
            target._pulse_elapsed = 0
            target._collapse_active = true
        end
    end

    -- if disabled, constantly test if player left sensor, more reliable then collision_end
    if self._is_disabled then
        if self._area_sensor:test_point(self._scene:get_player():get_position()) == false then
            self._is_disabled = false
            self:_set_stencil_enabled(false)
        end
    end

    if self._stage:get_is_body_visible(self._area_sensor) == false then return end

    -- tether
    if self._draw_tether then
        self._tether:update(delta)
        if self._object:get_physics_body_type() ~= b2.BodyType.STATIC or target._object:get_physics_body_type() ~= b2.BodyType.STATIC then
            self._tether:tether(
                self._offset_x, self._offset_y,
                target._offset_x, target._offset_y
            )
        end
    end

    -- move particles
    self._pulse_elapsed = self._pulse_elapsed + delta
    local pulse_duration = rt.settings.overworld.objects.portal.pulse_duration
    self._pulse_value = rt.InterpolationFunctions.ENVELOPE(
        self._pulse_elapsed / pulse_duration,
        0.05,
        0.05
    )

    local ax, ay, bx, by = table.unpack(self._particle_axis)
    local length = math.distance(ax, ay, bx, by)

    local speed = rt.settings.overworld.objects.portal.particle.collapse_speed
    local collapse_mean_distance = 0

    for particle in values(self._particles) do
        local t = particle[_t]

        if particle[_direction] == _FORWARD then
            t = t + particle[_speed] / length * delta
            if t > 1 then
                t = 1
                particle[_direction] = not particle[_direction]
            end
        else
            t = t - particle[_speed] / length * delta
            if t < 0 then
                t = 0
                particle[_direction] = not particle[_direction]
            end
        end

        particle[_t] = t

        if self._collapse_active then
            t = self._entry_t
        end
        local target_x, target_y = math.mix2(ax, ay, bx, by, t)

        particle[_x] = particle[_x] + speed * (target_x - particle[_x]) * delta
        particle[_y] = particle[_y] + speed * (target_y - particle[_y]) * delta

        if self._collapse_active then
            collapse_mean_distance = collapse_mean_distance + math.distance(target_x, target_y, particle[_x], particle[_y])
        end
    end

    if self._collapse_active and collapse_mean_distance < 2 * rt.settings.overworld.objects.portal.particle.radius then
        self._collapse_active = false
    end

    self._canvas_needs_update = true
end

--- @brief
function ow.Portal:_teleport()
    local player = self._scene:get_player()
    local target = self._target

    target._is_disabled = true
    self._is_disabled = true

    -- always appear at center of target
    local new_x, new_y = target._offset_x, target._offset_y

    -- exit velocity scales with entry
    local magnitude = math.max(
        math.magnitude(self._transition_velocity_x, self._transition_velocity_y),
        rt.settings.overworld.objects.portal.min_velocity_magnitude
    )

    local player_vx, player_vy = target._normal_x * magnitude, target._normal_y * magnitude

    -- teleport to be outside collision geometry
    player:teleport_to(new_x, new_y)
    player:clear_forces()
    player:set_velocity(player_vx, player_vy)

    local elapsed = 0
    self._world:signal_connect("step", function(_, delta)
        player:set_velocity(player_vx, player_vy)
        elapsed = elapsed + delta

        if elapsed > 4 / 60 then
            return meta.DISCONNECT_SIGNAL
        end
    end)
    self._player_teleported = true

    self._transition_active = false

    -- make portals hue
    player:set_hue(self._hue)

    self:_set_stencil_enabled(false)

    -- set target stencil right behind portal
    do
        local x, y = target._offset_x, target._offset_y
        local ax, ay, bx, by = target._ax, target._ay, target._bx, target._by
        local dx, dy = math.normalize(bx - ax, by - ay)
        local angle = math.angle(dx, dy)
        if target._direction == _RIGHT then
            dx, dy = math.turn_right(dx, dy)
        else
            dx, dy = math.turn_left(dx, dy)
        end

        local radius =  target._transition_stencil_radius
        local stencil_x, stencil_y =  x + dx * radius, y + dy * radius
        target._transition_stencil:set_position(stencil_x, stencil_y)
        target._transition_stencil:set_rotation(angle)
        self._target:_set_stencil_enabled(true)
    end
end

--- @brief
function ow.Portal:_set_buldge(t, path)

end

--- @brief
function ow.Portal:draw()
    if not self._stage:get_is_body_visible(self._area_sensor) then return end

    local r, g, b, a = table.unpack(self._color)

    if self._tether ~= nil then
        love.graphics.setLineWidth(10)
        love.graphics.setColor(r, g, b, a)
        self._tether:draw()

        if self._transition_active then

        end
    end

    if self._canvas_needs_update == true then
        love.graphics.push("all")
        love.graphics.origin()
        self._static_canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        local value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
        love.graphics.rectangle("fill", table.unpack(self._particle_stencil))
        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

        local w, h = _particle_texture:get_size()
        local scale = math.mix(1, rt.settings.overworld.objects.portal.impulse_max_scale, self._impulse:get_beat())
        for particle in values(self._particles) do
            love.graphics.draw(
                _particle_texture:get_native(),
                particle[_x], particle[_y], 0,
                particle[_scale] * scale, particle[_scale] * scale,
                0.5 * w, 0.5 * h
            )
        end

        rt.graphics.set_stencil_mode(nil)

        self._static_canvas:unbind()
        love.graphics.pop("all")

        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    _particle_shader:bind()
    _particle_shader:send("hue", self._hue)
    _particle_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    _particle_shader:send("black", { black_r, black_g, black_b })
    local w, h = self._static_canvas:get_size()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self._static_canvas:get_native(),
        self._canvas_x, self._canvas_y, self._canvas_angle,
        1, 1,
        0.5 * w, 0.5 * h
    )
    _particle_shader:unbind()

    local pulse_origin_y, pulse_origin_y = math.mix2(
        self._ax, self._ay,
        self._bx, self._by,
    1 - self._entry_t
    )

    love.graphics.translate(pulse_origin_y, pulse_origin_y)
    love.graphics.scale(1 - self._pulse_value)
    love.graphics.translate(-pulse_origin_y, -pulse_origin_y)

    love.graphics.setColor(r, g, b, 1)
    _pulse_shader:bind()
    _pulse_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _pulse_shader:send("pulse", self._pulse_value)
    _pulse_shader:send("brightness_scale", math.mix(1, 2 * rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse()))
    if self._direction == _LEFT then
        self._left_mesh:draw()
    else
        self._right_mesh:draw()
    end
    _pulse_shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.Portal:draw_bloom()
    if not self._stage:get_is_body_visible(self._area_sensor) then return end

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    local pulse_origin_y, pulse_origin_y = math.mix2(
        self._ax, self._ay,
        self._bx, self._by,
        1 - self._entry_t
    )

    love.graphics.translate(pulse_origin_y, pulse_origin_y)
    love.graphics.scale(1 - self._pulse_value)
    love.graphics.translate(-pulse_origin_y, -pulse_origin_y)

    local r, g, b = table.unpack(self._color)
    love.graphics.setColor(r, g, b, 1)
    _pulse_shader:bind()
    _pulse_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _pulse_shader:send("pulse", self._pulse_value)
    _pulse_shader:send("brightness_scale", math.mix(1, 2 * rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse()))
    if self._direction == _LEFT then
        self._left_mesh:draw()
    else
        self._right_mesh:draw()
    end
    _pulse_shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end

--- @brief
function ow.Portal:get_segment_light_sources()
    local offset_x, offset_y = self._offset_x, self._offset_y
    return {{
        self._ax + offset_x, self._ay + offset_y,
        self._bx + offset_x, self._by + offset_y
    }}, { table.deepcopy(self._color) }
end

--- @brief
function ow.Portal:reset()
    self._transition_elapsed = math.huge
    self._transition_active = false
    self:update(0)
end

--- @brief
function ow.Portal:set_position(x, y)
    self._offset_x, self._offset_y = x, y
    for body in range(
        self._area_sensor,
        self._segment_sensor
    ) do
        body:set_position(x, y)
    end
end

--- @brief
function ow.Portal:get_position()
    return self._offset_x, self._offset_y
end

--- @brief
function ow.Portal:set_velocity(vx, vy)
    for body in range(
        self._area_sensor,
        self._segment_sensor
    ) do
        body:set_velocity(vx, vy)
    end
end

--- @brief
function ow.Portal:get_velocity()
    return self._area_sensor:get_velocity()
end 