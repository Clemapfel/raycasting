require "common.scene"
require "common.input_subscriber"
require "common.frame"
require "common.game_state"
require "common.control_indicator"
require "common.lch_texture"
require "menu.verbose_info_panel"
require "menu.scale"
require "menu.option_button"
require "menu.scrollable_list"

local SettingsItem = {
    MUSIC_LEVEL = "music_level",
    SOUND_EFFECT_LEVEL = "sound_effect_level",

    CONTROLLER_VIBRATION = "controller_vibration",
    SCREEN_SHAKE = "screen_shake",
    COLOR_BLIND_MODE = "color_blind_mode",
    TEXT_SPEED = "text_speed",

    FULLSCREEN = "fullscreen",
    VSYNC = "vsync",
    MSAA = "msaa",
    BLOOM = "bloom",
    HDR = "hdr",
    DYNAMIC_LIGHTING = "dynamic_lighting",
    REFLECTIONS = "reflections",
    BACKGROUND_ANIMATION = "background_animation",

    JOYSTICK_DEADZONE = "joystick_deadzone",
    SPRINT_MODE = "sprint_mode",
    DOUBLE_PRESS_THRESHOLD = "double_press_threshold",
    INPUT_BUFFERING = "input_buffering",

    SPEEDRUN_SPLITS = "speedrun_splits",
    DEBUG_PRINT = "debug_print",
}

rt.settings.settings_scene = {
    scale_movement_ticks_per_second = 100,
    scale_movement_delay = 20 / 60,

    scroll_ticks_per_second = 4,
    scroll_delay = 20 / 60,

    verbose_info_width_fraction = 1 / 3,
    scrollbar_width_factor = 1.5, -- times margin

    item_order = {
        SettingsItem.MUSIC_LEVEL,
        SettingsItem.SOUND_EFFECT_LEVEL,
        SettingsItem.VSYNC,
        SettingsItem.FULLSCREEN,

        SettingsItem.CONTROLLER_VIBRATION,
        SettingsItem.SCREEN_SHAKE,
        SettingsItem.COLOR_BLIND_MODE,
        SettingsItem.TEXT_SPEED,

        SettingsItem.JOYSTICK_DEADZONE,
        SettingsItem.SPRINT_MODE,
        --SettingsItem.DOUBLE_PRESS_THRESHOLD,
        SettingsItem.INPUT_BUFFERING,

        SettingsItem.MSAA,
        SettingsItem.DYNAMIC_LIGHTING,
        SettingsItem.BLOOM,
        SettingsItem.HDR,
        SettingsItem.REFLECTIONS,
        SettingsItem.BACKGROUND_ANIMATION,

        SettingsItem.SPEEDRUN_SPLITS,
        SettingsItem.DEBUG_PRINT
    }
}

--- @class mn.SettingsScene
mn.SettingsScene = meta.class("MenuSettingsScene", rt.Scene)

--- @class mn.SettingsScene.Item
mn.SettingsScene.Item = meta.class("SettingsSceneItem", rt.Widget)
meta.add_signal(mn.SettingsScene.Item, "reset")

--- @brief [internal]
function mn.SettingsScene.Item:instantiate(t)
    meta.install(self, t)
end

--- @brief [internal]
function mn.SettingsScene.Item:realize()
    self.prefix:realize()
    self.widget:realize()
end

--- @brief [internal]
function mn.SettingsScene.Item:draw()
    self.prefix:draw()
    self.widget:draw()
end

function mn.SettingsScene.Item:measure()
    local w, h = self.prefix:measure()
    return w, h
end

local _shader = rt.Shader("menu/settings_scene_background.glsl", { MODE = 0 })
local _lch_texture = rt.LCHTexture(1, 1, 512)

