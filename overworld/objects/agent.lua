require "common.path"

rt.settings.overworld.agent = {
    detection_radius = 1000,
    ray_density = 0.2, -- [0, 1]
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
    local origin_x, origin_y = self._body:get_position()
    origin_x, origin_y = self._scene:screen_xy_to_world_xy(love.mouse.getPosition())

    local world = self._world:get_native()
    local radius = rt.settings.overworld.agent.detection_radius
    --local shapes = self._world:get_native():getShapesInArea(x - radius, y - radius, 2 * radius, 2 * radius)

    local group = bit.bnot(ow.AgentCollisionGroup)
    local circumference = 2 * math.pi * radius
    local n_rays = circumference * rt.settings.overworld.agent.ray_density

    self._rays = {}
    local path_data = {}
    for angle = 0, 2 * math.pi, (2 * math.pi) / n_rays do
        local shape, cx, cy, nx, ny, fraction = world:rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle) * radius,
            origin_y + math.sin(angle) * radius,
            group
        )

        if shape ~= nil then
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
            self._angle_to_distance[angle] = math.huge
            table.insert(path_data, angle)
            table.insert(path_data, math.huge)

            table.insert(self._rays, {
                origin_x, origin_y,
                origin_x + math.cos(angle) * math.huge,
                origin_y + math.sin(angle) * math.huge
            })
        end
    end

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
end

--- @brief
function ow.Agent:teleport_to(x, y)
    self._body:set_position(x, y)
end