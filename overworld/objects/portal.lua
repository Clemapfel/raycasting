rt.settings.overworld.portal = {
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
    }
}

--- @class ow.Portal
ow.Portal = meta.class("Portal")

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _assert_point = function(object)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Portal: object `" .. object:get_id() .. " is not a point")
end

local _current_hue = 0
local _get_hue = function()
    local out = _current_hue
    _current_hue = math.fract(_current_hue + 1 / 3)
    return _current_hue
end

local _particle_texture
local _pulse_shader, _particle_shader

local _LEFT = true
local _RIGHT = not _LEFT

-- which side of a segment vector points to
local _get_side = function(vx, vy, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local cross = abx * vy - aby * vx
    return cross < 0
end

local _x = 1
local _y = 2
local _direction = 3
local _speed = 4
local _scale = 5
local _t = 6

local _FORWARD = true
local _BACKWARDS = false


local function _t_on_line_segment(x1, y1, x2, y2, px, py)
    local segment_vec_x = x2 - x1
    local segment_vec_y = y2 - y1
    local point_vec_x = px - x1
    local point_vec_y = py - y1

    local t = math.dot(point_vec_x, point_vec_y, segment_vec_x, segment_vec_y) /
        math.dot(segment_vec_x, segment_vec_y, segment_vec_x, segment_vec_y)

    return 1 - math.clamp(t, 0, 1)
end

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    if _particle_texture == nil then
        local radius = rt.settings.overworld.portal.particle.radius
        local padding = 3
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))

        local mesh = rt.MeshCircle(0, 0, radius)
        local value = 0.4 -- for additive blending
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

    if _pulse_shader == nil then
        _pulse_shader = rt.Shader("overworld/objects/portal.glsl")
    end

    if _particle_shader == nil then
        _particle_shader = rt.Shader("overworld/objects/portal_particles.glsl")
    end

    self._stage = stage
    self._scene = scene
    self._world = self._stage:get_physics_world()

    self._pulse_elapsed = math.huge
    self._pulse_value = 0

    self._hue = 0
    self._hue_set = false

    self._direction = object:get_boolean("left_or_right", true)
    self._transition_active = false
    self._transition_elapsed = math.huge
    self._transition_contact_x, self._transition_contact_y = 0, 0
    self._transition_velocity_x, self._transition_velocity_y = 0, 0
    self._transition_speed = 0

    self._entry_t = 0.5

    self._particles = {}
    self._static_canvas = nil
    self._canvas_x, self._canvas_y, self._canvas_angle = 0, 0, 0
    self._canvas_needs_update = false
    self._collapse_active = false

    self._stage:signal_connect("respawn", function()
        self._transition_active = false
        self._collapse_active = false
    end)

    stage:signal_connect("initialized", function()
        -- get portal pairs as ordered points
        self._a = object
        _assert_point(self._a)
        self._ax, self._ay = object.x, object.y

        self._b = object:get_object("other", true)
        _assert_point(self._b)
        self._bx, self._by = self._b.x, self._b.y

        self._target = stage:get_object_instance(object:get_object("target", true))
        assert(self._target ~= nil and meta.isa(self._target, ow.Portal), "In ow.Portal: `target` of object `" .. object:get_id() .. "` is not another portal")

        -- synch hue
        if self._hue_set == false and self._target._hue_set == true then
            self._hue = self._target._hue
        elseif self._hue_set == true and self._target._hue_set == false then
            self._target._hue = self._hue
        elseif self._hue_set == false and self._target._hue_set == false then
            self._hue = _get_hue()
            self._target._hue = self._hue
        end

        self._hue_set = true
        self._target._hue_set = true
        self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }
        self._target._color = self._color

        local dx, dy = math.normalize(self._ax - self._bx, self._ay - self._by)
        local left_x, left_y = math.turn_left(dx, dy)
        local right_x, right_y = math.turn_right(dx, dy)

        if self._direction == _LEFT then
            self._normal_x, self._normal_y = left_x, left_y
        else
            self._normal_x, self._normal_y = right_x, right_y
        end

        -- sensors
        self._is_disabled = false

        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        local segment_w = 5
        self._segment_sensor = b2.Body(
            self._world,
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Polygon(
                self._ax - center_x, self._ay - center_y,
                self._ax + self._normal_x * segment_w - center_x, self._ay + self._normal_y * segment_w - center_y,
                self._bx + self._normal_x * segment_w - center_x, self._by + self._normal_y * segment_w - center_y,
                self._bx - center_x, self._by - center_y
            )
        )

        self._segment_sensor:set_use_continuous_collision(true)
        self._segment_sensor:set_collides_with(rt.settings.player.player_collision_group)
        self._segment_sensor:add_tag("unjumpable", "slippery")
        self._segment_sensor:add_tag("segment_light_source")
        self._segment_sensor:set_user_data(self)

        self._segment_sensor:signal_connect("collision_start", function(self_body, other_body, nx, ny, contact_x, contact_y)
            if not self._is_disabled and contact_x ~= nil and contact_y ~= nil then
                -- check if allowed to enter from that side
                local vx, vy = self._scene:get_player():get_velocity()
                local side = _get_side(vx, vy, self._ax, self._ay, self._bx, self._by)
                if (side == self._direction) then
                    -- start transition
                    local player = self._scene:get_player()
                    self._pulse_elapsed = 0
                    self._transition_active = true

                    self._entry_t = _t_on_line_segment(self._ax, self._ay, self._bx, self._by, contact_x, contact_y)
                    self._target._entry_t = 0.5

                    self._collapse_active = true
                    self._transition_elapsed = 0
                    self._transition_speed = math.max(
                        rt.settings.overworld.portal.transition_speed_factor * math.magnitude(player:get_velocity()),
                        rt.settings.overworld.portal.transition_min_speed
                    )
                    self._transition_contact_x, self._transition_contact_y = contact_x, contact_y
                    self._transition_x, self._transition_y = contact_x, contact_y
                    self._transition_velocity_x, self._transition_velocity_y = player:get_velocity()
                    self:_set_player_disabled(true)
                end
            end
        end)

        -- rectangle sensor
        local sensor_w = rt.settings.player.radius

        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w - center_x, self._ay +  left_y * sensor_w - center_y,
            self._ax + right_x * sensor_w - center_x, self._ay + right_y * sensor_w - center_y,
            self._bx + right_x * sensor_w - center_x, self._by + right_y * sensor_w - center_y,
            self._bx +  left_x * sensor_w - center_x, self._by +  left_y * sensor_w - center_y
        )

        self._area_sensor = b2.Body(self._world, b2.BodyType.STATIC, center_x, center_y, sensor_shape)
        self._area_sensor:set_is_sensor(true)

        do -- pulse mesh
            local outer = function() return 0, 0, 0, 0 end -- rgba
            local inner = function() return 1, 1, 1, 1 end

            local w = rt.settings.overworld.portal.mesh_w
            local stencil_w = 100

            local padding = 0 --0.25 * math.distance(self._ax, self._ay, self._bx, self._by)
            local ax, ay = self._ax - dx * padding, self._ay - dy * padding
            local bx, by = self._bx + dx * padding, self._by + dy * padding

            if self._direction == _LEFT then
                local left_mesh_data = {
                    { ax + left_x * w, ay +  left_y * w, 0, 1, outer() },
                    { ax, ay, 0, 0, inner() },
                    { bx, by, 1, 0, inner() },
                    { bx +  left_x * w, by +  left_y * w, 1, 1, outer() }
                }

                self._transition_stencil = {
                    self._ax + left_x * stencil_w, self._ay + left_y * stencil_w,
                    self._ax, self._ay,
                    self._bx, self._by,
                    self._bx + left_x * stencil_w, self._by + left_y * stencil_w
                }

                self._left_mesh = rt.Mesh(left_mesh_data)
            else
                local right_mesh_data = {
                    { ax, ay, 1, 0, inner() },
                    { ax + right_x * w, ay + right_y * w, 1, 1, outer() },
                    { bx + right_x * w, by + right_y * w, 0, 1, outer() },
                    { bx, by, 0, 0, inner() }
                }

                self._transition_stencil = {
                    self._ax, self._ay,
                    self._ax + right_x * stencil_w, self._ay + right_y * stencil_w,
                    self._bx + right_x * stencil_w, self._by + right_y * stencil_w,
                    self._bx, self._by
                }

                self._right_mesh = rt.Mesh(right_mesh_data)
            end
        end

        -- particles
        local settings = rt.settings.overworld.portal.particle
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

        -- line along which particles move, move in local coordinates and get rotated during draw
        local canvas_w, canvas_h = self._static_canvas:get_size()
        self._particle_axis = {
            0.5 * canvas_w, min_radius, -- min occassionally clips, but is more consistenly the exact length of segment
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
function ow.Portal:_set_player_disabled(b)
    local player = self._scene:get_player()
    player:set_is_ghost(b)
    -- do not disable control

    if b == false then
        local delay = 4
        self._world:signal_connect("step", function()
            delay = delay - 1
            if delay <= 0 then
                player:set_is_visible(true)
                return meta.DISCONNECT_SIGNAL
            end
        end)
    else
        player:set_is_visible(false)
    end

    if b == true then -- move towards portal
        local magnitude = math.magnitude(self._transition_velocity_x, self._transition_velocity_y)
        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        local dx, dy = math.normalize(center_x - self._transition_contact_x, center_y - self._transition_contact_y)
        dx, dy = -self._normal_x, -self._normal_y
        player:set_velocity(dx * magnitude, dy * magnitude)
    end

    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
end


local _get_ratio = function(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay

    local ab_length_squared = math.dot(abx, aby, abx, aby)
    local t = math.dot(apx, apy, abx, aby) / ab_length_squared
    return math.max(0, math.min(1, t))
end

local _get_sidedness = function(ax, ay, bx, by)
    return math.cross(ax, ay, bx, by) > 0
end

--- @brief
function ow.Portal:update(delta)
    if self._transition_active then
        self._transition_elapsed = self._transition_elapsed + delta
        local traveled = self._transition_elapsed * self._transition_speed

        local target = self._target
        local from_x, from_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        local to_x, to_y = math.mix2(target._ax, target._ay, target._bx, target._by, 0.5)
        local distance = math.distance(from_x, from_y, to_x, to_y)
        local t = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(traveled / distance)

        self._transition_x, self._transition_y = math.mix2(from_x, from_y, to_x, to_y, t)
        self._scene:get_camera():move_to(self._transition_x, self._transition_y)

        if t >= 1 then
            self:_teleport()
            self._target._pulse_elapsed = 0
            self:_set_player_disabled(false)
            self._transition_active = false
            self._target._collapse_active = true
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
        end
    end

    -- test manually, more reliable at high velocities
    if self._is_disabled then
        if self._area_sensor:test_point(self._scene:get_player():get_position()) == false then
            self._is_disabled = false
        end
    end

    if self._scene:get_is_body_visible(self._area_sensor) == false then return end

    self._pulse_elapsed = self._pulse_elapsed + delta
    local pulse_duration = rt.settings.overworld.portal.pulse_duration
    self._pulse_value = rt.InterpolationFunctions.ENVELOPE(
        math.min(self._pulse_elapsed / pulse_duration),
        pulse_duration * 0.05
    )

    local ax, ay, bx, by = table.unpack(self._particle_axis)
    local length = math.distance(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay

    local speed = rt.settings.overworld.portal.particle.collapse_speed
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

    if self._collapse_active and collapse_mean_distance < 2 * rt.settings.overworld.portal.particle.radius then
        self._collapse_active = false
    end

    self._canvas_needs_update = true
end

local function teleport_player(
    from_ax, from_ay, from_bx, from_by,
    to_ax, to_ay, to_bx, to_by,
    from_normal_x, from_normal_y, to_normal_x, to_normal_y,
    vx, vy, contact_x, contact_y
)
    -- new position
    local ratio = _get_ratio(contact_x, contact_y, from_ax, from_ay, from_bx, from_by)
    local from_sidedness = _get_sidedness(from_ax, from_ay, from_bx, from_by)
    local to_sidedness = _get_sidedness(to_ax, to_ay, to_bx, to_by)
    if from_sidedness ~= to_sidedness then
        ratio = 1 - ratio
    end

    local new_x, new_y = math.mix2(to_ax, to_ay, to_bx, to_by, 0.5) --ratio)

    -- new velocity
    local magnitude = math.magnitude(vx, vy)
    local new_vx, new_vy = to_normal_x * magnitude, to_normal_y * magnitude

    return new_x, new_y, new_vx, new_vy
end

function ow.Portal:_teleport()
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local target = self._target

    -- disable to prevent loops
    target._is_disabled = true
    self._is_disabled = true

    local new_x, new_y, new_vx, new_vy = teleport_player(
        self._ax, self._ay,  self._bx, self._by,
        target._ax, target._ay, target._bx, target._by,
        self._normal_x, self._normal_y, target._normal_x, target._normal_y,
        self._transition_velocity_x, self._transition_velocity_y,
        self._transition_contact_x, self._transition_contact_y
    )

    local radius = player:get_radius()
    local nvx, nvy = math.normalize(new_vx, new_vy)
    player:teleport_to(new_x + radius * nvx, new_y + radius * nvy)
    player:set_velocity(new_vx, new_vy)
    player:set_hue(self._hue)
end

--- @brief
function ow.Portal:draw()
    if not self._scene:get_is_body_visible(self._area_sensor) then return end

    local r, g, b, a = table.unpack(self._color)

    -- particles
    if self._canvas_needs_update == true then
        love.graphics.push("all")
        love.graphics.origin()
        self._static_canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        local value = (meta.hash(self) + 123) % 254 + 1
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
        love.graphics.rectangle("fill", table.unpack(self._particle_stencil))
        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

        local w, h = _particle_texture:get_size()
        for particle in values(self._particles) do
            love.graphics.draw(
                _particle_texture:get_native(),
                particle[_x], particle[_y], 0,
                particle[_scale], particle[_scale],
                0.5 * w, 0.5 * h
            )
            love.graphics.circle("fill", particle[_x], particle[_y], 3)
        end

        rt.graphics.set_stencil_mode(nil)

        self._static_canvas:unbind()
        love.graphics.pop("all")

        self._canvas_needs_update = false
    end

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


    if self._transition_active then
        love.graphics.push("all")
        local value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.polygon("fill", self._transition_stencil)

        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

        local player = self._scene:get_player()
        local before = player:get_is_visible()
        player:set_is_visible(true)
        player:draw_body()
        player:draw_core()
        player:set_is_visible(before)

        rt.graphics.set_stencil_mode(nil)
        love.graphics.pop("all")
    end
end

--- @brief
function ow.Portal:draw_bloom()
    if not self._scene:get_is_body_visible(self._area_sensor) then return end
    local r, g, b, a = table.unpack(self._color)
    love.graphics.setColor(r, g, b, 1)
    _pulse_shader:bind()
    _pulse_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _pulse_shader:send("pulse", self._pulse_value)
    if self._direction == _LEFT then
        self._left_mesh:draw()
    else
        self._right_mesh:draw()
    end
    _pulse_shader:unbind()
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end

--- @brief
function ow.Portal:get_segment_light_sources()
    return { { self._ax, self._ay, self._bx, self._by } }, { table.deepcopy(self._color) }
end
