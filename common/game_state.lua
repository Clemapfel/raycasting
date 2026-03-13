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
        input_mapping = {}, -- Table<rt.InputAction, { keyboard = rt.KeyboardKey, controller = rt.ControllerButton }>
        axis_mapping = {},

        -- stage results
        stage_results = {}, --[[ Table<StageID, {
            was_cleared,
            best_time,
            best_flow_percentage,
            collected_coins
        }]]--
    }

    self._keyboard_key_to_input_action = {}
    self._controller_button_to_input_action = {}
    self:load_default_input_mapping()
end

--- @brief
function rt.GameState:update(delta)
    self:_update_save_worker()
end


--- @brief
function rt.GameState:set_vsync_mode(mode)
    meta.assert_enum_value(mode, rt.VSyncMode, 1)
    bd.get_config().vsync = mode
    love.window.setVSync(mode)
end

--- @brief
function rt.GameState:get_vsync_mode(mode)
    return love.window.getVSync()
end

--- @brief
function rt.GameState:set_msaa_quality(msaa)
    meta.assert_enum_value(msaa, rt.MSAAQuality, 1)
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
function rt.GameState:get_is_input_buffering_enabled()
    return bd.get_config().input_buffering_enabled
end

--- @brief
function rt.GameState:set_is_input_buffering_enabled(is_enabled)
    meta.assert(is_enabled, "Boolean")
    bd.get_config().input_buffering_enabled = is_enabled
end

--- @brief
function rt.GameState:set_is_color_blind_mode_enabled(enabled)
    meta.assert(enabled, "Boolean")
    bd.get_config().color_blind_mode_enabled = enabled
end

--- @brief
function rt.GameState:get_is_color_blind_mode_enabled()
    return bd.get_config().color_blind_mode_enabled
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
function rt.GameState:load_default_input_mapping()
    self._state.input_mapping =
    {
        [rt.InputAction.UP] = {
            keyboard = {"up", "w"},
            controller = rt.ControllerButton.DPAD_UP
        },

        [rt.InputAction.DOWN] = {
            keyboard = {"down", "s"},
            controller = rt.ControllerButton.DPAD_DOWN
        },

        [rt.InputAction.LEFT] = {
            keyboard = {"left", "a"},
            controller = rt.ControllerButton.DPAD_LEFT
        },

        [rt.InputAction.RIGHT] = {
            keyboard = {"right", "d"},
            controller = rt.ControllerButton.DPAD_RIGHT
        },

        [rt.InputAction.B] = { -- sprint / back
            keyboard = {"n"},
            controller = rt.ControllerButton.LEFT
        },

        [rt.InputAction.A] = { -- jump / confirm
            keyboard = {"space"},
            controller = rt.ControllerButton.BOTTOM
        },

        [rt.InputAction.X] = { -- interact / reset
            keyboard = {"x", "m"},
            controller = rt.ControllerButton.TOP
        },

        [rt.InputAction.Y] = { -- unused
            keyboard = {"y"},
            controller = rt.ControllerButton.RIGHT
        },

        [rt.InputAction.L] = {
            keyboard = {"l"},
            controller = rt.ControllerButton.LEFT_SHOULDER
        },

        [rt.InputAction.R] = {
            keyboard = {"k", "r"},
            controller = rt.ControllerButton.RIGHT_SHOULDER
        },

        [rt.InputAction.START] = {
            keyboard = {"escape"},
            controller = rt.ControllerButton.START
        },

        --[[
        [rt.InputAction.SELECT] = { -- unused
            keyboard = {"#"},
            controller = rt.ControllerButton.SELECT
        }
        ]]
    }

    for mapping in values(self._state.input_mapping) do
        if not meta.is_table(mapping.keyboard) then mapping.keyboard = { mapping.keyboard } end
        if not meta.is_table(mapping.controller) then mapping.controller = { mapping.controller } end
    end

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
        local keyboard_entry = self._state.input_mapping[action]
        local keyboard_unused = false
        local keyboard

        if keyboard_entry == nil then
            keyboard_unused = false
        else
            local keyboard = keyboard_entry.keyboard
            if #keyboard == 0 then
                table.insert(unassigned_keyboard, action)
                unassigned_keyboard_active = true
            end

            for key in values(keyboard) do
                local entry = native_keyboard_to_action[key]
                if entry == nil then
                    entry = {}
                    native_keyboard_to_action[key] = entry
                end

                entry[action] = true -- set, since enum has aliases
            end
        end

        local controller_entry = self._state.input_mapping[action]
        local controller_unused = false
        local controller

        if controller_entry == nil then
            controller_unused = true
        else
            local controller = controller_entry.controller
            if #controller == 0 then
                table.insert(unassigned_controller, action)
                unassigned_controller_active = true
            end

            for button in values(controller) do
                local entry = native_controller_to_action[button]
                if entry == nil then
                    entry = {}
                    native_controller_to_action[button] = entry
                end

                entry[action] = true
            end
        end
    end

    -- verify that no button does two actions
    for key, actions in pairs(native_keyboard_to_action) do
        if table.sizeof(actions) > 1 then
            local flat = {}
            for action in keys(actions) do table.insert(flat, action) end

            double_assigned_keyboard[key] = flat
            double_assigned_keyboard_active = true
        end
    end

    for button, actions in pairs(native_controller_to_action) do
        if table.sizeof(actions) > 1 then
            local flat = {}
            for action in keys(actions) do table.insert(flat, action) end

            double_assigned_controller[button] = flat
            double_assigned_controller_active = true
        end
    end

    local valid = not unassigned_keyboard_active and
        not unassigned_controller_active and
        not double_assigned_keyboard_active and
        not double_assigned_controller_active

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

        if double_assigned_keyboard_active then
            table.insert(error, translation.double_assigned_keyboard_message)
            for key, actions in pairs(double_assigned_keyboard) do
                local line = { indent .. "<b>" .. rt.Translation.keyboard_key_to_string(key) .. "</b>: " }
                for i, action in ipairs(actions) do
                    table.insert(line, input_action_to_string(action))
                    if i ~= #actions then
                        table.insert(line, ", ")
                    end
                end
                table.insert(error, table.concat(line, ""))
            end
        end

        if double_assigned_controller_active then
            table.insert(error, translation.double_assigned_controller_message)
            for button, actions in pairs(double_assigned_controller) do
                local line = { indent .. rt.Translation.controller_button_to_string(button) .. ": "}
                for i, action in ipairs(actions) do
                    table.insert(line, input_action_to_string(action))
                    if i ~= #actions then
                        table.insert(line, ", ")
                    end
                end
                table.insert(error, table.concat(line, ""))
            end
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
        local mapping = self._state.input_mapping[action]

        if mapping ~= nil then
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
                table.insert(actions, action)
            end
        end
    end
