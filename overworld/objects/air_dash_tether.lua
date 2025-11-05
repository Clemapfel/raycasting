rt.settings.overworld.air_dash_tether = {
    radius_factor = 1.5
}

--- @class AirDashTether
--- @types Point
ow.AirDashTether = meta.class("AirDashThether")

local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

--- @brief
function ow.AirDashTether:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.AirDashTether: tiled object is not a point")

    self._x, self._y, self._radius = object.x, object.y, rt.settings.player.radius * rt.settings.overworld.air_dash_tether.radius_factor
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )
    self._scene = scene
    self._stage = stage

    -- collision
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._was_consumed = false
    self._body:signal_connect("collision_start", function(_)
        local player = self._scene:get_player()
        if not player:get_is_air_dash_source(self) then
            player:add_air_dash_source(self)
            player:pulse(self._color)
            self:update(0)
        end
    end)

    -- graphics
    self._hue = _hue_steps[_current_hue_step]
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    _current_hue_step = _current_hue_step % _n_hue_steps + 1
end

--- @brief
function ow.AirDashTether:update(delta)

end

--- @brief
function ow.AirDashTether:get_render_priority()
    return math.huge -- in front of player
end

--- @brief
function ow.AirDashTether:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()
end

--- @brief
function ow.AirDashTether:draw_bloom()
end

--- @brief
function ow.AirDashTether:get_color()
    return self._color
end

--- @brief
function ow.AirDashTether:reset()
    local player = self._scene:get_player()
    if player:get_is_air_dash_source(self) then
        player:remove_air_dash_source(self)
        self:update(0)
    end
end
