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
        local goal_x, goal_y = self._scene:screen_xy_to_world_xy(x, y)

        -- get closest nodes to start and end, move along graph path
        local graph = self._stage:get_pathfinding_graph()
        local start = graph:get_closest_node(self._body:get_position())
        local finish = graph:get_closest_node(goal_x, goal_y)

        dbg(start, finish)

        self._path = graph:get_path(start, finish)

        -- at the end, leave path and go to goal
        table.insert(self._path, goal_x)
        table.insert(self._path, goal_y)

        self._path_i = 1
    end)
end

--- @brief
function ow.Agent:_get_goal()
    return self._path[self._path_i], self._path[self._path_i + 1]
end

--- @brief
function ow.Agent:update(delta)
    local current_x, current_y = self._body:get_position()
    local goal_x, goal_y = self:_get_goal()
    local dx, dy = math.normalize(goal_x - current_x, goal_y  - current_y)
    local distance = math.distance(goal_x, goal_y, current_x, current_y)
    local magnitude = distance^1.8
    local max_velocity = rt.settings.overworld.agent.max_velocity
    dx = dx * math.min(magnitude, max_velocity)
    dy = dy * math.min(magnitude, max_velocity)
    self._body:set_velocity(dx, dy)

    if distance < 10 and self._path_i < #self._path - 2 then
        self._path_i = self._path_i + 2
    end
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

