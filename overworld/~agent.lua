require "common.path"

rt.settings.overworld.agent = {
    detection_radius = 1000,
    ray_density = 0.01, -- [0, 1]
}

--- @class ow.Agent
ow.Agent = meta.class("Agent", rt.Drawable)

ow.AgentCollisionGroup = b2.CollisionGroup.GROUP_15

--- @brief
function ow.Agent:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    meta.install(self, {
        _stage = stage,
        _scene = scene,
        _world = world,
        _body = b2.Body(world, b2.BodyType.DYNAMIC, object.x, object.y),
        _angle_to_distance = {},
        _rays = {},
        _distance_function_draw = nil, -- rt.Path
        _distance_function = nil, --rt.Path

        _goal_x = 0,
        _goal_y = 0,

        _secondary_goal_x = 0,
        _secondary_goal_y = 0,

        _current_x = 0,
        _current_y = 0,

    })

    self._body:set_collision_group(ow.AgentCollisionGroup)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("mouse_pressed", function(_, _, x, y)
        self._goal_x, self._goal_y = self._scene:screen_xy_to_world_xy(x, y)
    end)
end


local _draw_max = 300
local _draw_x_scale = 100
local _draw_y_scale = 1 / 2

--- @brief
--- @param direction_angle Number radians
--- @param sweep_range Number radians, final arc will be direction_angle - sweep_range, direction_angle + sweep_range
function ow.Agent:_sample_distance_function(direction_angle, sweep_range)
    local radius = rt.settings.overworld.agent.detection_radius
    local length = 2 * sweep_range * radius
    local world = self._world:get_native()
    local origin_x, origin_y = self._body:get_position()
    local mask = bit.bnot(ow.AgentCollisionGroup)

    local path_data = {}
    for angle = direction_angle - sweep_range, direction_angle + sweep_range do
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

        self._angle_to_distance[angle] = distance

        table.insert(path_data, angle)
        table.insert(path_data, distance)
        table.insert(self._rays, {
            origin_x, origin_y,
            origin_x + math.cos(angle) * (fraction * radius),
            origin_y + math.sin(angle) * (fraction * radius)
        })
    end

    self._distance_function = rt.Path(path_data)
end

--- @brief
function ow.Agent:update(delta)
    local world = self._world:get_native()
    local radius = rt.settings.overworld.agent.detection_radius

    local origin_x, origin_y = self._body:get_position()
    origin_x, origin_y = self._scene:get_player():get_position()

    self._current_x, self._current_y = origin_x, origin_y

    local group = bit.bnot(ow.AgentCollisionGroup)
    local path_data = {}
    local draw_data = {}
    local function push_path_data(x, y)
        table.insert(path_data, x)
        table.insert(path_data, y)

        table.insert(draw_data, math.fmod(x + 2 * math.pi, 2 * math.pi) / (2 * math.pi) * love.graphics.getWidth())
        table.insert(draw_data, math.min(y, rt.settings.overworld.agent.detection_radius) * _draw_y_scale )
    end
    self._rays = {}

    -- sample distance function
    local circumference = 2 * math.pi * radius
    local n_rays = math.ceil(circumference * rt.settings.overworld.agent.ray_density)

    local step = (2 * math.pi) / n_rays
    for angle = 0, 2 * math.pi, step do
        local hit, cx, cy, nx, ny, fraction = world:rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle) * radius,
            origin_y + math.sin(angle) * radius,
            group
        )

        if hit ~= nil then
            local distance = fraction * radius
            self._angle_to_distance[angle] = distance
            push_path_data(angle, distance)

            table.insert(self._rays, {
                origin_x, origin_y,
                origin_x + math.cos(angle) * (fraction * radius),
                origin_y + math.sin(angle) * (fraction * radius)
            })
        else
            local _inf = 10e9
            self._angle_to_distance[angle] = math.huge
            push_path_data(angle, math.huge)

            table.insert(self._rays, {
                origin_x, origin_y,
                origin_x + math.cos(angle) * 10e9,
                origin_y + math.sin(angle) * 10e9
            })
        end
    end

    -- path used to linearly interpolate between ray results
    self._distance_function = rt.Path(path_data)
    self._distance_function_draw = rt.Path(draw_data)

    -- test directly towards goal
    local shape, cx, cy, normal_x, normal_y, fraction = world:rayCastClosest(
        origin_x, origin_y,
        self._goal_x, self._goal_y,
        group
    )

    if shape ~= nil then
        self._secondary_goal_x, self._secondary_goal_y = cx, cy
    else
        self._secondary_goal_x, self._secondary_goal_y = self._goal_x, self._goal_y
    end
end

--- @brief
function ow.Agent:_query_distance(angle)
    local t = math.fmod(angle + 2 * math.pi, 2 * math.pi) / (2 * math.pi)
    return self._path:at(t)
end

--- @brief
function ow.Agent:draw()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1)

    local n = table.sizeof(self._rays)
    for i, ray in ipairs(self._rays) do
        rt.LCHA(0.8, 1, (i - 1) / n, 1):bind()
        love.graphics.line(ray)
    end

    self._body:draw()

    love.graphics.push()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(self._current_x, self._current_y, self._goal_x, self._goal_y)

    local angle = math.angle(self._goal_x - self._current_x, self._goal_y - self._current_y)
    angle = math.fmod(angle + 2 * math.pi, 2 * math.pi) / (2 * math.pi) * love.graphics.getWidth()

    local dist = math.distance(self._goal_x, self._goal_y, self._current_x, self._current_y)
    local dist2 = math.distance(self._secondary_goal_x, self._secondary_goal_y, self._current_x, self._current_y)

    dist = dist * _draw_y_scale--math.min(dist, 10e9) / rt.settings.overworld.agent.detection_radius * _draw_max

    love.graphics.origin()
    love.graphics.translate(0, love.graphics.getHeight())
    love.graphics.scale(1, -1)

    local draw_path = function()
        local points = self._distance_function_draw._points
        local n_points = #points
        local hue_i = 0
        for i = 1, n_points - 2, 2 do
            local a_x, a_y = points[i+0], points[i+1]
            local b_x, b_y = points[i+2], points[i+3]
            rt.LCHA(0.8, 1, (hue_i - 1) / (n_points / 2)):bind()
            love.graphics.line(a_x, a_y, b_x, b_y)
            hue_i = hue_i + 1
        end

        --love.graphics.line(points[1], points[2], points[#points-1], points[#points])
    end

    love.graphics.setLineWidth(5)
    love.graphics.setColor(0, 0, 0, 1)
    self._distance_function_draw:draw()

    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 1, 1)
    draw_path()

    love.graphics.setLineWidth(4)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.line(angle, 0, angle, dist)

    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(angle, 0, angle, dist)

    love.graphics.pop()

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", self._goal_x, self._goal_y, 4)
    love.graphics.circle("fill", self._secondary_goal_x, self._secondary_goal_y, 6)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._goal_x, self._goal_y, 3)
    love.graphics.circle("fill", self._secondary_goal_x, self._secondary_goal_y, 5)
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end