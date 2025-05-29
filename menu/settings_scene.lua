require "common.scene"
require "common.input_subscriber"
require "common.frame"
require "common.game_state"
require "common.control_indicator"
require "menu.verbose_info_panel"
require "menu.scale"
require "menu.option_button"
require "menu.scrollbar"

rt.settings.settings_scene = {
    fullscreen_default = true,
    vsync_default = rt.VSyncMode.ADAPTIVE,
    msaa_default = rt.MSAAQuality.BEST,
    shake_default = true,
    music_level_default = 1,
    sound_effect_level_default = 1,
    deadzone_default = 0.15,
    textspeed_default = 1
}

--- @class mn.SettingsScene
mn.SettingsScene = meta.class("MenuSettingsScene", rt.Scene)

--[[
full screen: on off
    description

vsync: adaptive, off, on
    description
f
msaa: off, good, better, best
    description
   widget

shake: off, on
    description

music level: scale
    description

sound effect leve: scale
    description

dead zone: scale
    description
    widget

textspeed: scale
    description
    widget
]]

--- @class mn.SettingsScene.Item
mn.SettingsScene.Item = meta.class("SettinsSceneItem")
meta.add_signal(mn.SettingsScene.Item, "reset")

--- @brief [internal]
function mn.SettingsScene.Item:instantiate(t)
    meta.install(self, t)
end

--- @brief
function mn.SettingsScene:instantiate()
    local translation = rt.Translation.settings_scene
    
    self._option_button_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_move,
        rt.ControlIndicatorButton.Y, translation.control_indicator_restore_default,
        rt.ControlIndicatorButton.B, translation.control_indicator_back
    )
    
    self._scale_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.ALL_DIRECTIONS, translation.control_indicator_move,
        rt.ControlIndicatorButton.Y, translation.control_indicator_restore_default,
        rt.ControlIndicatorButton.B, translation.control_indicator_back
    )

    self._verbose_info = mn.VerboseInfoPanel()
    self._scrollbar = mn.Scrollbar()
    self._item_frame = rt.Frame()
    self._item_stencil = rt.Rectangle()
    
    self._heading_label = rt.Label("<b><o>" .. translation.heading .. "</o></b>")
    self._heading_label_frame = rt.Frame()

    -- list items

    self._items = {}
    self._selected_item_i = 1
    self._n_items = 0

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
            frame = rt.Frame(),
            selected_frame = rt.Frame(),
            widget = widget,
            info = { ... },
            is_scale = meta.isa(widget, mn.Scale)
        })
        
        item.selected_frame:set_selection_state(rt.SelectionState.ACTIVE)
        table.insert(self._items, item)
        self._n_items = self._n_items + 1
        return item
    end
    
   
    local new_scale = function(default_value)
        return mn.Scale(0, 1, 1 / 100, default_value)
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
            mn.VerboseInfoObject.MUSIC_LEVEL
        )

        item:signal_connect("reset", function(_)
            music_level_scale:set_value(rt.settings.settings_scene.music_level_default)
        end)
    end

    do -- sound effect
        local sound_effect_level_scale = new_scale(rt.GameState:get_sound_effect_leve())
        sound_effect_level_scale:signal_connect("value_changed", function(_, value)
            rt.GameState:set_sound_effect_level(value)
        end)

        local item = add_item(
            translation.sound_effect_level_prefix, sound_effect_level_scale,
            mn.VerboseInfoObject.SOUND_EFFECT_LEVEL
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

    self._scrollbar:set_n_pages(self._n_items)
    self._scrollbar:set_page_index(1)

    -- input

    self._scale_elapsed = 0
    self._scale_active = false

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)

        if which == rt.InputButton.UP then
            if self._selected_item_i > 1 then
                self._selected_item_i = self._selected_item_i - 1
                self._verbose_info:show(self._items[self._selected_item_i].info)
                self._scrollbar:set_page_index(self._selected_item_i)
            end
        elseif which == rt.InputButton.DOWN then
            if self._selected_item_i < self._n_items then
                self._selected_item_i = self._selected_item_i + 1
                self._verbose_info:show(self._items[self._selected_item_i].info)
                self._scrollbar:set_page_index(self._selected_item_i)
            end
        elseif which == rt.InputButton.LEFT then
            local item = self._items[self._selected_item_i]
            if item.is_scale then
                self._scale_elapsed = 0
                self._scale_active = true
                item.widget:move_left()
            else
                self._scale_active = false
                item.widget:move_left()
            end
        elseif which == rt.InputButton.RIGHT then
            local item = self._items[self._selected_item_i]
            if item.is_scale then
                self._scale_elapsed = 0
                self._scale_active = true
                item.widget:move_right()
            else
                self._scale_active = false
                item.widget:move_right()
            end
        elseif which == rt.InputButton.Y then
            local item = self._items[self._selected_item_i]
            item:signal_emit("reset")
        elseif which == rt.InputButton.B then
            rt.SceneManager:set_scene(rt.SceneManager:get_previous_scene())
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
        self._item_frame
    ) do
        widget:realize()
    end

    for item in values(self._items) do
        for widget in range(
            item.frame,
            item.selected_frame,
            item.prefix,
            item.widget
        ) do
            widget:realize()
        end
    end
