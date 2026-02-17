require "common.scene"
require "common.input_subscriber"
require "common.frame"
require "common.game_state"
require "common.control_indicator"
require "menu.verbose_info_panel"
require "menu.scale"
require "menu.option_button"
require "menu.scrollable_list"

rt.settings.settings_scene = {
    fullscreen_default = true,
    vsync_default = rt.VSyncMode.ADAPTIVE,
    msaa_default = rt.MSAAQuality.BEST,
    bloom_default = true,
    hdr_default = false,
    shake_default = true,
    music_level_default = 1,
    sound_effect_level_default = 1,
    deadzone_default = 0.15,
    textspeed_default = 1,
    double_press_threshold_default = 0.5,
    performance_mode_default = false,
    color_blind_mode_default = false,
    draw_debug_info_default = false,
    draw_speedrun_splits_default = false,
    input_buffering_enabled_default = true,
    sprint_mode_default = rt.PlayerSprintMode.MANUAL,

    scale_movement_ticks_per_second = 100,
    scale_movement_delay = 20 / 60,

    scroll_ticks_per_second = 4,
    scroll_delay = 20 / 60,

    verbose_info_width_fraction = 1 / 3,
    scrollbar_width_factor = 1.5, -- times margin
}

--- @class mn.SettingsScene
mn.SettingsScene = meta.class("MenuSettingsScene", rt.Scene)

--- @class mn.SettingsScene.Item
mn.SettingsScene.Item = meta.class("SettingsSceneItem", rt.Widget)
meta.add_signal(mn.SettingsScene.Item, "reset")

--[[
How to add a new settings items:
    add <name> to mn.VerboseInfoObject enum
    add <name>_description to rt.Translation.verbose_info
    add <name>_title to rt.Translation.verbose_info
    add <name>_prefix to rt.Translation.settings_scene
    add widget in mn.SettingsScene:instantiate
]]

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

