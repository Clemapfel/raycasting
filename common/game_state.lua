require "overworld.stage_config"
require "common.input_action"
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
       trigger_deadzone = 0.05,

       input_mapping = {}
    }

    self._keyboard_key_to_input_action = {}
    self._controller_button_to_input_action = {}
    self:_load_default_input_mapping()

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
function rt.GameState:get_sound_effect_level()
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

--- @brief
function rt.GameState:_load_default_input_mapping()
    self._state.input_mapping =
    {
        [rt.InputAction.UP] = {
            keyboard = {"w", "up"},
            controller = rt.ControllerButton.DPAD_UP
        },

        [rt.InputAction.DOWN] = {
            keyboard = {"s", "down"},
            controller = rt.ControllerButton.DPAD_DOWN
        },

        [rt.InputAction.LEFT] = {
            keyboard = {"a", "left"},
            controller = rt.ControllerButton.DPAD_LEFT
        },

        [rt.InputAction.RIGHT] = {
            keyboard = {"d", "right"},
            controller = rt.ControllerButton.DPAD_RIGHT
        },

        [rt.InputAction.A] = {
            keyboard = {"space"},
            controller = rt.ControllerButton.RIGHT
        },

        [rt.InputAction.B] = {
            keyboard = {"b"},
            controller = rt.ControllerButton.BOTTOM
        },

        [rt.InputAction.X] = {
            keyboard = {"x"},
            controller = rt.ControllerButton.TOP
        },

        [rt.InputAction.Y] = {
            keyboard = {"y"},
            controller = rt.ControllerButton.LEFT
        },

        [rt.InputAction.L] = {
            keyboard = {"n", "l"},
            controller = rt.ControllerButton.LEFT_SHOULDER
        },

        [rt.InputAction.R] = {
            keyboard = {"m", "r"},
            controller = rt.ControllerButton.RIGHT_SHOULDER
        },

        [rt.InputAction.START] = {
            keyboard = {"escape"},
            controller = rt.ControllerButton.START
        },

        [rt.InputAction.SELECT] = {
            keyboard = {"#"},
            controller = rt.ControllerButton.SELECT
        }
    }

    local valid, error = self:_validate_input_mapping()

    if valid then
        self:_update_reverse_mapping()
    else
        rt.error(error)
    end
end

--- @brief
function rt.GameState:_validate_input_mapping()
    return true
end

--- @brief
function rt.GameState:_update_reverse_mapping()
    self._keyboard_key_to_input_action = {}
    self._controller_button_to_input_action = {}
    for action in values(meta.instances(rt.InputAction)) do
        local mapping = self._state.input_mapping[action]

        if not meta.is_table(mapping.keyboard) then mapping.keyboard = { mapping.keyboard } end
        if not meta.is_table(mapping.controller) then mapping.controller = { mapping.controller } end

        for key in values(mapping.keyboard) do
            local actions = self._keyboard_key_to_input_action[key]
            if actions == nil then
                actions = {}
                self._keyboard_key_to_input_action[key] = actions
            end
            table.insert(actions, action)
        end

        for button in values(mapping.controller) do
            local actions = self._controller_button_to_input_action[button]
            if actions == nil then
                actions = {}
                self._controller_button_to_input_action[button] = actions
            end
            table.insert(actions, button)
        end
    end
end

--- @brief
function rt.GameState:get_input_mapping(input_action, method)
    meta.assert_enum_value(input_action, rt.InputAction, 1)
    if method == rt.InputMethod.KEYBOARD then
        return table.deepcopy(self._state.input_mapping[input_action].keyboard)
    elseif method == rt.InputMethod.CONTROLLER then
        return table.deepcopy(self._state.input_mapping[input_action].controller)
    elseif method == nil then
        return table.deepcopy(self._state.input_mapping[input_action].keyboard),
        table.deepcopy(self._state.input_mapping[input_action].controller)
    else
        meta.assert_enum_value(method, rt.InputMethod, 2) -- always throws
    end
end

--- @brief
function rt.GameState:get_reverse_input_mapping(native, method)
    meta.assert_enum_value(method, rt.InputMethod)
    if method == rt.InputMethod.KEYBOARD then
        return self._keyboard_key_to_input_action[native]
    elseif method == rt.InputMethod.CONTROLLER then
        return self._controller_button_to_input_action[native]
    end
end

--- @brief
--- @param ... Union<rt.KeyboardKey, rt.ControllerButton>
function rt.GameState:set_input_mapping(input_action, method, ...)
    meta.assert_enum_value(input_action, rt.InputAction, 1)
    meta.assert_typeof(method, rt.InputMethod, 2)
    if method == rt.InputMethod.KEYBOARD then
        local before = table.deepcopy(self._state.input_mapping[input_action].keyboard)
        self._state.input_mapping[input_action].keyboard = { ... }
        local valid, error = self:_validate_input_mapping()
        if not valid then
            self._state.input_mapping[input_action.keyboard] = before
            return false, error
        else
            self:_update_reverse_mapping()
            return true
        end
    elseif method == rt.InputMethod.CONTROLLER then
        local before = table.deepcopy(self._state.input_mapping[input_action].controller)
        self._state.input_mapping[input_action].controller = { ... }
        local valid, error = self:_validate_input_mapping()
        if not valid then
            self._state.input_mapping[input_action.controller] = before
            return false, error
        else
            self:_update_reverse_mapping()
            return true
        end
    end
end

require "common.game_state_stage"

rt.GameState = rt.GameState()