require "overworld.stage_config"
require "common.random"
require "common.scene_manager"
require "common.player"

rt.settings.game_state = {
    save_file = "debug_save.lua",
    grade_double_s_threshold = 0.998,
    grade_s_threshold = 0.95,
    grade_a_threshold = 0.85,
}

--- @class rt.VSyncMode
rt.VSyncMode = meta.enum("VSyncMode", {
    ADAPTIVE = -1,
    OFF = 0,
    ON = 1
})

--- @class rt.MSAAQuality
rt.MSAAQuality = meta.enum("MSAAQuality", {
    OFF = 0,
    GOOD = 2,
    BETTER = 4,
    BEST = 8,
    MAX = 16
})

--- @brief rt.GameState
rt.GameState = meta.class("GameState")

--- @brief
function rt.GameState:instantiate()
    local width, height, mode = love.window.getMode()

    -- common
    self._state = {
       is_fullscreen = mode.is_fullscreen,
       vsync = mode.vsync,
       msaa = mode.msaa,
       screen_shake_enabled = true,
       resolution_x = width,
       resolution_y = height,
       sound_effect_level = 1.0,
       music_level = 1.0,
       text_speed = 1.0,
       joystick_deadzone = 0.15,
       trigger_deadzone = 0.05
    }

    -- read settings from conf.lua
    for setter_setting in range(
        { self.set_music_level, _G.SETTINGS.music_level },
        { self.set_sound_effect_level, _G.SETTINGS.sound_effect_level },
        { self.set_text_speed, _G.SETTINGS.text_speed },
        { self.set_joystick_deadzone, _G.SETTINGS.joystick_deadzone },
        { self.set_trigger_deadzone, _G.SETTINGS.trigger_deadzone },
        { self.set_is_screen_shake_enabled, _G.SETTINGS.screen_shake_enabled }
    ) do
        local setter, setting = table.unpack(setter_setting)
        if setting ~= nil then setter(self, setting) end
    end

    self:_initialize_stage()

    self._player = rt.Player()
end

--- @brief
function rt.GameState:set_vsync_mode(mode)
    meta.assert_enum_value(mode, rt.VSyncMode, 1)
    self._state.vsync = mode
    love.window.setVSync(mode)
end

--- @brief
function rt.GameState:get_vsync_mode(mode)
    return love.window.getVSync()
end

--- @brief
function rt.GameState:set_msaa_quality(msaa)
    meta.assert_enum_value(msaa, rt.MSAAQuality, 1)
    self._state.msaa = msaa
    local w, h, mode = love.window.getMode()
    mode.msaa = self._state.msaa
    love.window.setMode(w, h, mode)
end

--- @brief
function rt.GameState:get_msaa_quality()
    local _, _, mode = love.window.getMode()
    return mode.msaa
end

--- @brief
function rt.GameState:set_is_fullscreen(b)
    meta.assert(b, "Boolean")
    self._state.is_fullscreen = b
    love.window.setFullscreen(b)
end

--- @brief
function rt.GameState:get_is_fullscreen()
    return love.window.getFullscreen()
end

--- @brief
function rt.GameState:set_sound_effect_level(level)
    meta.assert(level, "Number")
    self._state.sound_effect_level = math.clamp(level, 0, 1)
end

--- @brief
function rt.GameState:get_sound_effect_leve()
    return self._state.sound_effect_level
end

--- @brief
function rt.GameState:set_music_level(level)
    meta.assert(level, "Number")
    self._state.music_level = math.clamp(level, 0, 1)
end

--- @brief
function rt.GameState:get_music_level()
    return self._state.music_level
end

--- @brief
function rt.GameState:set_text_speed(fraction)
    meta.assert(fraction, "Number")
    self._state.text_speed = fraction -- no clamp
end

--- @brief
function rt.GameState:get_text_speed()
    return self._state.text_speed
end

--- @brief
function rt.GameState:set_joystick_deadzone(fraction)
    meta.assert(fraction, "Number")
    self._state.joystick_deadzone = math.clamp(fraction, 0, 0.9) -- not 1, or controller would deadlock
end

--- @brief
function rt.GameState:get_joystick_deadzone()
    return self._state.joystick_deadzone
end

--- @brief
function rt.GameState:set_trigger_deadzone(fraction)
    meta.assert(fraction, "Number")
    self._state.trigger_deadzone = math.clamp(fraction, 0, 0.9)
end

--- @brief
function rt.GameState:get_trigger_deadzone()
    return self._state.trigger_deadzone
end

--- @brief
function rt.GameState:set_is_screen_shake_enabled(b)
    self._state.screen_shake_enabled = b
end

--- @brief
function rt.GameState:get_is_screen_shake_enabled()
    return self._state.screen_shake_enabled
end

require "common.game_state_stage"

rt.GameState = rt.GameState()