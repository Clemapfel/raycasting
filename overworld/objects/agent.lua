rt.settings.overworld.agent = {
    max_velocity = 100
}

--- @class ow.Agent
ow.Agent = meta.class("Agent", rt.Drawable)

--- @brief
function ow.Agent:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local shape = b2.Circle(0, 0, 10)
    meta.install(self, {
        _stage = stage,
        _scene = scene,
        _world = world,
        _body = b2.Body(world, b2.BodyType.DYNAMIC, object.x, object.y, shape),

        _path = { object.x, object.y },
        _path_i = 1,
    })

    self._input = rt.InputSubscriber()
    self._input:signal_connect("mouse_pressed", function(_, _, x, y)
        x, y = self._scene:screen_xy_to_world_xy(x, y)
        self._path = { self._stage:get_pathfinding_graph():get_closest_node(x, y) }
        self._path_i = 1
    end)
end

--- @brief
function ow.Agent:_get_goal()
    return self._path[1], self._path[2]
end

--- @brief
function ow.Agent:update(delta)
    local current_x, current_y = self._body:get_position()
    local goal_x, goal_y = self:_get_goal()
    local dx, dy = math.normalize(goal_x - current_x, goal_y  - current_y)
    local magnitude = math.distance(goal_x, goal_y, current_x, current_y)^1.8
    local max_velocity = rt.settings.overworld.agent.max_velocity
    dx = dx * math.min(magnitude, max_velocity)
    dy = dy * math.min(magnitude, max_velocity)
    self._body:set_velocity(dx, dy)
end

--- @brief
function ow.Agent:draw()
    self._body:draw()

    local goal_x, goal_y = self:_get_goal()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", goal_x, goal_y, 10)
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end

