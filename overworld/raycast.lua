--- @class ow.Raycast
ow.Raycast = meta.class("OverworldRaycast", rt.Drawable)

--- @brief
function ow.Raycast:instantiate(world)
    meta.assert(world, "PhysicsWorld")
    meta.install(self, {
        _points = {},
        _world = world,
    })
end

--- @brief
function ow.Raycast:cast(x, y, dx, dy)
    self._points = self._world:cast_ray(x, y, dx, dy)
    table.insert(self._points, 1, y)
    table.insert(self._points, 1, x)
end

local SceneManager = require "common.scene_manager"

--- @brief
function ow.Raycast:draw()
    if #self._points > 4 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(self._points)
        love.graphics.setPointSize(5)
        love.graphics.points(self._points)

        love.graphics.setColor(1, 0, 1, 1)
        love.graphics.circle("fill", self._points[1], self._points[2], 5)
        local x, y = love.mouse.getPosition()
        x, y = SceneManager._current_scene._camera:screen_xy_to_world_xy(x, y)
        love.graphics.circle("fill", x, y, 5)
    end
end