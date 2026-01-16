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
        b2.BodyType.DYNAMIC
    )

    self._start_velocity_x = object:get_number("velocity_x") or 0
    self._start_velocity_y = object:get_number("velocity_y") or 0
    self._start_x, self._start_y = object:get_centroid()

    self._sensor = object:get_object("sensor", true):create_physics_body(
        self._world,
        b2.BodyType.STATIC
    )
    self._sensor:set_is_sensor(true)

    for body in range(self._body, self._sensor) do
        body:set_collision_group(rt.settings.player.bounce_collision_group)
        body:set_collides_with(rt.settings.player.bounce_collision_group)
    end

    self._stage:signal_connect("respawn", function(_)
        self._body:set_position(self._start_x, self._start_y)
        self._body:set_velocity(0, 0)
        self._is_active = false
    end)

    self._sensor:signal_connect("collision_start", function(_, other_body)
        self._is_active = true
    end)

    self._sensor:signal_connect("collision_end", function(_, other_body)
        self._is_active = false
    end)

    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            self._scene:get_player():kill()
        end
    end)
end

--- @brief
function ow.KaizoFish:update(delta)
    if self._is_active == true then
        self._body:set_velocity(self._start_velocity_x, self._start_velocity_y)
    end
end

--- @brief
function ow.KaizoFish:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()

    self._sensor:draw()
end