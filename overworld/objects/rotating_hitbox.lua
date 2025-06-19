
--- @class ow.RotatingHitbox
ow.RotatingHitbox = meta.class("RotatingHitbox")

--- @class ow.RotatingHitboxTarget
ow.RotatingHitboxTarget = meta.class("RotatingHitboxTarget")

--- @brief
function ow.RotatingHitbox:instantiate(object, stage, scene)
    local cx, cy = object:get_centroid()
    local shapes = object:get_physics_shapes()
    for shape in values(shapes) do
        if meta.isa(shape, b2.Polygon) or meta.isa(shape, b2.Segment) then
            for i = 1, #shape._vertices, 2 do
                shape._vertices[i+0] = shape._vertices[i+0] - cx
                shape._vertices[i+1] = shape._vertices[i+1] - cy
            end
        elseif meta.isa(shape, b2.Circle) or meta.isa(shape, b2.Rectangle) then
            shape._x = shape._x - cx
            shape._y = shape._y - cy
        end
    end

    self._body = b2.Body(stage:get_physics_world(), b2.BodyType.KINEMATIC, cx, cy, table.unpack(shapes))
    self._body:add_tag("stencil")

    self._x, self._y = object:get_centroid()
    self._elapsed = 0
    self._speed = 0.1 -- radians per second
end

function ow.RotatingHitbox:update(delta)
    self._elapsed = self._elapsed + delta
    self._value = math.fract(self._elapsed * self._speed)

    local target = self._value * 2 * math.pi  -- Target angle in [0, 2π]
    local current = self._body:get_rotation()  -- Current angle

    -- Calculate shortest angular difference in [-π, π]
    local angle_diff = (target - current + math.pi) % (2 * math.pi) - math.pi

    -- Scale angular velocity by speed and clamp to avoid overshooting
    local angular_velocity = angle_diff
    self._body:set_angular_velocity(angular_velocity)
end

--- @brief
function ow.RotatingHitbox:draw(x, y)
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()
    love.graphics.circle("fill", self._x, self._y, 5 * rt.get_pixel_scale())
end