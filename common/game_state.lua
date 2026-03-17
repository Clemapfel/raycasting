require "overworld.stage_config"
require "common.msaa_quality"
require "common.vsync_mode"
require "common.input_action"
require "common.random"
require "common.scene_manager"
require "common.player_sprint_mode"
require "common.player"

rt.settings.game_state = {
    min_double_click_threshold = 0.2, -- seconds
    max_double_click_threshold = 0.5,

    log_directory = "logs"
}

--- @class rt.GameState
rt.GameState = meta.class("GameState")

function rt.GameState:instantiate()
    local width, height, mode = love.window.getMode()
    self._state = {
        -- stage results
        stage_results = {}, --[[ Table<StageID, {
            was_cleared,
            best_time,
            best_flow_percentage,
            collected_coins
        }]]--
    }

    self._input_action_to_keyboard_key = {}
    self._keyboard_key_to_input_action = {}

    self._input_action_to_controller_button = {}
    self._controller_button_to_input_action = {}
    self:load_default_input_mapping()
end

--- @brief
function rt.GameState:update(delta)
    -- noop
end

--- @brief
function rt.GameState:set_vsync_mode(mode)
    meta.assert_enum_value(mode, rt.VSyncMode, 1)
    bd.get_config().vsync = mode
    love.window.setVSync(mode)
end

--- @brief
function rt.GameState:get_vsync_mode(mode)
    return bd.get_config().vsync
end

--- @brief
function rt.GameState:set_msaa_quality(msaa)
    meta.assert_enum_value(msaa, rt.MSAAQuality, 1)
    msaa = rt.graphics.msaa_quality_to_native(msaa)
    
    local config = bd.get_config()
    config.msaa = math.min(msaa, love.graphics.getSystemLimits().texturemsaa)
    local w, h, mode = love.window.getMode()
    mode.msaa = ternary(config.is_hdr_enabled, 0, config.msaa)
    love.window.setMode(w, h, mode)
end

--- @brief
function rt.GameState:get_msaa_quality()
    return bd.get_config().msaa
end

--- @brief
function rt.GameState:get_is_bloom_enabled()
    return bd.get_config().is_bloom_enabled
end

--- @brief
function rt.GameState:set_is_bloom_enabled(b)
    meta.assert(b, "Boolean")
    bd.get_config().is_bloom_enabled = b
end

--- @brief
function rt.GameState:get_is_hdr_enabled()
    return bd.get_config().is_hdr_enabled
end

--- @brief
function rt.GameState:set_is_hdr_enabled(b)
    meta.assert(b, "Boolean")
    bd.get_config().is_hdr_enabled = b
end

--- @brief
function rt.GameState:set_is_fullscreen(b)
    meta.assert(b, "Boolean")
    bd.get_config().is_fullscreen = b
    love.window.setFullscreen(b)
end

--- @brief
function rt.GameState:get_is_fullscreen()
    return love.window.getFullscreen()
end

--- @brief
function rt.GameState:set_sound_effect_level(level)
    meta.assert(level, "Number")
    bd.get_config().sound_effect_level = math.clamp(level, 0, 1)
end

--- @brief
function rt.GameState:get_sound_effect_level()
    return bd.get_config().sound_effect_level
end

--- @brief
function rt.GameState:set_music_level(level)
    meta.assert(level, "Number")
    bd.get_config().music_level = math.clamp(level, 0, 1)
end

--- @brief
function rt.GameState:get_music_level()
    return bd.get_config().music_level
end

--- @brief
function rt.GameState:set_text_speed(fraction)
    meta.assert(fraction, "Number")
    bd.get_config().text_speed = fraction -- no clamp
end

--- @brief
function rt.GameState:get_text_speed()
    return bd.get_config().text_speed
end

--- @brief
function rt.GameState:set_joystick_deadzone(fraction)
    meta.assert(fraction, "Number")
    bd.get_config().joystick_deadzone = math.clamp(fraction, 0, 0.5) -- not 1, or controller would deadlock
end

--- @brief
function rt.GameState:get_joystick_deadzone()
    return bd.get_config().joystick_deadzone
end

--- @brief
function rt.GameState:set_trigger_deadzone(fraction)
    meta.assert(fraction, "Number")
    bd.get_config().trigger_deadzone = math.clamp(fraction, 0, 0.5)
end

--- @brief
function rt.GameState:get_trigger_deadzone()
    return bd.get_config().trigger_deadzone
end

--- @brief
function rt.GameState:set_player_sprint_mode(mode)
    meta.assert_enum_value(mode, rt.PlayerSprintMode, 1)
    bd.get_config().player_sprint_mode = mode
end

--- @brief
function rt.GameState:get_player_sprint_mode()
    return bd.get_config().player_sprint_mode
end

--- @brief
function rt.GameState:get_double_press_threshold()
    return math.mix(
        rt.settings.game_state.min_double_click_threshold,
        rt.settings.game_state.max_double_click_threshold,
        bd.get_config().double_press_threshold
    )
