--- @class rt.CrossFader
--- equal power, 2 channel crossfader
rt.CrossFader = meta.class("CrossFader")

--- @brief
function rt.CrossFader:instantiate(initial_t)
    if initial_t == nil then initial_t = 0 end
    meta.assert(initial_t, mt.Number)

    self._t = initial_t
    self._gain_a = 1
    self._gain_b = 0
    self:set_fade(initial_t)
end

--- @brief
--- @param t Number position, -1 (fully source a) to 1 (fully source b)
function rt.CrossFader:set_fade(t)
    meta.assert(t, mt.Number)

    if t < -1 then t = -1 end
    if t > 1 then t = 1 end

    self._t = t

    local normalized_t = (t + 1) / 2
    local angle = normalized_t * (math.pi / 2)

    self._gain_a = math.cos(angle)
    self._gain_b = math.sin(angle)
end

--- @brief
--- @return Number, Number first source level, second source level
function rt.CrossFader:get_gain(t)
    if t ~= nil then
        meta.assert(t, mt.Number)
        self:set_fade(t)
    end

    return self._gain_a, self._gain_b
end