end

--- @brief
function rt.GameState:get_input_mapping(input_action, method)
    meta.assert_enum_value(input_action, rt.InputAction, 1)
    local keyboard_entry = self._state.input_mapping[input_action]
    local controller_entry = self._state.input_mapping[input_action]
    if method == rt.InputMethod.KEYBOARD then
        if keyboard_entry == nil then
            return {}
        else
            return table.deepcopy(keyboard_entry.keyboard)
        end
    elseif method == rt.InputMethod.CONTROLLER then
        if controller_entry == nil then
            return {}
        else
            return table.deepcopy(controller_entry.controller)
        end
    elseif method == nil then
        local keyboard, controller = {}, {}
        if keyboard_entry ~= nil then
            keyboard = table.deepcopy(keyboard_entry.keyboard)
        end

        if controller_entry ~= nil then
            controller = table.deepcopy(controller_entry.controller)
        end

        return keyboard, controller
    else
        meta.assert_enum_value(method, rt.InputMethod, 2) -- always throws
    end
end

--- @brief
function rt.GameState:get_has_input_mapping(input_action, method)
    local keyboard_entry = self._state.input_mapping[input_action]
    local controller_entry = self._state.input_mapping[input_action]

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
function rt.GameState:get_double_press_threshold()
    return math.mix(
        rt.settings.game_state.min_double_click_threshold,
        rt.settings.game_state.max_double_click_threshold,
        self._state.double_press_threshold
    )
end

--- @brief
--- @param t Number fraction, in 0, 1
function rt.GameState:set_double_press_threshold(t)
    meta.assert(t, "Number")
    self._state.double_press_threshold = t
end

--- @brief
--- @param ... Union<rt.KeyboardKey, rt.ControllerButton>
function rt.GameState:set_input_mapping(input_action_to_keyboard_controller)
    meta.assert(input_action_to_keyboard_controller, "Table")

    local before = table.deepcopy(self._state.input_mapping)

    for action, entry in pairs(input_action_to_keyboard_controller) do
        meta.assert_enum_value(action, rt.InputAction)
        rt.assert(entry.keyboard ~= nil or entry.controller ~= nil, "In rt.GameState.set_input_mapping: new mapping for action `", action, "` does not have `keyboard` or `controller` entry")

        if entry.keyboard ~= nil then
            meta.assert_typeof(entry.keyboard, "String")
            self._state.input_mapping[action].keyboard[1] = entry.keyboard
        end
        if entry.controller ~= nil then
            meta.assert_typeof(entry.controller, "String")
            self._state.input_mapping[action].controller[1] = entry.controller
        end
    end

    local valid, error = self:_validate_input_mapping()
    if not valid then
        self._state.input_mapping = before -- restore backup
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
require "common.game_state_save"
require "common.game_state_log"

rt.GameState = rt.GameState()
rt.GameState._player = rt.Player()