--- @brief
function mn.SettingsScene:instantiate()
    self._background_only = false
    local translation = rt.Translation.settings_scene

    self._option_button_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_select,
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move,
        rt.ControlIndicatorButton.RESET, translation.control_indicator_restore_default,
        rt.ControlIndicatorButton.BACK, translation.control_indicator_back
    )

    self._scale_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_select,
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move,
        rt.ControlIndicatorButton.RESET, translation.control_indicator_restore_default,
        rt.ControlIndicatorButton.BACK, translation.control_indicator_back
    )

    self._verbose_info = mn.VerboseInfoPanel()
    self._item_stencil = rt.AABB()

    self._heading_label = rt.Label("<b><o>" .. translation.heading .. "</o></b>")
    self._heading_label_frame = rt.Frame()

    self._list = mn.ScrollableList()

    local prefix_prefix = "<b>"
    local prefix_postfix = "</b>"

    local function reverse(t)
        local out = {}
        for key, value in pairs(t) do
            out[value] = key
        end
        return out
    end

    local function extract_keys(t)
        local out = {}
        for key in keys(t) do
            table.insert(out, key)
        end
        return out
    end

    local function add_item(prefix, widget, ...)
        local item = mn.SettingsScene.Item({
            prefix = rt.Label(prefix_prefix .. prefix .. prefix_postfix),
            widget = widget,
            info = { ... },
            is_scale = meta.isa(widget, mn.Scale)
        })

        item.set_selection_state = function(_, state)
            if state == rt.SelectionState.ACTIVE then
                self._verbose_info:show(item.info)
            end
        end

        self._list:add_item(item)
        return item
    end

    local new_scale = function(default_value)
        return mn.Scale(0, 1, 100, default_value)
    end

    require "build.config"
    local defaults = bd.get_default_config()

    local init_functions = {}

    init_functions[SettingsItem.VSYNC] = function()
        local vsync_to_label = {
            [rt.VSyncMode.ADAPTIVE] = translation.vsync_adaptive,
            [rt.VSyncMode.OFF] = translation.vsync_off,
            [rt.VSyncMode.ON] = translation.vsync_on
        }
        local label_to_vsync = reverse(vsync_to_label)

        local vsync_button = mn.OptionButton({
            vsync_to_label[rt.VSyncMode.ADAPTIVE],
            vsync_to_label[rt.VSyncMode.OFF],
            vsync_to_label[rt.VSyncMode.ON]
        })
        vsync_button:set_option(vsync_to_label[rt.GameState:get_vsync_mode()])
        vsync_button:signal_connect("selection", function(_, label)
            rt.GameState:set_vsync_mode(label_to_vsync[label])
        end)

        local item = add_item(
            translation.vsync_prefix, vsync_button,
            mn.VerboseInfoObject.VSYNC,
            mn.VerboseInfoObject.SHOW_FPS_WIDGET
        )

        item:signal_connect("reset", function(_)
            vsync_button:set_option(vsync_to_label[defaults.vsync])
        end)
    end

    init_functions[SettingsItem.FULLSCREEN] = function() -- fullscreen
        local fullscreen_to_label = {
            [true] = translation.fullscreen_on,
            [false] = translation.fullscreen_off
        }
        local label_to_fullscreen = reverse(fullscreen_to_label)

        local fullscreen_button = mn.OptionButton({
            fullscreen_to_label[false],
            fullscreen_to_label[true]
        })
        fullscreen_button:set_option(fullscreen_to_label[rt.GameState:get_is_fullscreen()])
        fullscreen_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_fullscreen(label_to_fullscreen[label])
        end)

        local item = add_item(
            translation.fullscreen_prefix, fullscreen_button,
            mn.VerboseInfoObject.FULLSCREEN
        )

        item:signal_connect("reset", function(_)
            fullscreen_button:set_option(fullscreen_to_label[defaults.is_fullscreen])
        end)
    end

    init_functions[SettingsItem.MUSIC_LEVEL] = function() -- music
        local music_level_scale = new_scale(rt.GameState:get_music_level())
        music_level_scale:signal_connect("value_changed", function(_, value)
            rt.GameState:set_music_level(value)
        end)

        local item = add_item(
            translation.music_level_prefix, music_level_scale,
            mn.VerboseInfoObject.MUSIC_LEVEL,
            mn.VerboseInfoObject.MUSIC_LEVEL_WIDGET

        )

        item:signal_connect("reset", function(_)
            music_level_scale:set_value(defaults.music_level)
        end)
    end

    init_functions[SettingsItem.SOUND_EFFECT_LEVEL] = function() -- sound effect
        local sound_effect_level_scale = new_scale(rt.GameState:get_sound_effect_level())
        sound_effect_level_scale:signal_connect("value_changed", function(_, value)
            rt.GameState:set_sound_effect_level(value)
        end)

        local item = add_item(
            translation.sound_effect_level_prefix, sound_effect_level_scale,
            mn.VerboseInfoObject.SOUND_EFFECT_LEVEL,
            mn.VerboseInfoObject.SOUND_EFFECT_LEVEL_WIDGET
        )

        item:signal_connect("reset", function(_)
            sound_effect_level_scale:set_value(defaults.sound_effect_level)
        end)
    end

    init_functions[SettingsItem.MSAA] = function() -- msaa
        local msaa_to_label = {
            [rt.MSAAQuality.OFF] = translation.msaa_off,
            [rt.MSAAQuality.GOOD] = translation.msaa_good,
            [rt.MSAAQuality.BETTER] = translation.msaa_better,
            [rt.MSAAQuality.BEST] = translation.msaa_best,
        }
        local label_to_msaa = reverse(msaa_to_label)

        local msaa_button = mn.OptionButton({
            msaa_to_label[rt.MSAAQuality.OFF],
            msaa_to_label[rt.MSAAQuality.GOOD],
            msaa_to_label[rt.MSAAQuality.BETTER],
            msaa_to_label[rt.MSAAQuality.BEST]
        })

        msaa_button:set_option(msaa_to_label[rt.GameState:get_msaa_quality()])
        msaa_button:signal_connect("selection", function(_, label)
            rt.GameState:set_msaa_quality(label_to_msaa[label])
        end)

        local item = add_item(
            translation.msaa_prefix, msaa_button,
            mn.VerboseInfoObject.MSAA,
            mn.VerboseInfoObject.SHOW_FPS_WIDGET,
            mn.VerboseInfoObject.MSAA_WIDGET
        )
        item:signal_connect("reset", function(_)
            msaa_button:set_option(msaa_to_label[defaults.msaa])
        end)
    end

    init_functions[SettingsItem.BLOOM] = function() -- bloom
        local bloom_to_label = {
            [true] = translation.bloom_on,
            [false] = translation.bloom_off
        }
        local label_to_bloom = reverse(bloom_to_label)

        local bloom_button = mn.OptionButton({
            bloom_to_label[false],
            bloom_to_label[true],
        })

        bloom_button:set_option(bloom_to_label[rt.GameState:get_is_bloom_enabled()])
        bloom_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_bloom_enabled(label_to_bloom[label])
        end)

        local item = add_item(
            translation.bloom_prefix, bloom_button,
            mn.VerboseInfoObject.BLOOM
        )

        item:signal_connect("reset", function(_)
            bloom_button:set_option(bloom_to_label[defaults.is_bloom_enabled])
        end)
    end

    init_functions[SettingsItem.HDR] = function() -- hdr
        local hdr_to_label = {
            [false] = translation.hdr_off,
            [true] = translation.hdr_on
        }
        local label_to_hdr = reverse(hdr_to_label)

        local hdr_button = mn.OptionButton({
            hdr_to_label[false],
            hdr_to_label[true],
        })

        hdr_button:set_option(hdr_to_label[rt.GameState:get_is_hdr_enabled()])
        hdr_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_hdr_enabled(label_to_hdr[label])
        end)

        local item = add_item(
            translation.hdr_prefix, hdr_button,
            mn.VerboseInfoObject.HDR,
            mn.VerboseInfoObject.SHOW_FPS_WIDGET
        )

        item:signal_connect("reset", function(_)
            hdr_button:set_option(hdr_to_label[defaults.is_hdr_enabled])
        end)
    end

    init_functions[SettingsItem.DYNAMIC_LIGHTING] = function() -- dynamic lighting
        local dynamic_lighting_to_label = {
            [false] = translation.dynamic_lighting_off,
            [true] = translation.dynamic_lighting_on
        }
        local label_to_dynamic_lighting = reverse(dynamic_lighting_to_label)

        local dynamic_lighting_button = mn.OptionButton({
            dynamic_lighting_to_label[false],
            dynamic_lighting_to_label[true],
        })

        dynamic_lighting_button:set_option(dynamic_lighting_to_label[rt.GameState:get_is_dynamic_lighting_enabled()])
        dynamic_lighting_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_dynamic_lighting_enabled(label_to_dynamic_lighting[label])
        end)

        local item = add_item(
            translation.dynamic_lighting_prefix, dynamic_lighting_button,
            mn.VerboseInfoObject.DYNAMIC_LIGHTING
        )

        item:signal_connect("reset", function(_)
            dynamic_lighting_button:set_option(dynamic_lighting_to_label[defaults.is_dynamic_lighting_enabled])
        end)
    end

    init_functions[SettingsItem.REFLECTIONS] = function() -- reflections
        local reflections_to_label = {
            [false] = translation.reflections_off,
            [true] = translation.reflections_on
        }
        local label_to_reflections = reverse(reflections_to_label)

        local reflections_button = mn.OptionButton({
            reflections_to_label[false],
            reflections_to_label[true],
        })

        reflections_button:set_option(reflections_to_label[rt.GameState:get_are_reflections_enabled()])
        reflections_button:signal_connect("selection", function(_, label)
            rt.GameState:set_are_reflections_enabled(label_to_reflections[label])
        end)

        local item = add_item(
            translation.reflections_prefix, reflections_button,
            mn.VerboseInfoObject.REFLECTIONS
        )

        item:signal_connect("reset", function(_)
            reflections_button:set_option(reflections_to_label[defaults.are_reflections_enabled])
        end)
    end

    init_functions[SettingsItem.BACKGROUND_ANIMATION] = function() -- background animation
        local background_animated_to_label = {
            [false] = translation.background_animation_off,
            [true] = translation.background_animation_on
        }
        local label_to_background_animated = reverse(background_animated_to_label)

        local background_animated_button = mn.OptionButton({
            background_animated_to_label[false],
            background_animated_to_label[true],
        })

        background_animated_button:set_option(background_animated_to_label[rt.GameState:get_is_background_animated()])
        background_animated_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_background_animated(label_to_background_animated[label])
        end)

        local item = add_item(
            translation.background_animation_prefix, background_animated_button,
            mn.VerboseInfoObject.BACKGROUND_ANIMATION
        )

        item:signal_connect("reset", function(_)
            background_animated_button:set_option(background_animated_to_label[defaults.is_background_animated])
        end)
    end

    init_functions[SettingsItem.JOYSTICK_DEADZONE] = function() -- dead zone
        local deadzone_scale = new_scale(rt.GameState:get_joystick_deadzone())
        deadzone_scale:signal_connect("value_changed", function(_, value)
            rt.GameState:set_joystick_deadzone(value)
        end)

        local item = add_item(
            translation.joystick_deadzone_prefix, deadzone_scale,
            mn.VerboseInfoObject.JOYSTICK_DEADZONE,
            mn.VerboseInfoObject.JOYSTICK_DEADZONE_WIDGET
        )

        item:signal_connect("reset", function(_)
            deadzone_scale:set_value(defaults.joystick_deadzone)
        end)
    end

    init_functions[SettingsItem.TEXT_SPEED] = function() -- text speed
        local text_speed_scale = new_scale(rt.GameState:get_text_speed())
        text_speed_scale:signal_connect("value_changed", function(_, value)
            rt.GameState:set_text_speed(value)
        end)

        local item = add_item(
            translation.text_speed_prefix, text_speed_scale,
            mn.VerboseInfoObject.TEXT_SPEED,
            mn.VerboseInfoObject.TEXT_SPEED_WIDGET
        )

        item:signal_connect("reset", function(_)
            text_speed_scale:set_value(defaults.text_speed)
        end)
    end

    init_functions[SettingsItem.DOUBLE_PRESS_THRESHOLD] = function() -- double press threshold
        local double_press_threshold_scale = new_scale(rt.GameState:get_double_press_threshold())
        double_press_threshold_scale:signal_connect("value_changed", function(_, value)
            rt.GameState:set_double_press_threshold(value)
        end)

        local item = add_item(
            translation.double_press_threshold_prefix, double_press_threshold_scale,
            mn.VerboseInfoObject.DOUBLE_PRESS_THRESHOLD
        )

        item:signal_connect("reset", function(_)
            double_press_threshold_scale:set_value(rt.settings.settings_scene.double_press_threshold_default)
        end)
    end

    init_functions[SettingsItem.SCREEN_SHAKE] = function() -- shake
        local shake_to_label = {
            [false] = translation.shake_off,
            [true] = translation.shake_on
        }

        local label_to_shake = reverse(shake_to_label)

        local shake_button = mn.OptionButton({
            shake_to_label[false],
            shake_to_label[true]
        })

        shake_button:set_option(shake_to_label[rt.GameState:get_is_screen_shake_enabled()])
        shake_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_screen_shake_enabled(label_to_shake[label])
        end)

        local item = add_item(
            translation.shake_prefix, shake_button,
            mn.VerboseInfoObject.SHAKE_ENABLED
        )

        item:signal_connect("reset", function(_)
            shake_button:set_option(shake_to_label[defaults.is_screen_shake_enabled])
        end)
    end

    init_functions[SettingsItem.CONTROLLER_VIBRATION] = function() -- controller vibration
        local controller_vibration_scale = new_scale(rt.GameState:get_controller_vibration_strength())
        controller_vibration_scale:signal_connect("value_changed", function(_, value, is_during_realize)
            if is_during_realize then return end
            rt.GameState:set_controller_vibration_strength(value)
            self._input:vibrate(1, 1, 10 / 60)
        end)

        local item = add_item(
            translation.controller_vibration_strength_prefix, controller_vibration_scale,
            mn.VerboseInfoObject.CONTROLLER_VIBRATION_STRENGTH
        )

        item:signal_connect("reset", function(_)
            controller_vibration_scale:set_value(defaults.controller_vibration_strength)
            if self._input:get_input_method() == rt.InputMethod.CONTROLLER then
                self._input:vibrate(1, 1)
            end
        end)
    end

    init_functions[SettingsItem.COLOR_BLIND_MODE] = function() -- color blind mode
        local color_blind_mode_to_label ={
            [true] = translation.color_blind_mode_on,
            [false] = translation.color_blind_mode_off
        }
        local label_to_color_blind_mode = reverse(color_blind_mode_to_label)

        local color_blind_mode_button = mn.OptionButton({
            color_blind_mode_to_label[false],
            color_blind_mode_to_label[true]
        })

        color_blind_mode_button:set_option(color_blind_mode_to_label[rt.GameState:get_is_color_blind_mode_enabled()])
        color_blind_mode_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_color_blind_mode_enabled(label_to_color_blind_mode[label])
        end)

        local item = add_item(
            translation.color_blind_mode_prefix, color_blind_mode_button,
            mn.VerboseInfoObject.COLOR_BLIND_MODE_ENABLED
        )

        item:signal_connect("reset", function(_)
            color_blind_mode_button:set_option(color_blind_mode_to_label[defaults.is_color_blind_mode_enabled])
        end)
    end

    init_functions[SettingsItem.SPRINT_MODE] = function() -- sprint mode
        local sprint_mode_to_label = {
            [rt.PlayerSprintMode.HOLD_TO_SPRINT] = translation.sprint_mode_hold_to_sprint,
            [rt.PlayerSprintMode.HOLD_TO_WALK] = translation.sprint_mode_hold_to_walk
        }
        local label_to_sprint_mode = reverse(sprint_mode_to_label)

        local sprint_mode_button = mn.OptionButton({
            sprint_mode_to_label[rt.PlayerSprintMode.HOLD_TO_SPRINT],
            sprint_mode_to_label[rt.PlayerSprintMode.HOLD_TO_WALK]
        })

        sprint_mode_button:set_option(sprint_mode_to_label[rt.GameState:get_player_sprint_mode()])
        sprint_mode_button:signal_connect("selection", function(_, label)
            rt.GameState:set_player_sprint_mode(label_to_sprint_mode[label])
        end)

        local item = add_item(
            translation.sprint_mode_prefix, sprint_mode_button,
            mn.VerboseInfoObject.SPRINT_MODE
        )

        item:signal_connect("reset", function(_)
            sprint_mode_button:set_option(sprint_mode_to_label[defaults.player_sprint_mode])
        end)
    end

    init_functions[SettingsItem.INPUT_BUFFERING] = function() -- input buffering
        local input_buffering_enabled_to_label = {
            [true] = translation.input_buffering_enabled_on,
            [false] = translation.input_buffering_enabled_off,
        }
        local label_to_input_buffering_enabled = reverse(input_buffering_enabled_to_label)

        local input_buffering_enabled_button = mn.OptionButton({
            input_buffering_enabled_to_label[true],
            input_buffering_enabled_to_label[false]
        })

        input_buffering_enabled_button:set_option(input_buffering_enabled_to_label[rt.GameState:get_is_input_buffering_enabled()])
        input_buffering_enabled_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_input_buffering_enabled(label_to_input_buffering_enabled[label])
        end)

        local item = add_item(
            translation.input_buffering_enabled_prefix, input_buffering_enabled_button,
            mn.VerboseInfoObject.INPUT_BUFFERING_ENABLED
        )

        item:signal_connect("reset", function(_)
            input_buffering_enabled_button:set_option(input_buffering_enabled_to_label[defaults.is_input_buffering_enabled])
        end)
    end

    init_functions[SettingsItem.SPEEDRUN_SPLITS] = function() -- speedrun splits
        local draw_speedrun_splits_to_label = {
            [false] = translation.draw_speedrun_splits_off,
            [true] = translation.draw_speedrun_splits_on
        }
        local label_to_draw_speedrun_splits = reverse(draw_speedrun_splits_to_label)

        local draw_speedrun_splits_button = mn.OptionButton({
            draw_speedrun_splits_to_label[false],
            draw_speedrun_splits_to_label[true]
        })

        draw_speedrun_splits_button:set_option(draw_speedrun_splits_to_label[rt.GameState:get_draw_speedrun_splits()])
        draw_speedrun_splits_button:signal_connect("selection", function(_, label)
            rt.GameState:set_draw_speedrun_splits(label_to_draw_speedrun_splits[label])
        end)

        local item = add_item(
            translation.draw_speedrun_splits_prefix, draw_speedrun_splits_button,
            mn.VerboseInfoObject.DRAW_SPEEDRUN_SPLITS_ENABLED
        )

        item:signal_connect("reset", function(_)
            draw_speedrun_splits_button:set_option(draw_speedrun_splits_to_label[defaults.draw_speedrun_splits])
        end)
    end

    init_functions[SettingsItem.DEBUG_PRINT] = function() -- debug print
        local draw_debug_info_to_label = {
            [false] = translation.draw_debug_info_off,
            [true] = translation.draw_debug_info_on
        }
        local label_to_draw_debug_info = reverse(draw_debug_info_to_label)

        local draw_debug_info_button = mn.OptionButton({
            draw_debug_info_to_label[false],
            draw_debug_info_to_label[true]
        })

        draw_debug_info_button:set_option(draw_debug_info_to_label[rt.GameState:get_draw_debug_information()])
        draw_debug_info_button:signal_connect("selection", function(_, label)
            rt.GameState:set_draw_debug_information(label_to_draw_debug_info[label])
        end)

        local item = add_item(
            translation.draw_debug_info_prefix, draw_debug_info_button,
            mn.VerboseInfoObject.DRAW_DEBUG_INFO_ENABLED
        )

        item:signal_connect("reset", function(_)
            draw_debug_info_button:set_option(draw_debug_info_to_label[defaults.draw_debug_information])
        end)
    end

    for item in values(rt.settings.settings_scene.item_order) do
        init_functions[item]()
    end

    -- input

    self._scale_elapsed = 0
    self._scale_delay_elapsed = 0
    self._scale_active = false
    self._scale_direction = nil

    self._scroll_elapsed = 0
    self._scroll_active = false
    self._scroll_direction = nil

    self._mouse_input_active = false
    self._mouse_x, self._mouse_y = -math.huge, -math.huge

    local handle_left_pressed = function()
        local item = self._list:get_selected_item()
        if item.is_scale then
            self._scale_elapsed = 0
            self._scale_delay_elapsed = 0
            self._scale_active = true
            self._scale_direction = rt.Direction.LEFT
            item.widget:move_left()
        else
            item.widget:move_left()
        end
    end

    local handle_right_pressed = function()
        local item = self._list:get_selected_item()
        if item.is_scale then
            self._scale_elapsed = 0
            self._scale_delay_elapsed = 0
            self._scale_active = true
            self._scale_direction = rt.Direction.RIGHT
            item.widget:move_right()
        else
            item.widget:move_right()
        end
    end

    local handle_up_pressed = function()
        self:_start_scroll(rt.Direction.UP)
    end

    local handle_down_pressed = function()
        self:_start_scroll(rt.Direction.DOWN)
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        self._mouse_input_active = false

        self._scale_active = false
        if which == rt.InputAction.UP then
            handle_up_pressed()
        elseif which == rt.InputAction.DOWN then
            handle_down_pressed()
        elseif which == rt.InputAction.LEFT then
            handle_left_pressed()
        elseif which == rt.InputAction.RIGHT then
            handle_right_pressed()
        elseif which == rt.InputAction.RESET then
            local item = self._list:get_selected_item()
            rt.SoundManager:play(rt.SoundIDs.settings_scene.reset)
            item:signal_emit("reset")
        elseif which == rt.InputAction.BACK then
            rt.SoundManager:play(rt.SoundIDs.settings_scene.save)
            rt.SceneManager:pop()
        elseif which == rt.InputAction.SPECIAL then
            self._background_only = true
        end
    end)

    local handle_left_right_released = function()
        self._scale_active = false
    end

    local handle_up_down_released = function()
        self:_stop_scroll()
    end

    self._input:signal_connect("released", function(_, which)
        self._mouse_input_active = false

        if which == rt.InputAction.LEFT or which == rt.InputAction.RIGHT then
            handle_left_right_released()
        elseif which == rt.InputAction.UP or which == rt.InputAction.DOWN then
            handle_up_down_released()
        elseif which == rt.InputAction.SPECIAL then
            self._background_only = false
        end
    end)

    self._joystick_gesture = rt.JoystickGestureDetector()

    self._joystick_gesture:signal_connect("pressed", function(_, which)
        self._mouse_input_active = false
        if which == rt.InputAction.UP then
            handle_up_pressed()
        elseif which == rt.InputAction.DOWN then
            handle_down_pressed()
        elseif which == rt.InputAction.LEFT then
            handle_left_pressed()
        elseif which == rt.InputAction.RIGHT then
            handle_right_pressed()
        end
    end)

    self._joystick_gesture:signal_connect("released", function(_, which)
        if which == rt.InputAction.LEFT or which == rt.InputAction.RIGHT then
            handle_left_right_released()
        elseif which == rt.InputAction.UP or which == rt.InputAction.DOWN then
            handle_up_down_released()
        end
    end)
