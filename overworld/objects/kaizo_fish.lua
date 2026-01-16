rt.settings.overworld.kaizo_fish = {
    default_velocity = 100
}

--- @class ow.KaizoFish
ow.KaizoFish = meta.class("KaizoFish")

--- @class ow.KaizoFishSensor
ow.KaizoFishSensor = meta.class("KaizoFishSensor")

--- @brief
function ow.KaizoFish:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = self._stage:get_physics_world()

    self._body = object:create_physics_body(
        self._world,
        b2.BodyType.KINEMATIC
    )
    self._body:set_mass(1)

    self._start_velocity_x = object:get_number("velocity_x") or 0
    self._start_velocity_y = object:get_number("velocity_y") or 0
    self._start_x, self._start_y = self._body:get_position()

    self._sensor = object:get_object("sensor", true):create_physics_body(
        self._world,
        b2.BodyType.STATIC
    )
    self._sensor:set_is_sensor(true)

    for body in range(self._body, self._sensor) do
        body:set_collision_group(rt.settings.player.bounce_collision_group)
        body:set_collides_with(rt.settings.player.bounce_collision_group)
    end

    local reset = function()
        self._body:set_position(self._start_x, self._start_y)
        self._body:set_velocity(0, 0)
    end

    reset()

    self._stage:signal_connect("respawn", function(_)
        reset()
    end)

    self._stage:signal_connect("initialized", function()
        reset()
        return meta.DISCONNECT_SIGNAL
    end)

    self._sensor:signal_connect("collision_start", function(self_body, other_body)
        self._is_active = true
        self._body:set_position(self._start_x, self._start_y)

        if self._start_velocity_x == 0 and self._start_velocity_y == 0 then
            local px, py = self._scene:get_player():get_position()
            local self_x, self_y = self_body:get_position()
            local dx, dy = math.normalize(px - self._x, py - self_y)
            local magnitude = rt.settings.overworld.kaizo_fish.default_velocity
            self._body:set_velocity(dx * magnitude, dy * magnitude)
        else
            self._body:set_velocity(self._start_velocity_x, self._start_velocity_y)
        end
    end)

    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            --self._scene:get_player():kill()
        end
    end)
end


--- @brief
function ow.KaizoFish:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()

    self._sensor:draw()
end