--- @class ow.BubbleField
ow.BubbleField = meta.class("BubbleField")

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    self._scene = scene
    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    self._body:signal_connect("collision_start", function()
        local player = scene:get_player()
        if player:get_is_bubble() == false and not self._blocked then
            self:_block_signals()

            player:set_is_bubble(true)
        end
    end)

    self._body:signal_connect("collision_end", function()
        local player = scene:get_player()
        if player:get_is_bubble() == true and not self._blocked then
            self:_block_signals()

            -- check if player is actually outside body
            if self._body:test_point(player:get_physics_body():get_position()) then
                return
            end

            player:set_is_bubble(false)
        end
    end)
end

--- @brief
function ow.BubbleField:draw()
    rt.Palette.BLUE_1:bind()
    self._body:draw()
end

--- @brief
function ow.BubbleField:_block_signals()
    -- block signals until next step to avoid infinite loops
    -- because set_is_bubble can teleport
    self._body:signal_set_is_blocked("collision_start", true)
    self._body:signal_set_is_blocked("collision_end", true)

    self._world:signal_connect("step", function()
        self._body:signal_set_is_blocked("collision_start", false)
        self._body:signal_set_is_blocked("collision_end", false)
        return meta.DISCONNECT_SIGNAL
    end)
end