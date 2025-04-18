require "common.sound_manager"

rt.settings.overworld.coin = {
    radius = 5,
    sound_id = "overworld_coin_collected"
}

--- @class ow.Coin
ow.Coin = meta.class("Coin")

--- @brief
function ow.Coin:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Coin.instantiate: object is not a point")

    stage:add_coin(self, object.id)

    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, rt.settings.overworld.coin.radius)
    )

    self._is_collected = false

    self._body:set_is_sensor(true)
    self._body:set_collides_with(bit.bor(
        rt.settings.overworld.player.player_collision_group,
        rt.settings.overworld.player.player_outer_body_collision_group
    ))

    self._body:signal_connect("collision_start", function(self_body, player_body)
        if self._is_collected then return end
        rt.SoundManager:play(rt.settings.overworld.coin.sound_id)
        local x, y = self_body:get_position()
        player_body:get_user_data():pulse(x, y)
        self._is_collected = true
        --return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Coin:set_is_collected(b)
    self._is_collected = b
end

--- @brief
function ow.Coin:get_is_collected()
    return self._is_collected
end

--- @brief
function ow.Coin:update(delta)
    if self._is_collected then return end
end

--- @brief
function ow.Coin:draw()
    if self._is_collected then return end

    rt.Palette.YELLOW:bind()
    self._body:draw()
end