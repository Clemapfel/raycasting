--- @class ow.OneWayPlatform
ow.OneWayPlatform = meta.class("OneWayPlatform")

--- @brief
function ow.OneWayPlatform:instantiate(object, stage, scene)
    local x1, y1 = object.x, object.y
    local w, h = object.width, object.height
    local angle = object.rotation

    local dx, dy = math.rotate(w, 0, angle)
    local x2, y2 = x1 + dx, y1 + dy

    self._body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, 0, 0, b2.Segment(x1, y1, x2, y2))

    self.draw = function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(x1, y1, x2, y2)
    end
end