end

--- @brief
--- @param t Number fraction, in 0, 1
function rt.GameState:set_double_press_threshold(t)
    meta.assert(t, "Number")
    bd.get_config().double_press_threshold = t
end

--- @brief
function rt.GameState:get_is_input_buffering_enabled()
    return bd.get_config().is_input_buffering_enabled
end

--- @brief
function rt.GameState:set_is_input_buffering_enabled(is_enabled)
    meta.assert(is_enabled, "Boolean")
    bd.get_config().is_input_buffering_enabled = is_enabled
end

--- @brief
function rt.GameState:set_is_color_blind_mode_enabled(enabled)
    meta.assert(enabled, "Boolean")
    bd.get_config().is_color_blind_mode_enabled = enabled
end

--- @brief
function rt.GameState:get_is_color_blind_mode_enabled()
    return bd.get_config().is_color_blind_mode_enabled
end

--- @brief
function rt.GameState:set_is_screen_shake_enabled(b)
    bd.get_config().is_screen_shake_enabled = b
end

--- @brief
function rt.GameState:get_is_screen_shake_enabled()
    return bd.get_config().is_screen_shake_enabled
end

--- @brief
function rt.GameState:set_controller_vibration_strength(t)
    meta.assert(t, "Number")
    t = math.clamp(t, 0, 1)
    bd.get_config().controller_vibration_strength = t
end

--- @brief
function rt.GameState:get_controller_vibration_strength()
    return bd.get_config().controller_vibration_strength
end

--- @brief
function rt.GameState:get_is_performance_mode_enabled()
    return bd.get_config().performance_mode_enabled
end

--- @brief
function rt.GameState:set_is_performance_mode_enabled(b)
    meta.assert(b, "Boolean")
    bd.get_config().performance_mode_enabled = b
end

--- @brief
function rt.GameState:set_draw_debug_information(b)
    meta.assert(b, "Boolean")
    bd.get_config().draw_debug_information = b
end

--- @brief
function rt.GameState:get_draw_debug_information()
    return bd.get_config().draw_debug_information
end

--- @brief
function rt.GameState:set_draw_speedrun_splits(b)
    meta.assert(b, "Boolean")
    bd.get_config().draw_speedrun_splits = b
end

--- @brief
function rt.GameState:get_draw_speedrun_splits()
    return bd.get_config().draw_speedrun_splits
end

--- @brief
function rt.GameState:load_default_input_mapping()
    self._input_action_to_keyboard_key, self._input_action_to_controller_button = bd.get_default_keybinding()
    local valid, error = self:_validate_input_mapping()

    if valid then
        self:_update_reverse_mapping()
    else
        rt.error("In rt.GameState.validate_input_mapping: ", error)
    end
end

--- @brief
function rt.GameState:_validate_input_mapping()
    local unassigned_keyboard = {}
    local unassigned_keyboard_active = false

    local unassigned_controller = {}
    local unassigned_controller_active = false

    local native_keyboard_to_action = {}
    local double_assigned_keyboard = {}
    local double_assigned_keyboard_active = false

    local native_controller_to_action = {}
    local double_assigned_controller = {}
    local double_assigned_controller_active = false

    local unused_actions = {}

    local input_actions = {} -- Set
    for action in values(meta.instances(rt.InputAction)) do
        input_actions[action] = true
    end

    -- verify that all actions have an assignment
    for action in keys(input_actions) do
        local keyboard_entry = self._input_action_to_keyboard_key[action]
        local keyboard_unused = false
        local keyboard

        if keyboard_entry == nil then
            keyboard_unused = false
        else
            if #keyboard_entry == 0 then
                table.insert(unassigned_keyboard, action)
                unassigned_keyboard_active = true
            end

            for key in values(keyboard_entry) do
                local entry = native_keyboard_to_action[key]
                if entry == nil then
                    entry = {}
                    native_keyboard_to_action[key] = entry
                end

                entry[action] = true -- set, since enum has aliases
            end
        end

        local controller_entry = self._input_action_to_controller_button[action]
        local controller_unused = false
        local controller

        if controller_entry == nil then
            controller_unused = true
        else
            if #controller_entry == 0 then
                table.insert(unassigned_controller, action)
                unassigned_controller_active = true
            end

            for button in values(controller_entry) do
                local entry = native_controller_to_action[button]
                if entry == nil then
                    entry = {}
                    native_controller_to_action[button] = entry
                end

                entry[action] = true
            end
        end
    end

    local valid = not unassigned_keyboard_active and not unassigned_controller_active

    if not valid then
        local translation = rt.Translation.game_state.validate_keybinding_error
        local indent = "\t"
        local input_action_to_string = rt.Translation.input_action_to_string

        local error = {}

        if unassigned_keyboard_active then
            table.insert(error, translation.unassigned_keyboard_message)
            local line = { indent }
            for i, action in ipairs(unassigned_keyboard) do
                table.insert(line, input_action_to_string(action))
                if i ~= #unassigned_keyboard then
                    table.insert(line, ", ")
                end
            end
            table.insert(error, table.concat(line, ""))
        end

        if unassigned_controller_active then
            table.insert(error, translation.unassigned_controller_message)
            local line = { indent }
            for i, action in ipairs(unassigned_controller) do
                table.insert(line, input_action_to_string(action))
                if i ~= #unassigned_controller then
                    table.insert(line, ", ")
                end
            end
            table.insert(error, table.concat(line, ""))
        end

        return false, table.concat(error, "\n")
    else
        return valid, nil
    end