end

--- @brief
function mn.SettingsScene:realize()
    for widget in range(
        self._heading_label,
        self._heading_label_frame,
        self._scale_control_indicator,
        self._option_button_control_indicator,
        self._verbose_info,
        self._scrollbar,
        self._item_frame,
        self._list
    ) do
        widget:realize()
    end
end

--- @brief
function mn.SettingsScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m
    local item_outer_margin = 2 * m
    local item_inner_margin = 4 * m
    local item_y_padding = m

    local option_control_w, option_control_h = self._option_button_control_indicator:measure()
    local scale_control_w, scale_control_h = self._scale_control_indicator:measure()
    local control_h = math.max(option_control_h, scale_control_h)

    local heading_w, heading_h = self._heading_label:measure()
    local left_x, top_y = x + outer_margin, y + outer_margin
    local heading_frame_h = math.max(heading_h + 2 * item_y_padding, control_h)
    self._heading_label_frame:reformat(left_x, top_y, heading_w + 2 * item_outer_margin, heading_frame_h)
    self._heading_label:reformat(left_x + item_outer_margin, top_y + 0.5 * heading_frame_h - 0.5 * heading_h, math.huge)

    local current_x, current_y = left_x, top_y + heading_frame_h + m
    self._option_button_control_indicator:reformat(
        x + width - outer_margin - option_control_w,
        top_y,--y + height - outer_margin - option_control_h,
        option_control_w, option_control_h
    )

    self._scale_control_indicator:reformat(
        x + width - outer_margin - scale_control_w,
        top_y, --y + height - outer_margin - scale_control_h,
        scale_control_w, scale_control_h
    )

    local list_w = 2 / 3 * width - 2 * outer_margin + self._list:get_scrollbar_width()

    local verbose_info_w = width - list_w - 2 * outer_margin - m
    local verbose_info_h = height - 2 * outer_margin - heading_frame_h - m
    self._verbose_info:reformat(
        x + width - outer_margin - verbose_info_w, current_y, verbose_info_w, verbose_info_h
    )

    local max_prefix_w = -math.huge
    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        local prefix_w, prefix_h = item.prefix:measure()
        max_prefix_w = math.max(max_prefix_w, prefix_w)
    end

    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        item.size_allocate = function(self, x, y, width, height)
            local prefix_w, prefix_h = self.prefix:measure()

            self.prefix:reformat(
                x + item_outer_margin,
                y + 0.5 * height - 0.5 * prefix_h,
                math.huge, math.huge
            )

            local widget_h
            if item.is_scale then
                widget_h = prefix_h
            else
                widget_h = height - 2 * item_y_padding
            end

            local widget_w = width - 2 * item_outer_margin - item_inner_margin - max_prefix_w
            item.widget:reformat(
                x + width - item_outer_margin - widget_w,
                y + 0.5 * height - 0.5 * widget_h,
                widget_w, widget_h
            )
        end

        item.measure = function(self)
            return select(1, self.widget:measure()), control_h
        end
    end

    self._list:reformat(
        current_x, current_y,
        list_w,
        verbose_info_h
    )
