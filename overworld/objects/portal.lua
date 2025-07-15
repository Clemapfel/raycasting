rt.settings.overworld.portal = {
    mesh_w = 30, -- px
    pulse_duration = 1, -- s
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
    _current_hue = math.fract(_current_hue + 1 / 8)
    return _current_hue
end

local _particle_texture

local _LEFT = true
local _RIGHT = not _LEFT

-- which side of a segment vector points to
local _get_side = function(vx, vy, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local cross = abx * vy - aby * vx
    return cross < 0
end

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    if _particle_texture == nil then
        local radius = 30
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

    self._stage = stage
    self._scene = scene
    self._world = self._stage:get_physics_world()

    self._pulse_elapsed = math.huge
    self._pulse_value = 0

    self._hue = 0

    self._direction = object:get_boolean("left_or_right", true)

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
        local segment_w = 10
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

        self._segment_sensor:signal_connect("collision_start", function(self_body, other_body, nx, ny, contact_x, contact_y)
            if not self._is_disabled and contact_x ~= nil and contact_y ~= nil then
                -- check if allowed to enter from that side
                local vx, vy = self._scene:get_player():get_velocity()
                local side = _get_side(vx, vy, self._ax, self._ay, self._bx, self._by)
                if (side == self._direction) then
                    self:_teleport(nx, ny, contact_x, contact_y)
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
        self._area_sensor:signal_connect("collision_end", function()
            -- enable portal once exited to prevent loops
            self._is_disabled = false
        end)
        self._area_sensor:set_collides_with(rt.settings.player.player_collision_group)

        -- graphics
        do
            local outer = function() return 0, 0, 0, 0 end -- rgba
            local inner = function() return 1, 1, 1, 1 end

            local w = rt.settings.overworld.portal.mesh_w

            local padding = 0 --0.25 * math.distance(self._ax, self._ay, self._bx, self._by)
            local ax, ay = self._ax - dx * padding, self._ay - dy * padding
            local bx, by = self._bx + dx * padding, self._by + dy * padding

            if self._direction == _LEFT then
                local left_mesh_data = {
                    { ax +  left_x * w, ay +  left_y * w, 0, 1, outer() },
                    { ax, ay, 0, 0, inner() },
                    { bx, by, 1, 0, inner() },
                    { bx +  left_x * w, by +  left_y * w, 1, 1, outer() }
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
    end)
end

--- @brief
function ow.Portal:update(delta)
    if self._scene:get_is_body_visible(self._area_sensor) == false then return end

    self._pulse_elapsed = self._pulse_elapsed + delta
    local pulse_duration = rt.settings.overworld.portal.pulse_duration
    self._pulse_value = rt.InterpolationFunctions.ENVELOPE(
        math.min(self._pulse_elapsed / pulse_duration),
        pulse_duration * 0.05
    )
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

    local new_x, new_y = math.mix2(to_ax, to_ay, to_bx, to_by, ratio)

    -- new velocity
    local magnitude = math.magnitude(vx, vy)
    local new_vx, new_vy = to_normal_x * magnitude, to_normal_y * magnitude

    return new_x, new_y, new_vx, new_vy
end

function ow.Portal:_teleport(normal_x, normal_y, contact_x, contact_y)
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local target = self._target

    -- disable to prevent loops
    target._is_disabled = true
    self._is_disabled = true

    self._pulse_elapsed = 0
    target._pulse_elapsed = 0

    local vx, vy = player:get_velocity()
    local new_x, new_y, new_vx, new_vy = teleport_player(
        self._ax, self._ay,  self._bx, self._by,
        target._ax, target._ay, target._bx, target._by,
        self._normal_x, self._normal_y, target._normal_x, target._normal_y,
        vx, vy,
        contact_x, contact_y
    )

    local radius = player:get_radius()
    local nvx, nvy = math.normalize(new_vx, new_vy)
    player:teleport_to(new_x + radius * nvx, new_y + radius * nvy)
    player:set_velocity(new_vx, new_vy)

    new_vx, new_vy = math.normalize(new_vx, new_vy)
    vx, vy = math.normalize(vx, vy)

    _dbg = {
        {
            new_x, new_y,
            new_x + new_vx * 10,
            new_y + new_vy * 10
        }, {
            contact_x, contact_y,
            contact_x + new_vx * 10,
            contact_y + new_vy * 10
        }
    }
end

--- @brief
function ow.Portal:draw()
    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, self._hue, 1)

    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(4)
    love.graphics.line(self._ax, self._ay, self._bx, self._by)

    if self._direction == _LEFT then
        self._left_mesh:draw()
    else
        self._right_mesh:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    self._segment_sensor:draw()
    if _dbg ~= nil then
        for l in values(_dbg) do love.graphics.line(l) end
    end
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end