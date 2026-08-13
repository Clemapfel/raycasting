require "common.color"
require "common.palette"
require "common.shader"
require "common.lch_texture"

rt.settings.fade = {
    default_duration = 120 / 60
}

--- @class rt.Fade
rt.Fade = meta.class("Fade")
meta.add_signal(rt.Fade, "hidden", "done")

local _default_shader = rt.Shader("common/fade_default.glsl")
local _lch_texture = rt.LCHTexture(1, 1, 256)

--- @brief
function rt.Fade:instantiate(duration, shader_path)
    meta.assert(
        duration, mt.Optional(mt.Number),
        shader_path, mt.Optional(mt.String)
    )

    duration = duration or rt.settings.fade.default_duration

    local r, g, b, a = rt.Palette.TRUE_BLACK:unpack()

    if shader_path ~= nil then
        self._shader = rt.Shader(shader_path)
        self._shader:compile()
    else
        self._shader = _default_shader
    end

    meta.install(self, {
        _duration = duration,
        _elapsed = 0,
        _value = 0, -- opacity of overlay
        _direction = 0,
        _has_attack = true,
        _has_decay = true,
        _hidden_emitted = true,
        _queue_hidden_emit = false,
        _done_emitted = true,
        _queue_done_emit = false,
        _started = false,
        _r = r,
        _g = g,
        _b = b,
        _a = a
    })
end

--- @brief
--- @param has_attack Boolean if false, skips starting ramp
function rt.Fade:start(has_attack, has_decay)
    if has_attack == nil then has_attack = true end
    if has_decay == nil then has_decay = true end

    self._elapsed = 0
    self._has_attack = has_attack
    self._has_decay = has_decay

    self._hidden_emitted = false
    self._queue_hidden_emit = false

    self._done_emitted = false
    self._queue_done_emit = false

    self._started = true
    self:update(0)
end

--- @brief
function rt.Fade:skip()
    self._elapsed = math.huge
    self._value = 0
    self._started = false
    self._queue_hidden_emit = false
    self._queue_done_emit = false
end

--- @brief
function rt.Fade:reset()
    self._elapsed = 0
    self._value = 0
    self._hidden_emitted = false
    self._queue_hidden_emit = false
    self._done_emitted = false
    self._queue_done_emit = false
    self._started = false
end

local function gaussian(x, center)
    return math.exp(-4.4 * math.pi / 3 * ((x - center)^2))
end

local function _envelope(fraction, has_attack, has_decay)
    if fraction < 0 or fraction > 1 then return 0 end

    if fraction < 0.5 then -- attack
        if has_attack then
            return gaussian(fraction / 0.5, 1), 1
        else
            return 1, 0
        end
    else
        if has_decay then
            return gaussian((fraction - 0.5) / 0.5, 0), -1
        else
            return 1, 0
        end
    end
end

--- @brief
function rt.Fade:update(delta)
    local fraction = self._elapsed / self._duration
    self._value, self._direction = _envelope(fraction, self._has_attack, self._has_decay)

    if self._queue_hidden_emit then
        self:signal_emit("hidden")
        self._hidden_emitted = true
        self._queue_hidden_emit = false
    end

    if self._queue_done_emit then
        self:signal_emit("done")
        self._done_emitted = true
        self._queue_done_emit = false
    end

    if self._hidden_emitted == false and fraction >= 0.5 then
        self._value = 1
        self._queue_hidden_emit = true
    end

    if self._done_emitted == false and fraction >= 1 then
        self._value = 0
        self._queue_done_emit = true
    end

    if self._started then
        self._elapsed = self._elapsed + delta
    end
end

--- @brief
function rt.Fade:draw()
    if self._value == 0 or self._elapsed == 0 then return end

    if self._started == true then
        love.graphics.push()
        love.graphics.origin()
        self._shader:bind()

        if self._queue_hidden_emit then
            self._shader:send("value", 1.0) -- make sure screen is full black on emission
        else
            self._shader:send("value", self._value)
        end

        if self._shader:has_uniform("direction") then
            self._shader:send("direction", self._direction)
        end

        if self._shader:has_uniform("elapsed") then
            self._shader:send("elapsed", rt.SceneManager:get_elapsed())
        end

        if self._shader:has_uniform("lch_texture") then
            self._shader:send("lch_texture", _lch_texture)
        end

        love.graphics.setColor(self._r, self._g, self._b, self._a)
        love.graphics.rectangle("fill", 0, 0, rt.SceneManager:get_size())
        self._shader:unbind()
        love.graphics.pop()
    end
end

--- @brief
function rt.Fade:get_is_started()
    return self._started
end

--- @brief
function rt.Fade:get_is_active()
    return self._value > 0
end

--- @brief
function rt.Fade:set_duration(duration)
    self._duration = duration
end

--- @brief
function rt.Fade:set_shader(shader)
    meta.assert(shader, rt.Shader)
    rt.assert(shader:get_native():hasUniform("value"))
    self._shader = shader
    self._shader:compile()
end

--- @brief
function rt.Fade:get_value()
    return self._value
end