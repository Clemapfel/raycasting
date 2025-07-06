require "common.label"
require "common.sprite"
require "common.frame"
require "common.shape"
require "menu.msaa_visualization_widget"
require "menu.deadzone_visualization_widget"
require "menu.text_speed_visualization_widget"

--- @class VerboseInfoPanel.Item
mn.VerboseInfoPanel.Item = meta.class("MenuVerboseInfoPanelItem", rt.Widget)

--- @brief
function mn.VerboseInfoPanel.Item:instantiate()
    meta.install(self, {
        aabb = rt.AABB(0, 0, 1, 1),
        height_above = 0,
        frame = rt.Frame(),
        divider = rt.Line(0, 0, 1, 1),
        object = nil,
        final_height = 1,
        content = {} -- Table<rt.Drawable>
    })

    self.divider:set_color(rt.Palette.WHITE)
    self.frame:set_corner_radius(1)
end

--- @override
function mn.VerboseInfoPanel.Item:draw()
    for object in values(self.content) do
        object:draw()
    end
end

--- @override
function mn.VerboseInfoPanel.Item:measure()
    return self._bounds.width, self.final_height
end

--- @brief
function mn.VerboseInfoPanel.Item:create_from(object)
    self:create_from_enum(object)
end

function mn.VerboseInfoPanel.Item._font()
    return rt.FontSize.REGULAR
end

function mn.VerboseInfoPanel.Item._font_tiny()
    return rt.FontSize.SMALL
end

function mn.VerboseInfoPanel.Item._title(...)
    local out = rt.Label("<b><u>" .. string.paste(...) .. "</u></b>", mn.VerboseInfoPanel.Item._font())
    out:set_justify_mode(rt.JustifyMode.LEFT)
    out:realize()
    return out
end

function mn.VerboseInfoPanel.Item._description(...)
    local out = rt.Label("" .. string.paste(...), mn.VerboseInfoPanel.Item._font())
    out:set_justify_mode(rt.JustifyMode.LEFT)
    out:realize()
    return out
end

function mn.VerboseInfoPanel.Item._flavor_text(...)
    local out = rt.Label("<color=GRAY_2><i>" .. string.paste(...) .. "</color></i>", mn.VerboseInfoPanel.Item._font_tiny())
    out:set_justify_mode(rt.JustifyMode.CENTER)
    out:realize()
    return out
end

function mn.VerboseInfoPanel.Item._sprite(object)
    local out = rt.Sprite(object:get_sprite_id())
    out:realize()
    return out
end

function mn.VerboseInfoPanel.Item._hrule()
    local out = rt.Spacer()
    out:set_minimum_size(0, 2)
    out:set_color(rt.Palette.GRAY_4)
    out:realize()
    return out
end

function mn.VerboseInfoPanel.Item._colon()
    local out = rt.Label("<color=GRAY><b>:</b></color>", mn.VerboseInfoPanel.Item._font())
    out:set_justify_mode(rt.JustifyMode.LEFT)
    out:realize()
    return out
end

function mn.VerboseInfoPanel.Item._get_margin()
    local m = rt.settings.margin_unit
    return m, 2 * m, m
end

function mn.VerboseInfoPanel.Item._number(value, color)
    local out
    if color ~= nil then
        out = rt.Label("<color=" .. color .. "><mono>" .. value .. "</mono></color>", mn.VerboseInfoPanel.Item._font())
    else
        out = rt.Label("<mono>" .. value .. "</mono>", mn.VerboseInfoPanel.Item._font())
    end
    out:realize()
    out:set_justify_mode(rt.JustifyMode.LEFT)
    return out
end

function mn.VerboseInfoPanel.Item._prefix(str, color)
    local out
    if color ~= nil then
        out = rt.Label("<color=" .. color .. ">" .. str .. "</color>", mn.VerboseInfoPanel.Item._font())
    else
        out = rt.Label(str, mn.VerboseInfoPanel.Item._font())
    end
    out:realize()
    out:set_justify_mode(rt.JustifyMode.LEFT)
    return out
end

function mn.VerboseInfoPanel.Item._format_offset(x)
    if x > 0 then
        return "+" .. x
    elseif x < 0 then
        return "-" .. math.abs(x)
    else
        return rt.Translation.plus_minus .. x
    end
end

