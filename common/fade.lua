rt.settings.fade = {
    default_duration = 120 / 60
}

--- @class rt.Fade
rt.Fade = meta.class("Fade")

--- @brief
function rt.Fade:instantiate(duration, r, g, b, a)
    duration = duration or rt.settings.fade.default_duration
    if r == nil then
        r, g, b, a = rt.Palette.BLACK:unpack()
    end

    meta.install(self, {
        _duration = duration,
        _elapsed = 0,
        _value = 0, -- opacity of overlay
        _should_ramp = true,
        _signal_emitted = true,

        _r = r,
        _g = g,
        _b = b,
        _a = a
    })
end

meta.add_signal(rt.Fade, "hidden")

--- @brief
--- @param should_ramp Boolean if false, skips starting ramp
function rt.Fade:start(should_ramp)
    if should_ramp == nil then should_ramp = true end
    self._elapsed = 0
    self._should_ramp = should_ramp
    self._signal_emitted = false
end

--- @brief
function rt.Fade:skip()
    self._elapsed = math.huge
end

local function gaussian(x, center)
    return math.exp(-4.4 * math.pi / 3 * ((x - center)^2))
end

local function _envelope(fraction, should_ramp)
    if fraction > 1 then return 0 end
    if fraction < 0.5 then -- attack
        if should_ramp then
            return gaussian(fraction / 0.5, 1)
        else
            return 1
        end
    else
        return gaussian((fraction - 0.5) / 0.5, 0)
    end
end

--- @brief
function rt.Fade:update(delta)
    local fraction = self._elapsed / self._duration
    self._value = _envelope(fraction, self._should_ramp)

    if self._signal_emitted == false and fraction >= 0.5 then
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