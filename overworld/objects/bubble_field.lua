--- @class ow.BubbleField
ow.BubbleField = meta.class("BubbleField")

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    self._scene = scene
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
    self._body:signal_connect("collision_start", function()
        local player = scene:get_player()
        if player:get_is_bubble() == false then
            player:set_is_bubble(true)
        end
    end)

    self._body:signal_connect("collision_end", function()
        local player = scene:get_player()
        if player:get_is_bubble() == true then
            player:set_is_bubble(false)
        end
    end)
end

--- @brief
function ow.BubbleField:draw()
    rt.Palette.BLUE_1:bind()
    self._body:draw()
end