end

--- @brief
function mn.SettingsScene:enter()
    self._background_only = false
    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(false)
    self._list:set_selected_item(1)
    rt.SceneManager:set_is_cursor_visible(false)
    rt.MusicManager:play(rt.MusicIDs.settings_scene)
end

--- @brief
function mn.SettingsScene:exit()
    self._input:deactivate()
    rt.SceneManager:set_is_cursor_visible(false)
    rt.MusicManager:pause(rt.MusicIDs.settings_scene)
end

--- @brief
function mn.SettingsScene:update(delta)
    self._heading_label:update(delta)
    self._verbose_info:update(delta)

    for i = 1, self._list:get_n_items() do
        local item = self._list:get_item(i)
        item.widget:update(delta)
    end

    if self._scale_active then
        self._scale_delay_elapsed = self._scale_delay_elapsed + delta
        if self._scale_delay_elapsed > rt.settings.settings_scene.scale_movement_delay then
            self._scale_elapsed = self._scale_elapsed + delta
            local step = 1 / rt.settings.settings_scene.scale_movement_ticks_per_second
            local scale = self._list:get_item(self._list:get_selected_item_i()).widget
            while self._scale_elapsed > step do
                self._scale_elapsed = self._scale_elapsed - step
                if self._scale_direction == rt.Direction.LEFT then
                    scale:move_left()
                elseif self._scale_direction == rt.Direction.RIGHT then
                    scale:move_right()
                end
            end
        end
    end

    if self._scroll_active then
        local step = 1 / rt.settings.settings_scene.scroll_ticks_per_second
        while self._scroll_elapsed > step do
            self._scroll_elapsed = self._scroll_elapsed - step
            if self._scroll_direction == rt.Direction.UP then
                self._list:scroll_up()
            elseif self._scroll_direction == rt.Direction.DOWN then
                self._list:scroll_down()
            end
        end

        self._scroll_elapsed = self._scroll_elapsed + delta
    end

    if self._mouse_input_active then
        self._list:set_selected_item_from_cursor_position(
            self._mouse_x, self._mouse_y
        )
    end
end

--- @brief
function mn.SettingsScene:draw()
    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("black", { rt.Palette.BLACK:unpack() })
    _shader:send("lch_texture", _lch_texture)
    love.graphics.rectangle("fill", self._bounds:unpack())
    _shader:unbind()

    if self._background_only then return end

    self._heading_label_frame:draw()
    self._heading_label:draw()
    self._verbose_info:draw()

    self._list:draw()
    local item = self._list:get_selected_item()
    if item.is_scale then
        self._scale_control_indicator:draw()
    else
        self._option_button_control_indicator:draw()
    end
end

--- @brief
function mn.SettingsScene:_start_scroll(direction)
    if self._scroll_active == false then
        self._scroll_active = true
        self._scroll_elapsed = 1 / rt.settings.settings_scene.scroll_ticks_per_second
    end

    self._scroll_direction = direction
end

--- @brief
function mn.SettingsScene:_stop_scroll()
    self._scroll_active = false
end
