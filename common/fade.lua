require "common.color"
require "common.palette"

rt.settings.fade = {
    default_duration = 120 / 60
}

--- @class rt.Fade
rt.Fade = meta.class("Fade")

--- @brief
function rt.Fade:instantiate(duration, r, g, b, a)
    duration = duration or rt.settings.fade.default_duration
    if r == nil then
        r, g, b, a = rt.Palette.TRUE_BLACK:unpack()
    end

    meta.install(self, {
        _duration = duration,
        _elapsed = 0,
        _value = 0, -- opacity of overlay
        _has_attack = true,
        _has_decay = true,
        _signal_emitted = true,

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
end

--- @brief
function rt.Fade:skip()
    self._elapsed = math.huge
end

local function gaussian(x, center)
    return math.exp(-4.4 * math.pi / 3 * ((x - center)^2))
end

local function _envelope(fraction, has_attack, has_decay)
    if fraction < 0 or fraction > 1 then return 0 end

    if fraction < 0.5 then -- attack
        if has_attack then
            return gaussian(fraction / 0.5, 1)
        else
            return 1
        end
    else
        if has_decay then
            return gaussian((fraction - 0.5) / 0.5, 0)
        else
            return 1
        end
    end
end

--- @brief
function rt.Fade:update(delta)
    local fraction = self._elapsed / self._duration
    self._value = _envelope(fraction, self._has_attack, self._has_decay)

    if self._signal_emitted == false and fraction >= 0.5 then
        self._value = 1

        -- make sure screen is fully black for lag frames during emit
        love.graphics.clear()
        self:draw()
        love.graphics.present()

        self:signal_emit("hidden")
        self._signal_emitted = true
    end

    self._elapsed = self._elapsed + delta
end

--- @brief
function rt.Fade:draw()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(self._r, self._g, self._b, self._a * self._value)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
end

--- @brief
function rt.Fade:get_is_active()
    return self._signal_emitted == false
end

--- @brief
function rt.Fade:set_duration(duration)
    self._duration = duration
end