--- @class ow.Portal
ow.Portal = meta.class("Portal")

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _assert_point = function(object)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Portal: object `" .. object:get_id() .. " is not a point")
end

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

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

        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)

        self._segment_sensor = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Segment(self._ax - center_x, self._ay - center_y, self._bx - center_x, self._by - center_y)
        )

        --self._segment_sensor:set_is_sensor(true)
        self._segment_sensor:set_collides_with(rt.settings.player.player_collision_group)
        self._segment_sensor:signal_connect("collision_start", function(self_body, other_body, nx, ny, contact_x, contact_y)
            if not self._is_disabled and self._disabled_cooldown <= 0 then
                self:_teleport(nx, ny, contact_x, contact_y)
            end
        end)
        
        -- rectangle sensor
        local sensor_w = rt.settings.player.radius
        local dx, dy = self._ax - self._bx, self._ay - self._by
        local left_x, left_y = math.normalize(math.turn_left(dx, dy))
        local right_x, right_y = math.normalize(math.turn_right(dx, dy))

        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w - center_x, self._ay +  left_y * sensor_w - center_y,
            self._ax + right_x * sensor_w - center_x, self._ay + right_y * sensor_w - center_y,
            self._bx + right_x * sensor_w - center_x, self._by + right_y * sensor_w - center_y,
            self._bx +  left_x * sensor_w - center_x, self._by +  left_y * sensor_w - center_y
        )

        self._area_sensor = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, center_x, center_y, sensor_shape)
        self._area_sensor:set_is_sensor(true)
        self._area_sensor:signal_connect("collision_end", function()
            self._is_disabled = false
        end)

        for sensor in range(self._segment_sensor, self._area_sensor) do
            sensor:set_collides_with(rt.settings.player.player_collision_group)
        end

        self._sidedness = math.cross(self._ax, self._ay, self._bx, self._by) > 0
        self._is_disabled = false
        self._disabled_cooldown = 0
    end)
end

function ow.Portal:update(delta)
    if self._disabled_cooldown > 0 then
        self._disabled_cooldown = self._disabled_cooldown - 1
    end
end

function ow.Portal:_disable()
    self._is_disabled = true
    self._disable_cooldown = 2
end

local _get_ratio = function(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay

    local ab_length_squared = math.dot(abx, aby, abx, aby)
    local t = math.dot(apx, apy, abx, aby) / ab_length_squared
    return 1 - math.max(0, math.min(1, t))
end

local _get_sidedness = function(ax, ay, bx, by)
    return (ax * by - ay * bx) > 0
end

local _get_side = function(vx, vy, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local cross = abx * vy - aby * vx
    return cross > 0
end

local _get_normal = function(ax, ay, bx, by, side)
    local nx, ny = math.normalize(bx - ax, by - ay)
    if side then
        return math.turn_left(nx, ny)
    else
        return math.turn_right(nx, ny)
    end
end


local function teleport_player(
    from_ax, from_ay, from_bx, from_by,
    to_ax, to_ay, to_bx, to_by,
    vx, vy, contact_x, contact_y
)
    -- new position
    local ratio = _get_ratio(contact_x, contact_y, from_ax, from_ay, from_bx, from_by)
    local from_sidedness = _get_sidedness(from_ax, from_ay, from_bx, from_by)
    local to_sidedness = _get_sidedness(to_ax, to_ay, to_bx, to_by)
    if from_sidedness == to_sidedness then
        ratio = 1 - ratio
    end

    local new_x, new_y = math.mix2(to_ax, to_ay, to_bx, to_by, ratio)

    -- new velocity
    local from_dx = from_bx - from_ax
    local from_dy = from_by - from_ay
    local to_dx = to_bx - to_ax
    local to_dy = to_by - to_ay

    local from_angle = math.atan2(from_dy, from_dx)
    local to_angle = math.atan2(to_dy, to_dx)
    local angle_diff = to_angle - from_angle

    local speed = math.sqrt(vx*vx + vy*vy)
    local velocity_angle = math.atan2(vy, vx)
    local new_velocity_angle = velocity_angle + angle_diff

    local new_vx = speed * math.cos(new_velocity_angle)
    local new_vy = speed * math.sin(new_velocity_angle)

    local from_normal_angle = from_angle + math.pi / 2  -- perpendicular to portal
    local to_normal_angle = to_angle + math.pi / 2

    local from_normal_x, from_normal_y = math.cos(from_normal_angle), math.sin(from_normal_angle)
    local to_normal_x, to_normal_y = math.cos(to_normal_angle), math.sin(to_normal_angle)

    local from_dot = vx * from_normal_x + vy * from_normal_y
    local new_to_dot = new_vx * to_normal_x + new_vy * to_normal_y

    if not ((from_dot > 0 and new_to_dot < 0) or (from_dot < 0 and new_to_dot > 0)) then
        new_vx = -new_vx
        new_vy = -new_vy
    end

    return new_x, new_y, new_vx, new_vy
end

function ow.Portal:_teleport(normal_x, normal_y, contact_x, contact_y)
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local target = self._target

    -- disable to prevent loops
    target:_disable()
    self:_disable()

    local vx, vy = player:get_velocity()
    local new_x, new_y, new_vx, new_vy = teleport_player(
        self._ax, self._ay,  self._bx, self._by,
        target._ax, target._ay, target._bx, target._by,
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

    target._is_active = true
end


--- @brief
function ow.Portal:draw()
    love.graphics.setLineWidth(4)
    love.graphics.line(self._ax, self._ay, self._bx, self._by)

    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
    if _dbg ~= nil then
        for l in values(_dbg) do love.graphics.line(l) end
    end
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end