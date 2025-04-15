require "common.sound_manager"

rt.settings.overworld.coin = {
    radius = 16,
    sound_id = "overworld_coin_collected"
}

--- @class ow.Coin
ow.Coin = meta.class("Coin")

--- @brief
function ow.Coin:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Coin.instantiate: object is not a point")
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, rt.settings.overworld.coin.radius)
    )

    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
    self._body:signal_connect("collision_start", function(_, player_body)
        rt.SoundManager:play(rt.settings.overworld.coin.sound_id)
    end)
end