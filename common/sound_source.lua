--- @class rt.SoundSourceFilterType
rt.SoundSourceFilterType = meta.enum("SoundSourceFilterType", {
    LOWPASS = "lowpass",
    BANDPASS = "bandpass",
    HIGHPASS = "highpass"
})

--- @class rt.SoundSource
rt.SoundSource = meta.class("SoundSource")

--- @brief
function rt.SoundSource:instantiate(id, handler_id, native)
    rt.assert(native.typeOf ~= nil and native:typeOf("Source"), "In rt.SoundSource: expected `love.audio.Source`, got `", meta.typeof(native), "` ")
    self._id = id
    self._handler_id = handler_id
    self._native = native
end

--- @brief
function rt.SoundSource:get_native()
    return self._native
end

--- @brief
function rt.SoundSource:get_id()
    return self._id
end

--- @brief
function rt.SoundSource:get_handler_id()
    return self._handler_id
end

--- @brief
function rt.SoundSource:_check_disabled(scope)
    -- `SoundManager` may disable wrapper so if source is reused
    -- this reference does not affect another `SoundSource`
    if self._native == nil then
        rt.critical("In rt.SoundSource.",  scope,  ": trying to use source `",  self._id,  "`, but it is already released")
        return true
    else
        return false
    end
end

--- @brief
function rt.SoundSource:stop()
    if self:_check_disabled("stop") then return end
    self._native:stop()
end

-- no volume, handled by sound manager
function rt.SoundSource:set_volume(v)
    rt.critical("In rt.SoundSource.set_volume, volume cannot be set directly, use rt.SoundManager.set_volume(source:get_id(), source:get_handler_id(), volume)")
end

function rt.SoundSource:get_volume()
    if self:_check_disabled("get_volume") then return 0 end
    return self._native:getVolume()
end

--- @brief
function rt.SoundSource:set_filter(type, gain)
    meta.assert_enum_value(type, rt.SoundSourceFilterType)
    local config = {
        type = type
    }

    if gain ~= nil then
        if type == rt.SoundSourceFilterType.LOWPASS then
            config.highgain = gain
        elseif type == rt.SoundSourceFilterType.HIGHPASS then
            config.lowgain = gain
        end
    end

    if not self._native:setFilter(config) then
        rt.critical("In rt.SoundSource: unable to apply filter `",  type,  "` to source `",  self._id,  "`")
    end
end

--- @brief
function rt.SoundSource:add_effect(effect)
    if self:_check_disabled("add_effect") then return end
    if love.audio.isEffectsSupported() ~= true then return end
    meta.assert(effect, rt.SoundSourceEffect)
    self._native:setEffect(effect:get_native(), true)
end

--- @brief
function rt.SoundSource:remove_effect(effect)
    if self:_check_disabled("remove_effect") then return end
    if love.audio.isEffectsSupported() ~= true then return end
    meta.assert(effect, rt.SoundSourceEffect)
    self._native:setEffect(effect:get_native(), false)
end

--- @brief
function rt.SoundSource:has_effect(effect)
    if self:_check_disabled("has_effect") then return end
    if love.audio.isEffectsSupported() ~= true then return false end
    meta.assert(effect, rt.SoundSourceEffect)
    return self._native:getEffect(effect:get_native())
end