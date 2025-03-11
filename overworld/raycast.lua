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

local max_n_bounces = 10

function ow.Raycast:cast(x, y, dx, dy)
    self._points = {x, y}
    local current_x, current_y = x, y
    local next_x, next_y, normal_x, normal_y = self._world:cast_ray(current_x, current_y, dx, dy)
    local n_bounces = 0
    while next_x ~= nil do
        table.insert(self._points, next_x)
        table.insert(self._points, next_y)
        --table.insert(self._points, next_x + normal_x * 30)
        --table.insert(self._points, next_y + normal_y * 30)

        local dot_product = dx * normal_x + dy * normal_y
        dx = dx + 2 * dot_product * normal_x
        dy = dy + 2 * dot_product * normal_y

        table.insert(self._points, next_x + dx * 30)
        table.insert(self._points, next_y + dy * 30)

        next_x, next_y, normal_x, normal_y = self._world:cast_ray(next_x, next_y, dx, dy)

        n_bounces = n_bounces + 1
        if n_bounces > max_n_bounces then break end
    end
end


local SceneManager = require "common.scene_manager"

--- @brief
function ow.Raycast:draw()
    if #self._points >= 4 then
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