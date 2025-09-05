require "common.color"
require "common.palette"
require "common.shader"

rt.settings.fade = {
    default_duration = 120 / 60
}

--- @class rt.Fade
rt.Fade = meta.class("Fade")

local _default_shader = rt.Shader("common/fade_default.glsl")

--- @brief
function rt.Fade:instantiate(duration, shader_path)
    duration = duration or rt.settings.fade.default_duration
    meta.assert_typeof(duration, "Number", 1)

    local r, g, b, a = rt.Palette.TRUE_BLACK:unpack()

    if shader_path ~= nil then
        meta.assert_typeof(shader_path, "String", 2)
        self._shader = rt.Shader(shader_path)
        self._shader:precompile()
    end

    meta.install(self, {
        _duration = duration,
        _elapsed = 0,
        _value = 0, -- opacity of overlay
        _direction = 0,
        _has_attack = true,
        _has_decay = true,
        _signal_emitted = true,
        _queue_emit = false,
        _started = false,
        _r = r,
        _g = g,
        _b = b,
        _a = a
    })
end

meta.add_signal(rt.Fade, "hidden")

--- @brief
--- @param has_attack Boolean if false, skips starting ramp
function rt.Fade:start(has_attack, has_decay)
    if has_attack == nil then has_attack = true end
    if has_decay == nil then has_decay = true end

    self._elapsed = 0
    self._has_attack = has_attack
    self._has_decay = has_decay
    self._signal_emitted = false
    self._started = true
    self:update(0)
end

--- @brief
function rt.Fade:skip()
    self._elapsed = math.huge
    self._value = 0
end

--- @brief
function rt.Fade:reset()
    self._elapsed = 0
    self._signal_emitted = false
    self._queue_emit = false
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

    if self._signal_emitted == false and fraction > 0.5 then
        self._value = 1
        self._queue_emit = true -- wait until draw
    end

    if self._started then
        self._elapsed = self._elapsed + delta
    end
end

--- @brief
function rt.Fade:draw()
    if self._value == 0 then return end

    if self._started == true then
        love.graphics.push()
        love.graphics.origin()
        self._shader:bind()
        self._shader:send("value", self._value)

        if self._shader:has_uniform("direction") then
            self._shader:send("direction", self._direction)
        end

        if self._shader:has_uniform("elapsed") then
            self._shader:send("elapsed", rt.SceneManager:get_elapsed())
        end

        love.graphics.setColor(self._r, self._g, self._b, self._a)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        self._shader:unbind()
        love.graphics.pop()
    end

    if self._queue_emit then
        love.graphics.present() -- force window update, since emit often lags
        self:signal_emit("hidden")
        self._signal_emitted = true
        self._queue_emit = false
    end
end

--- @brief
function rt.Fade:get_is_active()
    return self._signal_emitted == false
end

--- @brief
function rt.Fade:get_is_started()
    return self._started
end

--- @brief
function rt.Fade:get_is_visible()
    return self._value > 0
end

--- @brief
function rt.Fade:set_duration(duration)
    self._duration = duration
end

--- @brief
function rt.Fade:set_shader(shader)
    meta.assert(shader, rt.Shader)
    assert(shader:get_native():hasUniform("value"))
    self._shader = shader
    self._shader:precompile()
end