rt.settings.overworld.agent = {
    max_velocity = 100
}

--- @class ow.Agent
ow.Agent = meta.class("Agent", rt.Drawable)

--- @brief
function ow.Agent:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local radius = 10
    local shape = b2.Circle(0, 0, radius)
    meta.install(self, {
        _stage = stage,
        _scene = scene,
        _world = world,
        _body = b2.Body(world, b2.BodyType.DYNAMIC, object.x, object.y, shape),
        _radius = radius,
        _path = { object.x, object.y },
        _path_i = 1,
    })

    self._input = rt.InputSubscriber()
    self._input:signal_connect("mouse_pressed", function(_, _, x, y)
        local current_x, current_y = self._body:get_position()
        local goal_x, goal_y = self._scene:screen_xy_to_world_xy(x, y)

        -- get closest nodes to start and end, move along graph path
        local graph = self._stage:get_pathfinding_graph()
        local from = graph:get_closest_reachable_node(current_x, current_y, self._world, self._radius)
        local to = graph:get_closest_reachable_node(goal_x, goal_y, self._world, self._radius)
        self._path = graph:get_path(from, to)

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

    -- check if goal is reachable already
    local final_x, final_y = self._path[#self._path - 1], self._path[#self._path]
    if math.distance(current_x, current_y, final_x, final_y) > 10 and
        not self._world:circle_cast(self._radius, current_x, current_y, final_x, final_y)
    then
        self._path_i = #self._path - 1 -- skip to end
    end
end

--- @brief
function ow.Agent:draw()
    self._body:draw()

    local goal_x, goal_y = self:_get_goal()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", goal_x, goal_y, 10)

    love.graphics.setColor(1, 0, 1, 1)
    love.graphics.setLineWidth(3)
    if #self._path >= 4 then
        love.graphics.line(self._path)
    end
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end

