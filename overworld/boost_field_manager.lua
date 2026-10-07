--- @class ow.BoostFieldManager
ow.BoostFieldManager = meta.class("BoostFieldManager")

local _ramp_sound_id = "boost_field.ramp"
local _hold_sound_id = "boost_field.hold"

--- @brief
function ow.BoostFieldManager:instantiate(scene, stage)
    self._scene = scene
    self._stage = stage
    self._boost_field_to_is_active = {}
    self._is_active = false

    self._ramp_sound_handler = nil
    self._hold_sound_handler = nil
end

--- @brief
function ow.BoostFieldManager:notify_boost_field_added(instance, is_active)
    meta.assert(instance, ow.BoostField, is_active, mt.Boolean)

    self._boost_field_to_is_active[instance] = is_active
    if is_active == true then self._is_active = true end
end

--- @brief
function ow.BoostFieldManager:notify_is_active(instance, is_active)
    meta.assert(instance, ow.BoostField, is_active, mt.Boolean)

    self._boost_field_to_is_active[instance] = is_active

    local now = false
    for b in values(self._boost_field_to_is_active) do
        if b == true then
            now = true
            break
        end
    end

    local before = self._is_active
    if before == false and now == true then
        self._ramp_sound_handler = rt.SoundManager:play(_ramp_sound_id)
        self._hold_sound_handler = rt.SoundManager:play(_hold_sound_id, {
            should_loop = true,
            after = self._ramp_sound_handler
        })
    elseif before == true and now == false then
        rt.SoundManager:stop(self._ramp_sound_handler)
        rt.SoundManager:stop(self._hold_sound_handler)
    end

    self._is_active = now
end