function mn.VerboseInfoPanel.Item._format_factor(x)
    x = math.abs(x)
    if x > 1 then
        return "+" .. math.round((x - 1) * 100) .. "%"
    elseif x < 1 then
        return "-" .. math.round((1 - x) * 100) .. "%"
    else
        return rt.Translation.plus_minus .. "0%"
    end
end

local _titles = nil
local _descriptions = nil

--- @brief party info
function mn.VerboseInfoPanel.Item:create_from_enum(which)
    self.object = nil
    self._is_realized = false

    if which == mn.VerboseInfoObject.MSAA_WIDGET then
        self:create_as_msaa_widget()
        return
    elseif which == mn.VerboseInfoObject.JOYSTICK_DEADZONE_WIDGET then
        self:create_as_deadzone_widget()
        return
    elseif which == mn.VerboseInfoObject.TEXT_SPEED_WIDGET then
        self:create_as_text_speed_widget()
        return
    elseif which == mn.VerboseInfoObject.VSYNC_WIDGET then
        self:create_as_vsync_widget()
        return
    elseif which == mn.VerboseInfoObject.MUSIC_LEVEL_WIDGET then
        self:create_as_music_level_widget()
        return
    elseif which == mn.VerboseInfoObject.SOUND_EFFECT_LEVEL_WIDGET then
        self:create_as_sound_effect_level_widget()
        return
    end

    local format_title = function(str)
        return "<b><u>" .. str .. "</u></b>"
    end

    local format_description = function(str)
        return str
    end

    local translation = rt.Translation.verbose_info
    if _titles == nil then
        _titles = {
            [mn.VerboseInfoObject.VSYNC] = format_title(translation.vsync_title),
            [mn.VerboseInfoObject.FULLSCREEN] = format_title(translation.fullscreen_title),
            [mn.VerboseInfoObject.MSAA] = format_title(translation.msaa_title),
            [mn.VerboseInfoObject.BLOOM] = format_title(translation.bloom_title),
            [mn.VerboseInfoObject.SOUND_EFFECT_LEVEL] = format_title(translation.sound_effect_level_title),
            [mn.VerboseInfoObject.MUSIC_LEVEL] = format_title(translation.music_level_title),
            [mn.VerboseInfoObject.SHAKE_ENABLED] = format_title(translation.shake_enabled_title),
            [mn.VerboseInfoObject.PERFORMANCE_MODE_ENABLED] = format_title(translation.performance_mode_enabled_title),
            [mn.VerboseInfoObject.JOYSTICK_DEADZONE] = format_title(translation.joystick_deadzone_title),
            [mn.VerboseInfoObject.TEXT_SPEED] = format_title(translation.text_speed_title),
            [mn.VerboseInfoObject.INPUT_ACTION_A] = format_title(translation.input_action_a_title),
            [mn.VerboseInfoObject.INPUT_ACTION_B] = format_title(translation.input_action_b_title),
            [mn.VerboseInfoObject.INPUT_ACTION_X] = format_title(translation.input_action_x_title),
            [mn.VerboseInfoObject.INPUT_ACTION_Y] = format_title(translation.input_action_y_title),
            [mn.VerboseInfoObject.INPUT_ACTION_UP] = format_title(translation.input_action_up_title),
            [mn.VerboseInfoObject.INPUT_ACTION_RIGHT] = format_title(translation.input_action_right_title),
            [mn.VerboseInfoObject.INPUT_ACTION_DOWN] = format_title(translation.input_action_down_title),
            [mn.VerboseInfoObject.INPUT_ACTION_LEFT] = format_title(translation.input_action_left_title),
            [mn.VerboseInfoObject.INPUT_ACTION_START] = format_title(translation.input_action_start_title),
            [mn.VerboseInfoObject.INPUT_ACTION_SELECT] = format_title(translation.input_action_select_title),
            [mn.VerboseInfoObject.INPUT_ACTION_L] = format_title(translation.input_action_l_title),
            [mn.VerboseInfoObject.INPUT_ACTION_R] = format_title(translation.input_action_r_title)
        }
    end

    if _descriptions == nil then
        _descriptions = {
            [mn.VerboseInfoObject.VSYNC] = format_description(translation.vsync_description),
            [mn.VerboseInfoObject.FULLSCREEN] = format_description(translation.fullscreen_description),
            [mn.VerboseInfoObject.MSAA] = format_description(translation.msaa_description),
            [mn.VerboseInfoObject.BLOOM] = format_description(translation.bloom_description),
            [mn.VerboseInfoObject.SOUND_EFFECT_LEVEL] = format_description(translation.sound_effect_level_description),
            [mn.VerboseInfoObject.MUSIC_LEVEL] = format_description(translation.music_level_description),
            [mn.VerboseInfoObject.SHAKE_ENABLED] = format_description(translation.shake_enabled_description),
            [mn.VerboseInfoObject.PERFORMANCE_MODE_ENABLED] = format_description(translation.performance_mode_enabled_description),
            [mn.VerboseInfoObject.JOYSTICK_DEADZONE] = format_description(translation.joystick_deadzone_description),
            [mn.VerboseInfoObject.TEXT_SPEED] = format_description(translation.text_speed_description),
            [mn.VerboseInfoObject.INPUT_ACTION_A] = format_description(translation.input_action_a_description),
            [mn.VerboseInfoObject.INPUT_ACTION_B] = format_description(translation.input_action_b_description),
            [mn.VerboseInfoObject.INPUT_ACTION_X] = format_description(translation.input_action_x_description),
            [mn.VerboseInfoObject.INPUT_ACTION_Y] = format_description(translation.input_action_y_description),
            [mn.VerboseInfoObject.INPUT_ACTION_UP] = format_description(translation.input_action_up_description),
            [mn.VerboseInfoObject.INPUT_ACTION_RIGHT] = format_description(translation.input_action_right_description),
            [mn.VerboseInfoObject.INPUT_ACTION_DOWN] = format_description(translation.input_action_down_description),
            [mn.VerboseInfoObject.INPUT_ACTION_LEFT] = format_description(translation.input_action_left_description),
            [mn.VerboseInfoObject.INPUT_ACTION_START] = format_description(translation.input_action_start_description),
            [mn.VerboseInfoObject.INPUT_ACTION_SELECT] = format_description(translation.input_action_select_description),
            [mn.VerboseInfoObject.INPUT_ACTION_L] = format_description(translation.input_action_l_description),
            [mn.VerboseInfoObject.INPUT_ACTION_R] = format_description(translation.input_action_r_description)
        }
    end

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.title_label = rt.Label(_titles[which])
        self.title_label:realize()
        self.title_label:set_justify_mode(rt.JustifyMode.LEFT)
        self.description_label = self._description(_descriptions[which])

        self.content = {
            self.title_label,
            self.description_label,
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        local m, xm, ym = self._get_margin()
        local start_y = y + ym
        local current_x, current_y = x + xm, start_y + ym
        local w = width - 2 * xm

        self.title_label:reformat(current_x, current_y, w)
        current_y = current_y + select(2, self.title_label:measure()) + m

        self.description_label:reformat(current_x, current_y, w)
        current_y = current_y + select(2, self.description_label:measure()) + m

        local total_height = current_y - start_y + 2 * ym
        self.frame:reformat(x, y, width, total_height)
        self.divider:reformat(x, y + total_height, x + width, y + total_height)
        self.final_height = total_height
    end

    self.measure = function(self)
        return self._bounds.width, self.final_height
    end

    return self
end

function mn.VerboseInfoPanel.Item:create_as_msaa_widget()
    self.object = nil
    self._is_realized = false

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.widget = mn.MSAAVisualizationWidget()
        self.widget:realize()

        self.content = {
            self.widget
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        local m, xm, ym = self._get_margin()
        ym = 2 * ym
        local w = 0.75 * (width - 2 * xm)
        height = w + 2 * ym
        self.widget:reformat(
            x + 0.5 * width - 0.5 * w,
            y + 0.5 * height - 0.5 * w,
            w,
            w
        )

        self.frame:reformat(x, y, width, height)
        self.divider:reformat(x, y + height, x + width, y + height)
        self.final_height = height
    end

    self.update = function(self, delta)
        self.widget:update(delta)
    end
end

function mn.VerboseInfoPanel.Item:create_as_deadzone_widget()
    self.object = nil
    self._is_realized = false

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.widget = mn.DeadzoneVisualizationWidget()
        self.widget:realize()

        self.content = {
            self.widget
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        local m, xm, ym = self._get_margin()
        ym = 2 * ym
        local w = 0.75 * (width - 2 * xm)
        height = w + 2 * ym
        self.widget:reformat(
            x + 0.5 * width - 0.5 * w,
            y + 0.5 * height - 0.5 * w,
            w,
            w
        )

        self.frame:reformat(x, y, width, height)
        self.divider:reformat(x, y + height, x + width, y + height)
        self.final_height = height
    end

    self.update = function(self, delta)
        self.widget:update(delta)
    end
end

function mn.VerboseInfoPanel.Item:create_as_text_speed_widget()
    self.object = nil
    self._is_realized = false

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.widget = mn.TextSpeedVisualizationWidget()
        self.widget:realize()

        self.content = {
            self.widget
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        height = width
        local m, xm, ym = self._get_margin()

        self.widget:reformat(x + xm, y + ym, width - 2 * xm, height)
        local w, h = self.widget:measure()
        self.widget:reformat(x + xm, y + ym, width - 2 * xm, h)

        h = h + 2 * ym
        self.frame:reformat(x, y, width, h)
        self.divider:reformat(x, y + h, x + width, y + h)
        self.final_height = h - 2 * ym
    end

    self.update = function(self, delta)
        self.widget:update(delta)
    end
end

function mn.VerboseInfoPanel.Item:create_as_vsync_widget()
    self.object = nil
    self._is_realized = false

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.label = rt.Label(rt.Translation.verbose_info.vsync_widget(0))
        self.label:realize()
        self.label:set_justify_mode(rt.JustifyMode.LEFT)

        self.content = {
            self.label
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        local m, xm, ym = self._get_margin()
        ym = 2 * ym
        local w = 0.75 * (width - 2 * xm)
        self.label:reformat(
            x + xm, y + ym, width - 2 * xm, height - 2 * ym
        )

        local label_w, label_h = self.label:measure()
        self.frame:reformat(x, y + ym, width, label_h + 2 * ym)
        self.divider:reformat(x, y + label_h + 2 * ym, x + width, y + label_h + 2 * ym)
        self.final_height = height - 2 * ym
    end

    self.update = function(self, delta)
        self.label:set_text(rt.Translation.verbose_info.vsync_widget(love.timer.getFPS()))
    end
end

function mn.VerboseInfoPanel.Item:create_as_music_level_widget()
    self.object = nil
    self._is_realized = false

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.label = rt.Label(rt.Translation.verbose_info.music_level_widget(math.round(rt.GameState:get_music_level() * 100)))
        self.label:realize()
        self.label:set_justify_mode(rt.JustifyMode.LEFT)

        self.content = {
            self.label
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        local m, xm, ym = self._get_margin()
        ym = 2 * ym
        local w = 0.75 * (width - 2 * xm)
        self.label:reformat(
            x + xm, y + ym, width - 2 * xm, height - 2 * ym
        )

        local label_w, label_h = self.label:measure()
        self.frame:reformat(x, y + ym, width, label_h + 2 * ym)
        self.divider:reformat(x, y + label_h + 2 * ym, x + width, y + label_h + 2 * ym)
        self.final_height = height - 2 * ym
    end

    self.update = function(self, delta)
        self.label:set_text(rt.Translation.verbose_info.music_level_widget(math.round(rt.GameState:get_music_level() * 100)))
    end
end

function mn.VerboseInfoPanel.Item:create_as_sound_effect_level_widget()
    self.object = nil
    self._is_realized = false

    self.realize = function()
        self._is_realized = true
        self.frame:realize()

        self.label = rt.Label(rt.Translation.verbose_info.sound_effect_level_widget(math.round(rt.GameState:get_music_level() * 100)))
        self.label:realize()
        self.label:set_justify_mode(rt.JustifyMode.LEFT)

        self.content = {
            self.label
        }
    end

    self.size_allocate = function(self, x, y, width, height)
        local m, xm, ym = self._get_margin()
        ym = 2 * ym
        local w = 0.75 * (width - 2 * xm)
        self.label:reformat(
            x + xm, y + ym, width - 2 * xm, height - 2 * ym
        )

        local label_w, label_h = self.label:measure()
        self.frame:reformat(x, y + ym, width, label_h + 2 * ym)
        self.divider:reformat(x, y + label_h + 2 * ym, x + width, y + label_h + 2 * ym)
        self.final_height = height - 2 * ym
    end

    self.update = function(self, delta)
        self.label:set_text(rt.Translation.verbose_info.sound_effect_level_widget(math.round(rt.GameState:get_sound_effect_level() * 100)))
    end
end


