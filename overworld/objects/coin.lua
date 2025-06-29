require "common.sound_manager"
require "common.timed_animation"
require "overworld.coin_particle"

rt.settings.overworld.coin = {
    radius = 10,
    pulse_animation_duration = 0.4,
    sound_id = "overworld_coin_collected",
    flow_increase = 0.1,
    particle_padding = 3,
    translation_noise_frequency = 0.1,
    amplitude_noise_frequency = 1,
    amplitude_max_offset = 0.3, -- 1 +/- fraction
    follow_offset = 40, -- px
}

--- @class ow.Coin
ow.Coin = meta.class("Coin")

local _pulse_mesh = nil
local _particle_texture, _particle_shader

local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
end

function ow.Coin.index_to_hue(i)
    return _hue_steps[((i - 1) % _n_hue_steps) + 1]
end

--- @brief
function ow.Coin:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Coin.instantiate: object is not a point")

    local radius = rt.settings.overworld.coin.radius
    if _particle_shader == nil then
        _particle_shader = rt.Shader("overworld/objects/coin.glsl")
    end

    if _particle_texture == nil then
        local padding = rt.settings.overworld.coin.particle_padding
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))
        _particle_texture:bind()
        _particle_shader:bind()
        love.graphics.rectangle("fill", padding, padding, 2 * radius, 2 * radius)
        _particle_shader:unbind()
        _particle_texture:unbind()
    end

    self._id = object.id -- TODO: global id

    self._stage = stage
    self._scene = scene
    self._x, self._y = object.x, object.y
    self._follow_motion = rt.SmoothedMotion2D(self._x, self._y, 1.1)
    self._follow_x, self._follow_y = self._x, self._y
    self._follow_offset = 0

    self._pulse_x, self._pulse_y = 0, 0
    self._particle = ow.CoinParticle(radius)

    stage:add_coin(self, self._id)

    self._index = object:get_number("index") or stage:get_n_coins()
    self._hue = ow.Coin.index_to_hue(self._index)

    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    self._particle:set_hue(self._hue)

    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, rt.settings.overworld.coin.radius)
    )

    self._x, self._y, self._radius = object.x, object.y, radius

    self._is_collected = false
    self._timestamp = -math.huge -- timestamp of collection
    self._noise_x, self._noise_y = 0, 0
    self._noise_dx, self._noise_dy = math.cos(rt.random.number(0, 2 * math.pi)), math.sin(rt.random.number(0, 2 * math.pi))
    self._noise_amplitude = 1
    self._elapsed = 0

    self._body:set_user_data(self)
    self._body:set_is_sensor(true)
    self._body:add_tag("light_source")
    self._body:set_collides_with(bit.bor(
        rt.settings.player.player_collision_group,
        rt.settings.player.player_outer_body_collision_group
    ))

    self._body:signal_connect("collision_start", function(self_body, player_body)
        if self._is_collected then return end
        rt.SoundManager:play(rt.settings.overworld.coin.sound_id)
        self._is_collected = true
        self._follow_offset = rt.settings.overworld.coin.follow_offset * self._stage:get_n_coins_collected()
        self._stage:set_coin_is_collected(self._id, true)
        self._timestamp = love.timer.getTime()
        self._pulse_opacity_animation:reset()
        self._pulse_active = true
    end)

    if _pulse_mesh == nil then
        _pulse_mesh = rt.MeshCircle(0, 0, rt.settings.player.radius * 2)

        _pulse_mesh:set_vertex_color(1, 1, 1, 1, 0)
        for i = 2, _pulse_mesh:get_n_vertices() do
            _pulse_mesh:set_vertex_color(i, 1, 1, 1, 1)
        end
        _pulse_mesh = _pulse_mesh:get_native()
    end

    self._pulse_opacity_animation = rt.TimedAnimation(
        rt.settings.overworld.coin.pulse_animation_duration,
        1, 0
    )
    self._pulse_active = false
end

--- @brief
function ow.Coin:get_render_priority()
    return math.huge
end

--- @brief
function ow.Coin:set_is_collected(b)
    if b ~= self._is_collected then
        if b == false then
            self._follow_x, self._follow_y = self._x, self._y
            self._follow_motion:set_position(self._x, self._y)
        end
    end

    self._is_collected = b
end

--- @brief
function ow.Coin:get_is_collected()
    return self._is_collected
end

--- @brief
function ow.Coin:update(delta)
    if self._is_collected then
        if self._pulse_active then
            self._pulse_active = not self._pulse_opacity_animation:update(delta)
            self._pulse_x, self._pulse_y = self._scene:get_player():get_physics_body():get_predicted_position()
        end

        local player_radius = rt.settings.player.radius
        self._follow_motion:set_target_position(self._scene:get_player():get_past_position(self._follow_offset))
        self._follow_motion:update(delta)
        self._follow_x, self._follow_y = self._follow_motion:get_position()
    else
        if not self._scene:get_is_body_visible(self._body) then return end

        self._elapsed = self._elapsed + delta
        local frequency = rt.settings.overworld.coin.translation_noise_frequency
        local offset = self._radius
        self._noise_x = (rt.random.noise(self._noise_dx * self._elapsed * frequency, self._noise_dy * self._elapsed * frequency) * 2 - 1) * offset
        self._noise_y = (rt.random.noise(-self._noise_dx * self._elapsed * frequency, -self._noise_dy * self._elapsed * frequency) * 2 - 1) * offset

        frequency = rt.settings.overworld.coin.amplitude_noise_frequency
        self._noise_amplitude = rt.settings.overworld.coin.amplitude_max_offset * (rt.random.noise(self._noise_dx * self._elapsed * frequency, self._noise_dy * self._elapsed * frequency) * 2 - 1)
    end
end

--- @brief
function ow.Coin:draw()
    if not self._is_collected and not self._scene:get_is_body_visible(self._body) then return end

    if self._is_collected then
        if self._pulse_active then
            local r, g, b = self._color:unpack()
            local v = self._pulse_opacity_animation:get_value()

            local x, y = self._pulse_x, self._pulse_y
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(2 * (1 - v))
            love.graphics.translate(-x, -y)
            love.graphics.setColor(r, g, b, v)
            love.graphics.draw(_pulse_mesh, x, y)
            love.graphics.pop()

            x, y = self._follow_x, self._follow_y
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(2 * (1 - v))
            love.graphics.translate(-x, -y)
            love.graphics.setColor(r, g, b, v)
            love.graphics.draw(_pulse_mesh, x, y)
            love.graphics.pop()
        end

        self._particle:draw(self._follow_x, self._follow_y)
    else
        self._particle:draw(self._x + self._noise_x, self._y + self._noise_y)
    end
end

--- @brief
function ow.Coin:get_color()
    if self._is_collected then return rt.RGBA(0, 0, 0, 0) end
    return rt.RGBA(self._color.r, self._color.g, self._color.b, 1 + self._noise_amplitude)
end

--- @brief
function ow.Coin:get_position()
    return self._x, self._y
end


--- @brief
function ow.Coin:get_should_bloom()
    return true
end

--- @brief
function ow.Coin:draw_bloom()
    if self._scene:get_is_body_visible(self._body) and self._is_collected ~= true then
        self._particle:draw_bloom(self._x + self._noise_x, self._y + self._noise_y)
    end
end