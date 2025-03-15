--- @class ow.Teleporter
ow.Teleporter = meta.class("Teleporter", rt.Drawable)

--- @brief
function ow.Teleporter:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")
    assert(object.type == ow.ObjectType.ELLIPSE)
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        0, 0,
        object:get_physics_shapes()
    )

    local target = object.properties.target
    assert(target ~= nil, "In ow.Teleporter.instantiate: `target` property of Teleporter class is nil")
    self._target_x, self._target_y = target:get_centroid()
    self._blocking_body = nil

    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function(self_body, other_body, x, y, normal_x, normal_y)
        if self._blocking_body ~= nil then return end

        if other_body:has_tag("player") then
            -- block other teleporters to prevent loop
            for other_teleporter in values(target.instances) do
                other_teleporter._blocking_body = other_body
            end

            -- teleport player
            other_body:set_position(self._target_x, self._target_y)
            other_body:set_linear_velocity(0, 0)
            other_body:get_user_data():set_timeout(0.2)
        end
    end)

    self._body:signal_connect("collision_end", function(self_body, other_body, ...)
        if other_body == self._blocking_body then
            -- unblock when player leaves teleporter
            self._blocking_body = nil
        end
    end)

    self._body:set_collision_group(ow.RayMaterial.TRANSMISSIVE)
end

--- @brief
function ow.Teleporter:draw()
    self._body:draw()
end
