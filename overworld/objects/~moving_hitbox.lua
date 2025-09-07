
--- @class ow.MovingHitbox
ow.MovingHitbox = meta.class("MovingHitbox")

--- @class ow.MovingHitboxTarget
ow.MovingHitboxTarget = meta.class("MovingHitboxTarget")

--- @brief
function ow.MovingHitbox:instantiate(object, stage, scene)
    self._scene = scene

    self._body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.KINEMATIC)
    self._body:add_tag("stencil")
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    local target = object:get_object("target")
    assert(target:get_type() == ow.ObjectType.POINT, "In ow.MovingHitbox: for object `" .. object.id .. "`: `target` property is not a point")

    self._x, self._y = object:get_centroid()
    self._dx, self._dy = math.normalize(target.x - self._x, target.y - self._y)
    self._length = math.distance(self._x, self._y, target.x, target.y)
    self._lower = object:get_number("lower") or 0
    self._upper = object:get_number("upper") or 1

    self._elapsed = 0
    self._speed = 50
end

--- @brief
function ow.MovingHitbox:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    self._elapsed = self._elapsed + delta
    self._value = rt.InterpolationFunctions.TRIANGLE_WAVE(self._elapsed * (self._speed / self._length))

    local x1 = self._x + self._lower * self._dx * self._length
    local y1 = self._y + self._lower * self._dy * self._length
    local x2 = self._x + self._upper * self._dx * self._length
    local y2 = self._y + self._upper * self._dy * self._length

    local target_x, target_y = x1 + self._value * (x2 - x1), y1 + self._value * (y2 - y1)
    target_x = target_x - self._x
    target_y = target_y - self._y
    local current_x, current_y = self._body:get_position()
    self._body:set_linear_velocity(
        (target_x - current_x) * self._speed,
        (target_y - current_y) * self._speed
    )
    --self._body:set_position(target_x, target_y)
end

--- @brief
function ow.MovingHitbox:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()
    local x1 = self._x + self._lower * self._dx
    local y1 = self._y + self._lower * self._dy
    local x2 = self._x + self._upper * self._dx
    local y2 = self._y + self._upper * self._dy
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.circle("fill", self._x, self._y, 10)
end