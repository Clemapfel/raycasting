require "common.path"

rt.settings.overworld.agent = {
    detection_radius = 200,
    ray_density = 0.05, -- [0, 1]
    sweep_range = 0.25 * (2 * math.pi)
}

--- @class ow.Agent
ow.Agent = meta.class("Agent", rt.Drawable)

ow.AgentCollisionGroup = b2.CollisionGroup.GROUP_15

ow.AgentMotionMode = meta.enum("AgentMotionMode", {
    MOVE_TO_GOAL = 1,
    FOLLOW_BOUNDARY = 2
})

--- @brief
function ow.Agent:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local shape = b2.Circle(0, 0, 10)

    meta.install(self, {
        _stage = stage,
        _scene = scene,
        _world = world,
        _body = b2.Body(world, b2.BodyType.DYNAMIC, object.x, object.y, shape),
        _distance_function = nil, --rt.Path

        _goal_x = 0,
        _goal_y = 0,
        _mode = ow.AgentMotionMode.MOVE_TO_GOAL,
        _max_velocity = 100,

        -- debug drawing
        _debug_drawing_enabled = true,
        _rays = {},
        _ray_colors = {},
        _graph_width = 0.5 * love.graphics.getWidth(),
        _graph_height = 0.25 * love.graphics.getHeight(),
        _distance_function_graph = {}, -- same size as _rays
        _distance_function_graph_goal_x = 0,
        _distance_function_graph_goal_y = 0,
    })

    self._body:set_collision_group(ow.AgentCollisionGroup)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("mouse_pressed", function(_, _, x, y)
        self._goal_x, self._goal_y = self._scene:screen_xy_to_world_xy(x, y)
    end)
end

local _normalize_angle = function(angle)
    return math.fmod(angle + math.pi, 2 * math.pi)
end

function ow.Agent:get_position()
    return self._body:get_position()
end

--- @brief
--- @param direction_angle Number radians
--- @param sweep_range Number radians, final arc will be direction_angle - sweep_range, direction_angle + sweep_range
function ow.Agent:_sample_distance_function(direction_angle)
    local sweep_range = rt.settings.overworld.agent.sweep_range
    local radius = rt.settings.overworld.agent.detection_radius
    local ray_density = rt.settings.overworld.agent.ray_density

    local length = 2 * sweep_range * radius
    local n_rays = math.ceil(ray_density * length)

    local world = self._world:get_native()
    local origin_x, origin_y = self:get_position()
    local mask = bit.bnot(ow.AgentCollisionGroup)

    self._rays = {}
    self._ray_colors = {}
    local ray_i = 0

    local path_data = {}
    for angle = direction_angle - sweep_range, direction_angle + sweep_range, (2 * sweep_range) / n_rays do
        local hit, cx, cy, nx, ny, fraction = world:rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle) * radius,
            origin_y + math.sin(angle) * radius,
            mask
        )

        local distance
        if hit ~= nil then
            distance = fraction * radius
        else
            distance = math.huge
        end

        local normalized = _normalize_angle(angle)
        table.insert(path_data, normalized)
        table.insert(path_data, distance)

        if self._debug_drawing_enabled then
            table.insert(self._rays, {
                origin_x, origin_y,
                origin_x + math.cos(angle) * math.min(distance, radius),
                origin_y + math.sin(angle) * math.min(distance, radius)
            })

            table.insert(self._ray_colors, {
                rt.lcha_to_rgba(0.8, 1, ray_i / n_rays, 1)
            })

            ray_i = ray_i + 1
        end
    end

    self._distance_function = rt.Path(path_data)

    if self._debug_drawing_enabled then
        self._distance_function_graph = {}
        for i = 1, #path_data, 2 do
            local x = path_data[i+0]
            local y = path_data[i+1]

            x = _normalize_angle(x + sweep_range - direction_angle) / (2 * sweep_range) * self._graph_width
            y = self._graph_height - (y / radius) * self._graph_height
            table.insert(self._distance_function_graph, x)
            table.insert(self._distance_function_graph, y)
        end

        self._distance_function_graph_goal_x = (direction_angle + sweep_range - direction_angle) / (2 * sweep_range) * self._graph_width
        self._distance_function_graph_goal_y = self._graph_height - (math.distance(self._goal_x, self._goal_y, origin_x, origin_y) / radius) * self._graph_height
    end

end

--- @brief
function ow.Agent:update(delta)
    local current_x, current_y = self:get_position()
    local direction_x, direction_y = self._goal_x - current_x, self._goal_y - current_y
    self:_sample_distance_function(math.angle(direction_x, direction_y))

    if self._mode == ow.AgentMotionMode.MOVE_TO_GOAL then
        local magnitude = math.magnitude(direction_x, direction_y)
        local dx, dy = math.normalize(direction_x, direction_y)
        dx = dx * math.min(magnitude, self._max_velocity)
        dy = dy * math.min(magnitude, self._max_velocity)
        self._body:set_velocity(dx, dy)
    end
end

--- @brief
function ow.Agent:draw()
    self._body:draw()

    if self._debug_drawing_enabled then
        love.graphics.setLineWidth(2)
        for i, ray in ipairs(self._rays) do
            love.graphics.setColor(table.unpack(self._ray_colors[i]))
            love.graphics.line(ray)
        end

        love.graphics.setColor(1, 1, 1, 1)
        local current_x, current_y = self:get_position()
        love.graphics.line(current_x, current_y, self._goal_x, self._goal_y)
        love.graphics.circle("fill", self._goal_x, self._goal_y, 4)

        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("line", 0, 0, self._graph_width, self._graph_height)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, self._graph_width, self._graph_height)

        local ray_i = 1
        for i = 1, #self._distance_function_graph - 2, 2 do
            love.graphics.setColor(table.unpack(self._ray_colors[ray_i]))
            love.graphics.line(
                self._distance_function_graph[i+0], self._distance_function_graph[i+1],
                self._distance_function_graph[i+2], self._distance_function_graph[i+3]
            )
            ray_i = ray_i + 1
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(
            self._distance_function_graph_goal_x, self._graph_height,
            self._distance_function_graph_goal_x, self._distance_function_graph_goal_y
        )

        love.graphics.pop()
    end
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end