end

--- @brief
function mn.SettingsScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m
    local item_outer_margin = 2 * m
    local item_y_padding = m
    local item_y_margin = m
    local item_inner_margin = 4 * m

    local item_h, max_prefix_w = -math.huge, -math.huge
    for item in values(self._items) do
        local prefix_w, prefix_h = item.prefix:measure()
        item_h = math.max(item_h,
            prefix_h,
            select(2, item.widget:measure())
        )

        max_prefix_w = math.max(max_prefix_w, prefix_w)
    end

    local option_control_w, option_control_h = self._option_button_control_indicator:measure()
    local scale_control_w, scale_control_h = self._scale_control_indicator:measure()
    local control_h = math.max(option_control_h, scale_control_h)

    local heading_w, heading_h = self._heading_label:measure()
    local left_x, top_y = x + 2 * m, y + 2 * m
    local heading_frame_h = math.max(heading_h + 2 * item_y_padding, control_h)
    self._heading_label_frame:reformat(left_x, top_y, heading_w + 2 * item_outer_margin, heading_frame_h)
    self._heading_label:reformat(left_x + item_outer_margin, top_y + 0.5 * heading_frame_h - 0.5 * heading_h, math.huge)

    local current_x, current_y = left_x, top_y + heading_frame_h + item_y_margin

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

    local verbose_info_w = (width - 2 * outer_margin) * 1 / 3
    local verbose_info_h = height - 2 * outer_margin - heading_frame_h - item_y_margin
    self._verbose_info:reformat(
        x + width - outer_margin - verbose_info_w, current_y, verbose_info_w, verbose_info_h
    )

    local scrollbar_w = 1.5 * rt.settings.margin_unit
    self._scrollbar:reformat(
        x + width - outer_margin - verbose_info_w - item_y_margin - scrollbar_w,
        current_y,
        scrollbar_w,
        verbose_info_h
    )

    local frame_thickness = rt.settings.frame.thickness

    self._item_frame:reformat(
        current_x, current_y, width - 2 * outer_margin - verbose_info_w - item_y_margin, verbose_info_h
    )

    local padding = 2 * rt.get_pixel_scale()
    self._item_stencil:reformat(
        current_x - frame_thickness - padding,
        current_y - frame_thickness - padding,
        width - 2 * outer_margin - verbose_info_w - item_y_margin + 2 * frame_thickness + 2 * padding,
        verbose_info_h + 2 * frame_thickness + 0 * padding -- sic
    )

    item_h = math.max(item_h, control_h, (verbose_info_h - (self._n_items - 1) * item_y_margin - 2 * (self._n_items - 1) * frame_thickness)  / self._n_items)

    local item_w = width - 2 * outer_margin - verbose_info_w - item_outer_margin - scrollbar_w
    local widget_w = item_w - 2 * item_outer_margin - item_inner_margin - max_prefix_w

    for item in values(self._items) do
        for frame in range(
            item.frame,
            item.selected_frame
        ) do
            frame:reformat(left_x, current_y, item_w, item_h)
        end

        local prefix_w, prefix_h = item.prefix:measure()
        item.prefix:reformat(
            left_x + item_outer_margin,
            current_y + 0.5 * item_h - 0.5 * prefix_h,
            math.huge, math.huge
        )


        local widget_h
        if item.is_scale then
            widget_h = item_h - 3 * item_y_padding
        else
            widget_h = item_h - 2 * item_y_padding
        end

        item.widget:reformat(
            left_x + item_w - item_outer_margin - widget_w,
            current_y + 0.5 * item_h - 0.5 * widget_h,
            widget_w, widget_h
        )

        current_y = current_y + item_h + item_y_margin + 2 * frame_thickness
    end

    self._verbose_info:show(self._items[self._selected_item_i].info)
end

--- @brief
function mn.SettingsScene:enter()
    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(false)
end

--- @brief
function mn.SettingsScene:enter()
    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(false)
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
end

--- @brief
function mn.SettingsScene:draw()
    self._heading_label_frame:draw()
    self._heading_label:draw()
    
    self._verbose_info:draw()
    --self._item_frame:draw()

    local value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(value, self._item_stencil)
    rt.graphics.set_stencil_test(rt.StencilCompareMode.EQUAL)

    local is_scale = false
    for i, item in ipairs(self._items) do
        if i == self._selected_item_i then
            item.selected_frame:draw()
            is_scale = item.is_scale
        else
            item.frame:draw()
        end
        
        item.prefix:draw()
        item.widget:draw()
    end

    rt.graphics.set_stencil_test(nil)

    self._scrollbar:draw()

    if is_scale then
        self._scale_control_indicator:draw()
    else
        self._option_button_control_indicator:draw()
    end
end