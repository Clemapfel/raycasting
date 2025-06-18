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
        local player = self._scene:get_player()
        if not self._is_consumed and not player:get_is_double_jump_source(self) then
            player:add_double_jump_source(self)
            self._is_consumed = true
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
function ow.DoubleJumpTether:get_render_priority()
    return math.huge -- in front of player
end

--- @brief
function ow.DoubleJumpTether:draw()
    local player = self._scene:get_player()
    if self._is_consumed then
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("fill", self._x, self._y, self._radius * 0.25)

        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("line", self._x, self._y, self._radius * 0.25)

        if player:get_is_double_jump_source(self) then
            local line_width = 1
            rt.Palette.BLACK:bind()
            love.graphics.setLineWidth(line_width + 2)
            love.graphics.line(
                self._x, self._y,
                player:get_position()
            )
            rt.Palette.WHITE:bind()
            love.graphics.setLineWidth(line_width + 2)
            love.graphics.line(
                self._x, self._y,
                player:get_position()
            )
        end
    else
        love.graphics.setColor(1, 1, 1, 1)
        self._body:draw()
    end
end