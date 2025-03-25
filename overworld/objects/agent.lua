require "common.path"

rt.settings.overworld.agent = {
    detection_radius = 1000,
    ray_density = 0.02, -- [0, 1]
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
        _distance_function = nil, --rt.Path
    })

    self._body:set_collision_group(ow.AgentCollisionGroup)
end

--- @brief
function ow.Agent:update(delta)
    local world = self._world:get_native()
    local radius = rt.settings.overworld.agent.detection_radius

    local origin_x, origin_y = self._body:get_position()

    local group = bit.bnot(ow.AgentCollisionGroup)
    local path_data = {}
    self._rays = {}

    local circumference = 2 * math.pi * radius
    local n_rays = circumference * rt.settings.overworld.agent.ray_density

    local step = (2 * math.pi) / n_rays
    for angle = 0, 2 * math.pi - step, step do
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
            table.insert(path_data, angle)
            table.insert(path_data, distance)

            table.insert(self._rays, {
                origin_x, origin_y,
                origin_x + math.cos(angle) * (fraction * radius),
                origin_y + math.sin(angle) * (fraction * radius)
            })
        else
            local _inf = 10e9
            self._angle_to_distance[angle] = math.huge
            table.insert(path_data, angle)
            table.insert(path_data, math.huge)

            table.insert(self._rays, {
                origin_x, origin_y,
                origin_x + math.cos(angle) * 10e9,
                origin_y + math.sin(angle) * 10e9
            })
        end
    end

    --[[
    -- TODO: this also casts to all nearby shapes, but it doesn't seem to be worth the performance cost
    for shape in values(world:getShapesInArea(
        origin_x - radius, origin_y - radius,
        2 * radius, 2 * radius)
    ) do
        local body = shape:getBody()
        local body_x, body_y = body:getPosition()
        local shape_x, shape_y = shape:getMassData()
        local target_x, target_y = body_x + shape_x, body_y + shape_y

        local hit, cx, cy, nx, ny, fraction = world:rayCastClosest(
            origin_x,
            origin_y,
            target_x,
            target_y,
            group
        )

        local angle = math.angle(target_x - origin_x, target_y - origin_y)
        local dx, dy = target_x - origin_x, target_y - origin_y

        if hit ~= nil then
            local distance = fraction * radius
            self._angle_to_distance[angle] = distance
            table.insert(path_data, angle)
            table.insert(path_data, distance)

            table.insert(self._rays, {
                origin_x,
                origin_y,
                origin_x + dx * fraction,
                origin_y + dy * fraction
            })
        else
            local _inf = 10e9
            self._angle_to_distance[angle] = math.huge
            table.insert(path_data, angle)
            table.insert(path_data, math.huge)

            table.insert(self._rays, {
                origin_x,
                origin_y,
                origin_x + dx * 10e9,
                origin_y + dy * 10e9
            })
        end
    end
    ]]--

    -- path used to linearly interpolate between ray results
    self._distance_function = rt.Path(path_data)
end

--- @brief
function ow.Agent:_query_distance(angle)
    local t = ((angle + math.pi) % (2 * math.pi)) / (2 * math.pi)
    return self._path:at(t)
end

--- @brief
function ow.Agent:draw()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1)
    for ray in values(self._rays) do
        love.graphics.line(ray)
    end

    self._body:draw()
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end