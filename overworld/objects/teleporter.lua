--- @class ow.Teleporter
ow.Teleporter = meta.class("Teleporter", rt.Drawable)

--- @brief
function ow.Teleporter:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)

    local target = object:get_object("target", true)
    stage:signal_connect("initialized", function(stage)
        self._other = stage:object_wrapper_to_instance(target):get_physics_body()
        self._target_x, self._target_y = self._other:get_center_of_mass()

        -- if colliding with player, mark player as blocking body to prevent infinte loop
        self._body:signal_connect("collision_start", function(self_body, other_body, x, y, normal_x, normal_y)
            if self_body.teleporter_blocking_body ~= nil then return end

            if other_body:has_tag("player") or other_body:has_tag("agent") then
                self._other.teleporter_blocking_body = other_body

                other_body:set_position(self._target_x, self._target_y)
                other_body:set_linear_velocity(0, 0)
                other_body:get_user_data():set_timeout(0.2)
            end
        end)

        -- if player leaves self, unblock for later reuse
        self._body:signal_connect("collision_end", function(self_body, other_body)
            if other_body == self_body.teleporter_blocking_body then
                self_body.teleporter_blocking_body = nil
            end
        end)
    end)
end

--- @brief
function ow.Teleporter:draw()
    self._body:draw()
end

--- @brief
function ow.Teleporter:get_physics_body()
    return self._body
end