end

--- @brief
function rt.GameState:_update_reverse_mapping()
    self._keyboard_key_to_input_action = {}
    self._controller_button_to_input_action = {}

    local input_actions = {}
    for action in values(meta.instances(rt.InputAction)) do input_actions[action] = true end

    for action in keys(input_actions) do
        local keyboard_mapping = self._input_action_to_keyboard_key[action]
        local controller_mapping = self._input_action_to_controller_button[action]
        assert(keyboard_mapping ~= nil and controller_mapping ~= nil)

        for key in values(keyboard_mapping) do
            local actions = self._keyboard_key_to_input_action[key]
            if actions == nil then
                actions = {}
                self._keyboard_key_to_input_action[key] = actions
            end
            table.insert(actions, action)
        end

        for button in values(controller_mapping) do
            local actions = self._controller_button_to_input_action[button]
            if actions == nil then
                actions = {}
                self._controller_button_to_input_action[button] = actions
            end
            table.insert(actions, action)
        end
    end
end

--- @brief
function rt.GameState:get_input_mapping(input_action, method)
    meta.assert_enum_value(input_action, rt.InputAction, 1)
    local keyboard_entry = self._input_action_to_keyboard_key[input_action]
    local controller_entry = self._input_action_to_controller_button[input_action]

    if method == rt.InputMethod.KEYBOARD then
        if keyboard_entry == nil then
            return {}
        else
            return table.deepcopy(keyboard_entry)
        end
    elseif method == rt.InputMethod.CONTROLLER then
        if controller_entry == nil then
            return {}
        else
            return table.deepcopy(controller_entry)
        end
    elseif method == nil then
        local keyboard, controller = {}, {}
        if keyboard_entry ~= nil then
            keyboard = table.deepcopy(keyboard_entry)
        end

        if controller_entry ~= nil then
            controller = table.deepcopy(controller_entry)
        end

        return keyboard, controller
    else
        meta.assert_enum_value(method, rt.InputMethod, 2) -- always throws
    end
end

--- @brief
function rt.GameState:get_has_input_mapping(input_action, method)
    local keyboard_entry = self._input_action_to_keyboard_key[input_action]
    local controller_entry = self._input_action_to_controller_button[input_action]

    if method == rt.InputMethod.KEYBOARD then
        return keyboard_entry ~= nil
    elseif method == rt.InputMethod.CONTROLLER then
        return controller_entry ~= nil
    elseif method == nil then
        return keyboard_entry ~= nil, controller_entry ~= nil
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
    else
        return self._keyboard_key_to_input_action[native], self._controller_button_to_input_action[native]
    end
end

--- @brief
--- @param ... Union<rt.KeyboardKey, rt.ControllerButton>
function rt.GameState:set_input_mapping(input_action_to_keyboard_key, input_action_to_controller_button)
    meta.assert(
        input_action_to_keyboard_key, "Table",
        input_action_to_controller_button, "Table"
    )

    local keyboard_before = table.deepcopy(self._input_action_to_keyboard_key)
    local controller_before = table.deepcopy(self._input_action_to_controller_button)

    for action, entry in pairs(input_action_to_keyboard_key) do
        meta.assert_enum_value(action, rt.InputAction)
        for key in values(entry) do
            meta.assert_enum_value(key, rt.KeyboardKey)
        end
    end

    for action, entry in pairs(input_action_to_controller_button) do
        meta.assert_enum_value(action, rt.InputAction)
        for button in values(entry) do
            meta.assert_enum_value(button, rt.ControllerButton)
        end
    end

    self._input_action_to_keyboard_key = input_action_to_keyboard_key
    self._input_action_to_controller_button = input_action_to_controller_button

    local valid, error = self:_validate_input_mapping()
    if not valid then
        -- restore backup
        self._input_action_to_keyboard_key = keyboard_before
        self._input_action_to_controller_button = controller_before
        return false, error
    else
        self:_update_reverse_mapping()
        return true
    end
end

--- @brief
function rt.GameState:get_player()
    return self._player
end

require "common.game_state_stage"

rt.GameState = rt.GameState()
rt.GameState._player = rt.Player()