--- @brief
function mn.SettingsScene:instantiate()
    self._background_only = false
    local translation = rt.Translation.settings_scene

    self._option_button_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_select,
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move,
        rt.ControlIndicatorButton.Y, translation.control_indicator_restore_default,
        rt.ControlIndicatorButton.B, translation.control_indicator_back
    )

    self._scale_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_select,
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move,
        rt.ControlIndicatorButton.Y, translation.control_indicator_restore_default,
        rt.ControlIndicatorButton.B, translation.control_indicator_back
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

    do -- vsync
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
            vsync_button:set_option(vsync_to_label[rt.settings.settings_scene.vsync_default])
        end)
    end

    do -- fullscreen
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
            fullscreen_button:set_option(fullscreen_to_label[rt.settings.settings_scene.fullscreen_default])
        end)
    end

    do -- msaa
        local msaa_to_label = {
            [rt.MSAAQuality.OFF] = translation.msaa_off,
            [rt.MSAAQuality.GOOD] = translation.msaa_good,
            [rt.MSAAQuality.BETTER] = translation.msaa_better,
            [rt.MSAAQuality.BEST] = translation.msaa_best,
            [rt.MSAAQuality.MAX] = translation.msaa_max,
        }
        local label_to_msaa = reverse(msaa_to_label)

        local msaa_button = mn.OptionButton({
            msaa_to_label[rt.MSAAQuality.OFF],
            msaa_to_label[rt.MSAAQuality.GOOD],
            msaa_to_label[rt.MSAAQuality.BETTER],
            msaa_to_label[rt.MSAAQuality.BEST],
            msaa_to_label[rt.MSAAQuality.MAX]
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
            msaa_button:set_option(msaa_to_label[rt.settings.settings_scene.msaa_default])
        end)
    end

    do -- bloom
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
            bloom_button:set_option(bloom_to_label[rt.settings.settings_scene.bloom_default])
        end)
    end

    do -- hdr
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
            hdr_button:set_option(hdr_to_label[rt.settings.settings_scene.hdr_default])
        end)
    end

    do -- music
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
            music_level_scale:set_value(rt.settings.settings_scene.music_level_default)
        end)
    end

    do -- sound effect
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
            sound_effect_level_scale:set_value(rt.settings.settings_scene.sound_effect_level_default)
        end)
    end

    do -- dead zone
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
            deadzone_scale:set_value(rt.settings.settings_scene.deadzone_default)
        end)
    end

    do -- text speed
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
            text_speed_scale:set_value(rt.settings.settings_scene.text_speed_default)
        end)
    end

    --[[
    do -- double press threshold
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
    ]]--

    do -- shake
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
            shake_button:set_option(shake_to_label[rt.settings.settings_scene.shake_default])
        end)
    end

    do -- color blind mode
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
    end

    do -- performance mode
        local performance_mode_to_label = {
            [false] = translation.performance_mode_off,
            [true] = translation.performance_mode_on
        }
        local label_to_performance_mode = reverse(performance_mode_to_label)

        local performance_mode_button = mn.OptionButton({
            performance_mode_to_label[false],
            performance_mode_to_label[true]
        })

        performance_mode_button:set_option(performance_mode_to_label[rt.GameState:get_is_performance_mode_enabled()])
        performance_mode_button:signal_connect("selection", function(_, label)
            rt.GameState:set_is_performance_mode_enabled(label_to_performance_mode[label])
        end)

        local item = add_item(
            translation.performance_mode_prefix, performance_mode_button,
            mn.VerboseInfoObject.PERFORMANCE_MODE_ENABLED
        )

        item:signal_connect("reset", function(_)
            performance_mode_button:set_option(performance_mode_to_label[rt.settings.settings_scene.performance_mode_default])
        end)
    end

    do -- sprint mode
        local sprint_mode_to_label = {
            [rt.PlayerSprintMode.MANUAL] = translation.sprint_mode_manual,
            [rt.PlayerSprintMode.AUTO] = translation.sprint_mode_auto
        }
        local label_to_sprint_mode = reverse(sprint_mode_to_label)

        local sprint_mode_button = mn.OptionButton({
            sprint_mode_to_label[rt.PlayerSprintMode.MANUAL],
            sprint_mode_to_label[rt.PlayerSprintMode.AUTO]
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
            sprint_mode_button:set_option(sprint_mode_to_label[rt.settings.settings_scene.sprint_mode_default])
        end)
    end

    do -- input buffering
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
            input_buffering_enabled_button:set_option(input_buffering_enabled_to_label[rt.settings.settings_scene.draw_speedrun_splits_default])
        end)
    end

    do -- speedrun splits
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
            draw_speedrun_splits_button:set_option(draw_speedrun_splits_to_label[rt.settings.settings_scene.draw_speedrun_splits_default])
        end)
    end

    do -- debug print
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
            draw_debug_info_button:set_option(draw_debug_info_to_label[rt.settings.settings_scene.draw_debug_info_default])
        end)
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

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        self._mouse_input_active = false

        self._scale_active = false
        if which == rt.InputAction.UP then
            self:_start_scroll(rt.Direction.UP)
        elseif which == rt.InputAction.DOWN then
            self:_start_scroll(rt.Direction.DOWN)
        elseif which == rt.InputAction.LEFT then
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
        elseif which == rt.InputAction.RIGHT then
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
        elseif which == rt.InputAction.Y then
            local item = self._list:get_selected_item()
            rt.SoundManager:play(rt.SoundIDs.settings_scene.reset)
            item:signal_emit("reset")
        elseif which == rt.InputAction.B then
            rt.SoundManager:play(rt.SoundIDs.settings_scene.save)
            rt.SceneManager:pop()
        elseif which == rt.InputAction.L or which == rt.InputAction.R then
            self._background_only = true
        end
    end)

    self._input:signal_connect("released", function(_, which)
        self._mouse_input_active = false

        if which == rt.InputAction.LEFT or which == rt.InputAction.RIGHT then
            self._scale_active = false
        elseif which == rt.InputAction.UP or which == rt.InputAction.DOWN then
            self:_stop_scroll()
        elseif which == rt.InputAction.L or which == rt.InputAction.R then
            self._background_only = false
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self._mouse_input_active = false

        if y < 0 then
            self:_start_scroll(rt.Direction.UP)
        elseif y > 0 then
            self:_start_scroll(rt.Direction.DOWN)
        else
            self:_stop_scroll()
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
    rt.SceneManager:set_is_cursor_visible(true)
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
