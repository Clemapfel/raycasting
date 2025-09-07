--- @class ow.OneWayPlatform
ow.OneWayPlatform = meta.class("OneWayPlatform")

--- @brief
function ow.OneWayPlatform:instantiate(object, stage, scene)
    local x1, y1 = object.x, object.y
    local w, h = object.width, object.height
    local angle = object.rotation

    local dx, dy = math.rotate(w, 0, angle)
    local x2, y2 = x1 + dx, y1 + dy

    local shape = b2.Segment(x1, y1, x2, y2)
    shape:set_is_one_sided(true)
    self._body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, 0, 0, shape)

    local down_x, down_y = math.turn_right(math.normalize(dx, dy))

    local width = 10
    down_x = down_x * width
    down_y = down_y * width

    local r, alpha = 1, 0.8
    self._mesh = rt.Mesh({
        { x1, y1, 0, 0, r, r, r, alpha },
        { x2, y2, 0, 0, r, r, r, alpha },
        { x2 + down_x, y2 + down_y, 0, 0, r, r, r, 0 },
        { x1 + down_x, y1 + down_y, 0, 0, r, r, r, 0 }
    })
    self._vertices = {x1 + down_x, y1 + down_y, x1, y1, x2, y2, x2 + down_x, y2 + down_y}
end

--- @brief
function ow.OneWayPlatform:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    love.graphics.line(self._vertices)
end