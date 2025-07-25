require "common.path"

rt.settings.overworld.agent = {
    detection_radius = 50,
    n_rays = 8,
    sweep_range = 0.1 * (2 * math.pi)
}

--- @class ow.Agent
ow.Agent = meta.class("Agent", rt.Drawable)

ow.AgentCollisionGroup = b2.CollisionGroup.GROUP_15

ow.AgentMotionMode = meta.enum("AgentMotionMode", {
    MOVE_TO_GOAL = 1,
    FOLLOW_BOUNDARY = 2,
    STATIONARY = 3
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
        _distance_function = nil, -- rt.Path
        _data = {},

        _n_rays = 1,
        _max_velocity = 100,

        _direction_x = 0,
        _direction_y = 0,

        -- debug drawing
        _debug_drawing_enabled = true,
        _rays = {},
        _ray_colors = {},
        _graph_width = 0.5 * love.graphics.getWidth(),
        _graph_height = 0.25 * love.graphics.getHeight(),
        _distance_function_graph = {}, -- same size as _rays
        _distance_function_graph_goal_x = 0,
        _distance_function_graph_goal_y = 0,

        _ray_hit_x = 0,
        _ray_hit_y = 0,

        _current_path = {},
        _current_path_i = 1,
    })

    self._body:set_collision_group(ow.AgentCollisionGroup)
    self._body:set_restitution(0.3)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("mouse_pressed", function(_, _, x, y)
        self._current_path = { self._stage:get_pathfinding_graph():get_closest_node(x, y) }
    end)
end

local _normalize_angle = function(angle)
    return math.fmod(angle + math.pi, 2 * math.pi)
end

function ow.Agent:get_position()
    return self._body:get_position()
end

local _ray_mask = bit.bnot(ow.AgentCollisionGroup)

--- @brief
--- @param direction_angle Number radians
--- @param sweep_range Number radians, final arc will be direction_angle - sweep_range, direction_angle + sweep_range
function ow.Agent:_sample_distance_function(direction_angle)
    local sweep_range = rt.settings.overworld.agent.sweep_range
    local radius = rt.settings.overworld.agent.detection_radius
    local n_rays = rt.settings.overworld.agent.n_rays

    local world = self._world:get_native()
    local origin_x, origin_y = self._scene:screen_xy_to_world_xy(love.mouse.getPosition())--self:get_position() --self._scene:screen_xy_to_world_xy(love.mouse.getPosition())
    local origin_x, origin_y = self:get_position()

    self._rays = {}
    self._ray_colors = {}
    local ray_i = 0

    local path_data = {}
    self._data = {}
    for angle = direction_angle - sweep_range, direction_angle + sweep_range, (2 * sweep_range) / n_rays do
        local hit, cx, cy, normal_x, normal_y, fraction = world:rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle) * radius,
            origin_y + math.sin(angle) * radius,
            _ray_mask
        )

        local distance
        if hit ~= nil then
            distance = fraction * radius
        else
            distance = radius
            cx = origin_x + math.cos(angle) * radius
            cy = origin_y + math.sin(angle) * radius
        end

        local normalized = _normalize_angle(angle)
        table.insert(path_data, normalized)
        table.insert(path_data, distance)

        table.insert(self._data, {
            x = cx,
            y = cy,
            normal_x = normal_x,
            normal_y = normal_y,
            angle = angle,
            distance = distance,
            is_valid = hit ~= nil
        })

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

    self._n_rays = ray_i
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

local _stalling_counter = 0

function ow.Agent:_update_mode()
    local radius = rt.settings.overworld.agent.detection_radius
    self._rays = {}

    -- test directly towards goal
    local origin_x, origin_y = self:get_position()
    local goal_x, goal_y = self._goal_x, self._goal_y

    local dx, dy = math.normalize(goal_x - origin_x, goal_y - origin_y)

    local hit, center_x, center_y, normal_x, normal_y, fraction = self._world:get_native():rayCastClosest(
        origin_x,
        origin_y,
        origin_x + dx * radius,
        origin_y + dy * radius,
        _ray_mask
    )

    local distance
    if hit ~= nil then
        distance = math.distance(origin_x, origin_y, goal_x, goal_y) * fraction
    else
        distance = math.huge
    end

    self:_sample_distance_function(math.angle(dx, dy))

    self._ray_hit_x, self._ray_hit_y = center_x, center_y

    -- if ray in direction of goal does not hit anything, move straight to goal
    if hit == nil then
        self._direction_x, self._direction_y = math.normalize(dx, dy)
        return
    else
        local angle = math.angle(dx, dy)
        local step = (2 * math.pi) / 8
        local hit_left, left_x, left_y, left_nx, left_ny, left_fraction = self._world:get_native():rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle - step) * radius,
            origin_y + math.sin(angle - step) * radius,
            _ray_mask
        )

        local hit_right, right_x, right_y, right_nx, right_ny, right_fraction = self._world:get_native():rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle + step) * radius,
            origin_y + math.sin(angle + step) * radius,
            _ray_mask
        )

        local left, right = true, false
        local left_or_right = nil

        local right_distance, left_distance
        if hit_right and not hit_left then
            left_distance = math.magnitude(center_x, center_y, self._goal_x, self._goal_y)
            right_distance = math.magnitude(right_x, right_y, self._goal_x, self._goal_y)
        elseif hit_left and not hit_right then
            right_distance = math.magnitude(center_x, center_y, self._goal_x, self._goal_y)
            left_distance = math.magnitude(left_x, left_y, self._goal_x, self._goal_y)
        elseif hit_left and hit_right then
            left_distance = math.magnitude(left_x, left_y, self._goal_x, self._goal_y)
            right_distance = math.magnitude(right_x, right_y, self._goal_x, self._goal_y)
        else
            return
        end

        if left_distance < right_distance then
            left_or_right = left
        elseif left_distance > right_distance then
            left_or_right = right
        end

        if left_or_right == left then
            self._direction_x, self._direction_y = math.turn_right(normal_x, normal_y)
        else
            self._direction_x, self._direction_y = math.turn_left(normal_x, normal_y)
        end

        return
    end
end

--- @brief
function ow.Agent:update(delta)
    --self:_update_mode()

    -- update velocity
    local current_x, current_y = self._body:get_position()
    local dx, dy = self._goal_x - current_x, self._goal_y  - current_y
    local magnitude = math.distance(self._goal_x, self._goal_y, current_x, current_y)
    dx = dx * math.min(magnitude, self._max_velocity)
    dy = dy * math.min(magnitude, self._max_velocity)
    self._body:set_velocity(dx, dy)
    --self._body:apply_linear_impulse(math.normalize(dx, dy))
    --self._body._native:setLinearDamping(1 - math.min(magnitude / rt.settings.overworld.agent.detection_radius, 1))
end

--- @brief
function ow.Agent:draw()
    if self._debug_drawing_enabled then
        love.graphics.setLineWidth(2)
        for i, ray in ipairs(self._rays) do
            love.graphics.setColor(self._ray_colors[i])
            love.graphics.line(ray)
        end

        love.graphics.setColor(1, 1, 1, 1)
        local current_x, current_y = self:get_position()
        --love.graphics.line(current_x, current_y, self._goal_x, self._goal_y)
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

        local x, y = self._ray_hit_x, self._ray_hit_y
        if x ~= nil then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(2)
            love.graphics.line(x, y, x + self._direction_x * 20, y + self._direction_y * 20)
        end
    end

    self._body:draw()
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end