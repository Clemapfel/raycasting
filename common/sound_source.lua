--- @class rt.SoundSource
rt.SoundSource = meta.class("SoundSource")

--- @brief
function rt.SoundSource:instantiate(native)
    assert(native.typeOf ~= nil and native:typeOf("Source"), "In rt.SoundSource: expected `love.audio.Source`, got `" .. meta.typeof(native) .. "` ")

    self._native = native
end

--- @brief
function rt.SoundSource:stop()
    self._native:stop()
end

--- @brief
function rt.SoundSource:set_effect(effect)
    if love.audio.isEffectsSupported() ~= true then return end

    meta.assert(effect, rt.SoundEffect)

end