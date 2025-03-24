rt.settings.overworld.agent = {
    detection_radius = 1000,
    ray_density = 0.9, -- [0, 1]
}

--- @class ow.Agent
ow.Agent = meta.class("Agent", rt.Drawable)

ow.AgentCollisionGroup = b2.CollisionGroup.GROUP_15

--- @brief
function ow.Agent:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    meta.install(self, {
        _world = world,
        _body = b2.Body(world, b2.BodyType.DYNAMIC, object.x, object.y),
        _angle_to_distance = {}
    })

    self._body:set_collision_group(ow.AgentCollisionGroup)
end

--- @brief
function ow.Agent:update(delta)
    local origin_x, origin_y = self._body:get_position()

    local world = self._world:get_native()
    local radius = rt.settings.overworld.agent.detection_radius
    --local shapes = self._world:get_native():getShapesInArea(x - radius, y - radius, 2 * radius, 2 * radius)

    local group = bit.bnot(ow.AgentCollisionGroup)
    local circumference = 2 * math.pi * radius
    local n_rays = circumference * rt.settings.overworld.agent.ray_density
    local angle = 0, 2 * math.pi, (2 * math.pi) / n_rays do
        local shape, cx, cy, nx, ny, fraction = world:rayCastClosest(
            origin_x,
            origin_y,
            origin_x + math.cos(angle) * radius,
            origin_y + math.sin(angle) * radius,
            group
        )

        self._angle_to_distance[angle] = fraction * radius
    end
end

--- @brief
function ow.Agent:_query_distance(angle)
    angle = (angle + math.pi) % (2 * math.pi)
end

--- @brief
function ow.Agent:draw()

end