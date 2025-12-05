require "overworld.double_jump_tether_particle"
require "overworld.player_tether_particle_effect"
require "overworld.player_tether"
require "common.impulse_manager"
require "overworld.movable_object"

rt.settings.overworld.double_jump_tether = {
    radius_factor = 1.5,
}

--- @class DoubleJumpTether
--- @types Point
ow.DoubleJumpTether = meta.class("DoubleJumpThether", ow.MovableObject)
meta.add_signal(ow.DoubleJumpTether, "removed")

local _shader

local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

local eps = 0.01

--- @brief
function ow.DoubleJumpTether:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.DoubleJumpTether: tiled object is not a point")

    self._x, self._y, self._radius = object.x, object.y, rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.KINEMATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )
    self._scene = scene
    self._stage = stage

    -- collision
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._body:add_tag("light_source")
    self._body:set_user_data(self)

    self._was_consumed = false
    self._body:signal_connect("collision_start", function(_)
        local player = self._scene:get_player()
        if not player:get_is_double_jump_source(self)
            and self._particle_opacity_motion:get_value() > 0.8 -- cooldown tied to animation
        then
            player:add_double_jump_source(self)
            player:pulse(self._color)
            self:update(0)
        end
    end)

    -- graphics
    self._hue = _hue_steps[_current_hue_step]
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    _current_hue_step = _current_hue_step % _n_hue_steps + 1
    self._particle = ow.DoubleJumpTetherParticle(self._radius)
    self._line_opacity_motion = rt.SmoothedMotion1D(0, 3.5)
    self._tether= ow.PlayerTether(self._scene)
    self._particle_opacity_motion = rt.SmoothedMotion1D(1, 2)
    self._particles = ow.PlayerTetherParticleEffect()

    self:signal_connect("removed", function()
        local ax, ay = self:get_position()
        local bx, by = self._scene:get_player():get_position()
        self._particles:emit(
            self._tether:as_path(),
            self:get_color():unpack()
        )
    end)

    self._impulse = rt.ImpulseSubscriber()
end

--- @brief
function ow.DoubleJumpTether:update(delta)
    local is_consumed = self._scene:get_player():get_is_double_jump_source(self)
    local is_visible = self._stage:get_is_body_visible(self._body)

    self._particles:update(delta)
    self._line_opacity_motion:update(delta)
    local already_tethered = false

    -- show / hide particle when consumed
    if self._was_consumed == false and is_consumed == true then
        self._line_opacity_motion:set_target_value(1)
        self._particle_opacity_motion:set_target_value(0)
        self._particle:set_is_exploded(true)
        local x, y = self._body:get_position()
        self._tether:tether(x, y, self._scene:get_player():get_position())
    elseif self._was_consumed == true and is_consumed == false then
        self._line_opacity_motion:set_target_value(0)
        self._particle_opacity_motion:set_target_value(1)
        self._particle:set_is_exploded(false)
    end
    self._was_consumed = is_consumed

    self._particle_opacity_motion:update(delta)
    self._line_opacity_motion:update(delta)

    -- update particle if on screen and visible
    if is_visible then
        if self._particle_opacity_motion:get_value() > eps then
            self._particle:update(delta)
        end

        self._particle:set_brightness_offset(self._impulse:get_pulse())
        self._particle:set_scale_offset(self._impulse:get_beat())
    end

    -- update line if visible
    if self._line_opacity_motion:get_value() > eps then
        local x, y = self._body:get_position()
        self._tether:tether( -- update player position
            x, y,
            self._scene:get_player():get_position()
        )
        self._tether:update(delta)
    end
end

--- @brief
function ow.DoubleJumpTether:get_render_priority()
    return math.huge -- in front of player
end

--- @brief
function ow.DoubleJumpTether:draw()
    local x, y = self._body:get_position()

    local line_a = self._line_opacity_motion:get_value()
    if line_a > eps then
        local r, g, b = self._color:unpack()
        love.graphics.setColor(r, g, b, 1)
        self._tether:draw()
    end

    self._particles:draw()

    if self._stage:get_is_body_visible(self._body) then
        local shape_a = self._particle_opacity_motion:get_value()
        local r, g, b = self._color:unpack()

        -- always draw core, fade out line
        love.graphics.setColor(r, g, b, 1)
        self._particle:draw(x, y, false, true) -- core only

        if shape_a > eps then
            love.graphics.setColor(r, g, b, shape_a)
            self._particle:draw(x, y, true, true) -- both
        end
    end
end

--- @brief
function ow.DoubleJumpTether:draw_bloom()
    if self._stage:get_is_body_visible(self._body) == false then return end
    local x, y = self._body:get_position()

    local r, g, b = self._color:unpack()
    local shape_a = self._particle_opacity_motion:get_value()
    if shape_a > eps then
        love.graphics.setColor(r, g, b, shape_a)
        self._particle:draw(x, y, false, true) -- line only
    end

    local line_a = self._line_opacity_motion:get_value()
    if line_a > eps then
        love.graphics.setColor(r, g, b, 1)
        self._tether:draw()
    end
end

--- @brief
function ow.DoubleJumpTether:get_color()
    return self._color
end

--- @brief
function ow.DoubleJumpTether:get_position()
    return self._body:get_position()
end

--- @brief
function ow.DoubleJumpTether:reset()
    local player = self._scene:get_player()
    if player:get_is_double_jump_source(self) then
        player:remove_double_jump_source(self)
        self:update(0)
    end
end
