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
    shake_default = true,
    music_level_default = 1,
    sound_effect_level_default = 1,
    deadzone_default = 0.15,
    textspeed_default = 1,

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
mn.SettingsScene.Item = meta.class("SettinsSceneItem", rt.Widget)
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

--- @brief
function mn.SettingsScene:instantiate()
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
            mn.VerboseInfoObject.VSYNC_WIDGET
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
            mn.VerboseInfoObject.MSAA_WIDGET
        )
        item:signal_connect("reset", function(_)
            msaa_button:set_option(msaa_to_label[rt.settings.settings_scene.msaa_default])
        end)
    end

    do -- shake
        local shake_to_label = {
            [true] = translation.shake_on,
            [false] = translation.shake_off
        }
        local label_to_shake = reverse(shake_to_label)

        local shake_button = mn.OptionButton({
            shake_to_label[true],
            shake_to_label[false]
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

    -- input

    self._scale_elapsed = 0
    self._scale_delay_elapsed = 0
    self._scale_active = false
    self._scale_direction = nil

    self._scroll_elapsed = 0
    self._scroll_active = false
    self._scroll_direction = nil

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
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
            item:signal_emit("reset")
        elseif which == rt.InputAction.B then
            rt.SceneManager:pop()
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputAction.LEFT or which == rt.InputAction.RIGHT then
            self._scale_active = false
        elseif which == rt.InputAction.UP or which == rt.InputAction.DOWN then
            self:_stop_scroll()
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
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

    local verbose_info_w = (width - 2 * outer_margin) * rt.settings.settings_scene.verbose_info_width_fraction
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
    end

    self._list:reformat(
        current_x, current_y,
        width - 2 * outer_margin - verbose_info_w - m,
        verbose_info_h
    )
end

--- @brief
function mn.SettingsScene:enter()
    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(false)
    self._list:set_selected_item(1)
end

--- @brief
function mn.SettingsScene:exit()
    self._input:deactivate()
end

--- @brief
function mn.SettingsScene:update(delta)
    self._heading_label:update(delta)
    self._verbose_info:update(delta)

    for item in values(self._items) do
        item.widget:update(delta)
    end

    if self._scale_active then
        self._scale_delay_elapsed = self._scale_delay_elapsed + delta
        if self._scale_delay_elapsed > rt.settings.settings_scene.scale_movement_delay then
            self._scale_elapsed = self._scale_elapsed + delta
            local step = 1 / rt.settings.settings_scene.scale_movement_ticks_per_second
            local scale = self._items[self._selected_item_i].widget
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
end

--- @brief
function mn.SettingsScene:draw()
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
