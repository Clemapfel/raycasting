rt.settings.overworld.double_jump_tether = {
    radius_factor = 1.5
}

--- @class DoubleJumpTether
ow.DoubleJumpTether = meta.class("DoubleJumpThether")

local _current_thether = nil

--- @brief
function ow.DoubleJumpTether:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.DoubleJumpTether: tiled object is not a point")

    self._x, self._y, self._radius = object.x, object.y, rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )
    self._scene = scene

    -- collision
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._is_consumed = false
    self._body:signal_connect("collision_start", function(_)
        if not self._is_consumed then
            local player = self._scene:get_player()
            player:set_double_jump_allowed(1)
            self._is_consumed = true
            _current_thether = self

            player:signal_connect("grounded", function()
                self._is_consumed = false
                return meta.DISCONNECT_SIGNAL
            end)
        end
    end)
end

--- @brief
function ow.DoubleJumpTether:update(delta)

end

--- @brief
function ow.DoubleJumpTether:draw()
    if self._is_consumed == false then
        love.graphics.setColor(1, 1, 1, 1)
        self._body:draw()
    else
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("fill", self._x, self._y, self._radius * 0.25)

        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("line", self._x, self._y, self._radius * 0.25)
    end
end