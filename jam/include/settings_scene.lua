SettingsScene_t = "SettingsScene"

local _settings_title_font_size = 80 / 800
local _settings_font_size = 40 / 800
local _settings_outline_line_width = 1.5 / 800
local graphics_draw_lines = graphics_draw_line

local _settings_sound_effects_volume_label = "Sound Effects"
local _settings_music_volume_label = "Music"
local _settings_enable_shaders = "Enable Shaders"

settings_scene_new = function()
    return settings_scene_init(object_new(SettingsScene_t, {
        is_active = false
    }))
end

local _type_slider = "slider"
local _type_checkbox = "checkbox"

settings_scene_init = function(self)
    log_typecheck(self, SettingsScene_t)

    self.bounds = aabb_new(0, 0, graphics_get_size())
    self.entries = {
        {
            id = "sound_effects",
            type = _type_slider,

            unselected_label = label_new(
                _settings_sound_effects_volume_label, _settings_font_size * graphics_get_height(), TextStyle.BOLD
            ),
            selected_label = label_new(
                _settings_sound_effects_volume_label, _settings_font_size * graphics_get_height(), TextStyle.BOLD
            ),
        },
        {
            id = "music",
            type = _type_slider,

            unselected_label = label_new(
                _settings_music_volume_label, _settings_font_size * graphics_get_height(), TextStyle.BOLD
            ),
            selected_label = label_new(
                _settings_music_volume_label, _settings_font_size * graphics_get_height(), TextStyle.BOLD
            ),
        },
        {
            id = "shaders",
            type = _type_checkbox,

            unselected_label = label_new(
                _settings_enable_shaders, _settings_font_size * graphics_get_height(), TextStyle.BOLD
            ),
            selected_label = label_new(
                _settings_enable_shaders, _settings_font_size * graphics_get_height(), TextStyle.BOLD
            )
        }
    }

    for _, entry in ipairs(self.entries) do
        label_set_is_outlined(entry.unselected_label, true)
        label_set_is_outlined(entry.selected_label, true)
        label_set_is_rainbow(entry.selected_label, true)
        label_set_is_wave(entry.selected_label, true)
    end

    self.selected_entry_i = 1
    self.radius = 0

    self.title_label = label_set_is_wave(label_set_is_outlined(label_new(
        "Settings", _settings_title_font_size * graphics_get_height(), TextStyle.BOLD
    )))

    settings_scene_reformat(self, self.bounds)

    self.input_pressed_handler = input_connect_pressed(function(which)

        if state_get_scene_is_active(STATE, self) ~= true then return end

        local select = function(direction)
            self.selected_entry_i = math_clamp(
                self.selected_entry_i + direction,
                1,
                table_sizeof(self.entries)
            )
        end

        local adjust = function(direction)
            if self.selected_entry_i == 1 then
                local value = state_get_sound_effect_volume(STATE) + direction / 10
                state_set_sound_effect_volume(STATE, math_clamp(value, 0, 1))
                audio_replay_sound(self, SoundID.menu_down)
            elseif self.selected_entry_i == 2 then
                local value = state_get_music_volume(STATE) + direction / 10
                state_set_music_volume(STATE, math_clamp(value, 0, 1))
                audio_replay_sound(self, SoundID.menu_up)
            end
        end

        if which == input_action_move_up then
            select(-1)
        elseif which == input_action_move_down then
            select(1)
        elseif which == input_action_move_left then
            adjust(-1)
        elseif which == input_action_move_right then
            adjust(1)
        elseif which == input_action_accept then
            if self.selected_entry_i == 3 then
                state_set_shaders_enabled(STATE, not state_get_shaders_enabled(STATE))
            end
            audio_replay_sound(self, SoundID.menu_accept)
        elseif which == input_action_back then
            state_pop_scene(STATE)
        end
    end, self.input_pressed_handler)

    self.control_indicator = control_indicator_new(
        input_action_move_up, "Up",
        input_action_move_down, "Down",
        input_action_accept, "Accept",
        input_action_back, "Back"
    )

    return self
end

settings_scene_reformat = function(self, bounds)
    log_typecheck(self, SettingsScene_t)

    self.bounds = bounds
    local bx, by, bw, bh = aabb_unpack(bounds)
    local outer_m = _global_outer_margin
    local label_h = 0
    local label_w = 0

    for i, entry in ipairs(self.entries) do
        label_h = math_max(label_h, label_get_height(entry.unselected_label))
        if i <= 2 then
            label_w = math_max(label_w, label_get_width(entry.unselected_label))
        end
    end

    local row_m = outer_m
    local total_h = 3 * label_h + 2 * row_m
    local first_y = by + 0.5 * (bh - total_h) + 0.5 * label_h
    local label_x = bx + outer_m
    local control_x = label_x + label_w + outer_m
    local control_w = bx + bw - outer_m - control_x

    local content_x = bx + outer_m
    local content_w = bw - 2 * outer_m
    local title_w, title_h = label_get_size(self.title_label)
    local title_y = by + 1 / 4 * bh - 0.5 * title_h
    label_set_justify_mode(self.title_label, JustifyMode.CENTER)
    label_reformat(self.title_label, content_x, title_y, content_w, 0)

    self.radius = 0.5 * label_h

    for i, entry in ipairs(self.entries) do
        local y = first_y + (i - 1) * (label_h + row_m)

        entry.label_bounds = aabb_new(label_x, y, label_w, label_h)
        entry.control_bounds = aabb_new(control_x, y, control_w, label_h)

        for _, label in ipairs({ entry.unselected_label, entry.selected_label }) do
            label_set_justify_mode(label, JustifyMode.LEFT)
            label_reformat(label, label_x, y, label_w, 0)
        end
    end
end

settings_scene_update = function(self, delta)
    log_typecheck(self, SettingsScene_t)

    label_update(self.title_label, delta)
    for _, entry in ipairs(self.entries) do
        label_update(entry.unselected_label, delta)
        label_update(entry.selected_label, delta)
    end

    control_indicator_update(self.control_indicator, delta)
end

settings_scene_draw = function(self)
    log_typecheck(self, SettingsScene_t)

    local line_w = _settings_outline_line_width * graphics_get_height()

    local draw_outline = function(points, color)
        graphics_set_line_state(line_w + 1.5)
        rgba_bind(palette_black)
        graphics_draw_lines(points)

        graphics_set_line_state(line_w)
        rgba_bind(color)
        graphics_draw_lines(points)
    end

    local make_circle_contour = function(x, y, radius)
        local points = {}
        local n_segments = 24
        for i = 1, n_segments + 1 do
            local angle = (i - 1) / n_segments * math_tau
            table_push(points, x + radius * math_cos(angle))
            table_push(points, y + radius * math_sin(angle))
        end
        return points
    end

    local make_track_contour = function(left_x, right_x, y, radius)
        local points = {}
        local n_segments = 12
        for i = 0, n_segments do
            local angle = -0.5 * math_pi + i / n_segments * math_pi
            table_push(points, right_x + radius * math_cos(angle))
            table_push(points, y + radius * math_sin(angle))
        end
        for i = 0, n_segments do
            local angle = 0.5 * math_pi + i / n_segments * math_pi
            table_push(points, left_x + radius * math_cos(angle))
            table_push(points, y + radius * math_sin(angle))
        end
        table_push(points, points[1])
        table_push(points, points[2])
        return points
    end

    local radius = self.radius

    graphics_set_color(1, 1, 1, 1)
    label_draw(self.title_label)

    for i, entry in ipairs(self.entries) do
        graphics_set_color(1, 1, 1, 1)
        if i == self.selected_entry_i then
            label_draw(entry.selected_label)
        else
            label_draw(entry.unselected_label)
        end

        local cx, cy, cw, ch = aabb_unpack(entry.control_bounds)
        local center_y = entry.label_bounds.y + 0.5 * entry.label_bounds.height - 0.5 * ch

        if entry.type == _type_slider then
            local value
            if i == 1 then
                value = state_get_sound_effect_volume(STATE)
            else
                value = state_get_music_volume(STATE)
            end
            value = math_clamp(value, 0, 1)

            local slider_r = radius * 0.5
            local movable_r = radius * 7 / 5 * 0.5

            local left_x = cx + radius
            local right_x = cx + cw - radius

            rgba_bind(palette_dark_gray)
            graphics_draw_rectangle(left_x, center_y - slider_r, right_x - left_x, 2 * slider_r)
            graphics_draw_ellipse(left_x, center_y, slider_r)
            graphics_draw_ellipse(right_x, center_y, slider_r)
            draw_outline(make_track_contour(left_x, right_x, center_y, slider_r), palette_white)

            local moving_x = math_mix(left_x, right_x, value)
            rgba_bind(palette_light_gray)
            graphics_draw_ellipse(moving_x, center_y, movable_r)
            draw_outline(make_circle_contour(moving_x, center_y, movable_r), palette_white)
        elseif entry.type == _type_checkbox then
            local x = cx + 0.5 * cw

            rgba_bind(palette_dark_gray)
            graphics_draw_ellipse(x, center_y, radius)
            draw_outline(make_circle_contour(x, center_y, radius), palette_white)

            if state_get_shaders_enabled(STATE) then
                rgba_bind(palette_light_gray)
                local inner_r = 3 / 5 * radius
                graphics_draw_ellipse(x, center_y, inner_r)
                draw_outline(make_circle_contour(x, center_y, inner_r), palette_white)
            end
        else
            log_error("In settings_scene_draw: unhandled widget type `", entry.type, "`")
        end
    end
end

settings_scene_get_control_indicator = function(self)
    log_typecheck(self, SettingsScene_t)
    return self.control_indicator
end

settings_scene_enter = function(self)
    log_typecheck(self, SettingsScene_t)
end

settings_scene_exit = function(self)
    log_typecheck(self, SettingsScene_t)
end