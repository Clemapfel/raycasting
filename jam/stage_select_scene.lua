StageSelectScene_t = "StageSelectScene"

local _settings_command_label_font_size = 80 / 800
local _settings_stage_name_font_size = 60 / 800
local _settings_beaten_font_size = 30 / 800
local _settings_thumbnail_line_width = 3 / 800
local _settings_carousel_radius = 2000 / 800
local _settings_stage_progress_bar_height = 24 / 800

local _stage_wheel_rotation_speed = 1.5
local _stage_wheel_min_scale = 1

stage_select_scene_new = function(stage_list)
    log_typecheck(stage_list, StageList_t)
    return stage_select_scene_init(object_new(StageSelectScene_t, {
    }), stage_list)
end

stage_select_scene_init = function(self, stage_list)
    log_typecheck(self, StageSelectScene_t, stage_list, StageList_t)

    self.stage_list = stage_list
    self.bounds = aabb_new(0, 0, graphics_get_size())
    self.entries = {}
    self.n_entries = 0
    self.elapsed = 0

    local native_h = graphics_get_height()
    local command_size = _settings_command_label_font_size * native_h
    self.command_label = label_set_is_wave(label_set_is_outlined(
        label_new("Select Stage", command_size, TextStyle.BOLD)
    ))

    self.left_label = label_set_is_wave(label_set_is_outlined(label_new(
        "<", 2 * command_size, TextStyle.BOLD
    )))

    self.right_label = label_set_is_wave(label_set_is_outlined(label_new(
        ">", 2 * command_size, TextStyle.BOLD
    )))

    self.left_right_enabled_color = rgba_new(1, 1, 1, 1)
    self.left_right_disabled_color = rgba_new(1, 1, 1, 0)
    self.progress_outline_color = rgba_new(0, 0, 0, 1)

    local ids = stage_list_get_ids(stage_list)
    for _, id in ipairs(ids) do
        local stage = state_get_stage(id)
        local name_label = label_new(
            stage_get_name(stage),
            _settings_stage_name_font_size * native_h,
            TextStyle.BOLD
        )
        label_set_is_outlined(name_label, true)

        local beaten_label = label_set_is_wave(label_set_is_rainbow(
            label_set_is_outlined(label_new(
                "(beaten)", _settings_beaten_font_size * native_h, TextStyle.BOLD
            ))
        ))

        local not_beaten_label = label_set_is_outlined(label_new(
            "(not beaten)", _settings_beaten_font_size * native_h, TextStyle.BOLD
        ))

        table_push(self.entries, {
            id = id,
            stage = stage,
            color = nil,

            name_label = name_label,
            name_y = 0,

            beaten_label = beaten_label,
            not_beaten_label = not_beaten_label,
            beaten_y = 0,

            thumbnail_x = 0,
            thumbnail_y = 0,
            thumbnail_scale = 1,
            stage_center_x = 0,
            stage_center_y = 0,

            draw_contours = {}, -- Table<Polyline>
            draw_bounds = nil, -- AABB
            draw_meshes = nil, -- Table<Mesh>
        })

        self.n_entries = self.n_entries + 1
    end

    for i, entry in ipairs(self.entries) do
        local hue = (i - 1) / self.n_entries
        entry.color = lcha_to_rgba(0.8, 1, hue, 1)
    end

    self.selected_entry_i = 1
    self.selection_lag = lag_new(1, _stage_wheel_rotation_speed)

    stage_select_scene_reformat(self, self.bounds)

    self.input_pressed_handler = input_connect_pressed(function(which)
        local scroll = function(direction)
            local target = lag_get_target_value(self.selection_lag) + direction
            if target >= 1 and target <= self.n_entries then
                lag_set_target_value(self.selection_lag, target)
                self.selected_entry_i = target
                if direction == 1 then
                    audio_replay_sound(self, SoundID.menu_swipe_left)
                else
                    audio_replay_sound(self, SoundID.menu_swipe_right)
                end

                self.elapsed = 0
            end
        end

        if which == input_action_move_left then
            scroll(-1)
        elseif which == input_action_move_right then
            scroll(1)
        end
    end, self.input_pressed_handler)

    return self
end

stage_select_scene_reformat = function(self, bounds)
    log_typecheck(self, StageSelectScene_t)

    self.bounds = bounds
    local outer_m = _global_outer_margin

    local content_x = bounds.x + outer_m
    local content_w = bounds.width - 2 * outer_m
    local center_x = bounds.x + 0.5 * bounds.width
    local center_y = bounds.y + 0.5 * bounds.height

    local command_h = label_get_height(self.command_label)
    local command_y = bounds.y + 1 / 5 * bounds.height - 0.5 * command_h
    label_set_justify_mode(self.command_label, JustifyMode.CENTER)
    label_reformat(self.command_label,
        content_x, command_y,
        content_w, 0
    )

    label_set_justify_mode(self.left_label, JustifyMode.LEFT)
    label_set_justify_mode(self.right_label, JustifyMode.RIGHT)
    label_reformat(self.left_label,
        bounds.x + outer_m, bounds.y + outer_m,
        bounds.width - 2 * outer_m, bounds.height - 2 * outer_m
    )
    label_reformat(self.right_label,
        bounds.x + outer_m, bounds.y + outer_m,
        bounds.width - 2 * outer_m, bounds.height - 2 * outer_m
    )

    local max_thumbnail_w = bounds.width - label_get_width(self.left_label) - label_get_width(self.left_label)

    for _, entry in ipairs(self.entries) do
        local stage = entry.stage
        local stage_bounds = stage_get_bounds(stage)
        local stage_w = stage_bounds.width
        local stage_h = stage_bounds.height

        entry.draw_contours = {}
        for contour in iter_values(stage_get_hitbox_collision_contours(stage)) do
            table_push(entry.draw_contours, contour)
        end

        local draw_contours = stage_get_draw_contours(stage)
        local draw_meshes = stage_get_draw_meshes(stage)

        entry.draw_bounds = stage_bounds
        entry.draw_meshes = {}
        for i = 1, math.min(table_sizeof(draw_contours), table_sizeof(draw_meshes)) do
            table_push(entry.draw_meshes, draw_meshes[i])
        end

        local name_h = label_get_height(entry.name_label)
        local beaten_h = label_get_height(entry.beaten_label)
        local not_beaten_h = label_get_height(entry.not_beaten_label)
        local status_h = math.max(beaten_h, not_beaten_h)

        entry.beaten_y = bounds.y + bounds.height - outer_m - status_h
        entry.name_y = entry.beaten_y - beaten_h

        label_set_justify_mode(entry.name_label, JustifyMode.CENTER)
        label_reformat(entry.name_label, content_x, entry.name_y, content_w, 0)

        label_set_justify_mode(entry.beaten_label, JustifyMode.CENTER)
        label_reformat(entry.beaten_label, content_x, entry.beaten_y, content_w, 0)

        label_set_justify_mode(entry.not_beaten_label, JustifyMode.CENTER)
        label_reformat(entry.not_beaten_label, content_x, entry.beaten_y, content_w, 0)

        entry.thumbnail_x = center_x
        entry.thumbnail_y = center_y
        entry.stage_center_x = stage_bounds.x + 0.5 * stage_w
        entry.stage_center_y = stage_bounds.y + 0.5 * stage_h

        local max_thumbnail_h = math.max(0, bounds.height - 2 * outer_m - command_h - name_h - beaten_h - 2 * outer_m)

        if stage_w > 0 and stage_h > 0 and max_thumbnail_w > 0 and max_thumbnail_h > 0 then
            entry.thumbnail_scale = math.min(
                max_thumbnail_w / stage_w,
                max_thumbnail_h / stage_h
            )
        else
            entry.thumbnail_scale = 1
        end
    end
end

stage_select_scene_update = function(self, delta)
    log_typecheck(self, StageSelectScene_t)

    self.elapsed = self.elapsed + delta

    lag_update(self.selection_lag, delta)
    label_update(self.command_label, delta)
    label_update(self.left_label, delta)
    label_update(self.right_label, delta)

    for _, entry in ipairs(self.entries) do
        label_update(entry.name_label, delta)
        label_update(entry.beaten_label, delta)
        label_update(entry.not_beaten_label, delta)
    end
end

stage_select_scene_draw = function(self)
    log_typecheck(self, StageSelectScene_t)

    graphics_set_color(1, 1, 1, 1)
    label_draw(self.command_label)

    local line_w = _settings_thumbnail_line_width * graphics_get_height()
    local n_entries = self.n_entries
    local wheel_radius = _settings_carousel_radius * graphics_get_height()
    local selection_position = lag_get_value(self.selection_lag)

    local draw_entries = {}
    for i, entry in ipairs(self.entries) do
        local relative = i - selection_position
        relative = (math_fract(relative / n_entries + 0.5) - 0.5) * n_entries
        local angle = relative * (math_tau / n_entries)
        local depth = math.cos(angle)

        if depth >= 0 then
            table_push(draw_entries, {
                entry = entry,
                angle = angle,
                depth = depth
            })
        end
    end

    table.sort(draw_entries, function(a, b)
        return a.depth < b.depth
    end)

    for _, item in ipairs(draw_entries) do
        local entry = item.entry
        local offset_x = math.sin(item.angle) * wheel_radius
        local scale = _stage_wheel_min_scale + (1 - _stage_wheel_min_scale) * (item.depth + 1) / 2
        local thumbnail_scale = entry.thumbnail_scale * scale

        graphics_push_transform()
        graphics_translate(
            entry.thumbnail_x + offset_x - thumbnail_scale * entry.stage_center_x,
            entry.thumbnail_y - thumbnail_scale * entry.stage_center_y
        )
        graphics_set_scale(thumbnail_scale, thumbnail_scale)

        graphics_set_line_state(line_w + 1.5)
        rgba_bind(entry.color)
        aabb_draw(entry.draw_bounds)

        rgba_bind(palette_dark_gray)
        for _, mesh in ipairs(entry.draw_meshes) do
            mesh_draw(mesh)
        end
        graphics_pop_transform()

        graphics_push_transform()
        rgba_bind(palette_true_white)
        local bounds = self.bounds
        local center_x = bounds.x + 0.5 * bounds.width
        graphics_translate(
            center_x + offset_x - scale * center_x,
            entry.name_y - scale * entry.name_y
        )

        label_draw(entry.name_label)
        if state_get_stage_is_completed(entry.id) then
            --label_draw(entry.beaten_label)
        else
            --label_draw(entry.not_beaten_label)
        end

        graphics_pop_transform()
    end

    if self.selected_entry_i >= 1 then
        rgba_bind(self.left_right_enabled_color)
    else
        rgba_bind(self.left_right_disabled_color)
    end
    label_draw(self.left_label)

    if self.selected_entry_i <= self.n_entries then
        rgba_bind(self.left_right_enabled_color)
    else
        rgba_bind(self.left_right_disabled_color)
    end
    label_draw(self.right_label)

    local bounds = self.bounds
    if n_entries > 0 then
        local n_segments = 24
        local function make_circle_contour(radius, segments)
            local points = {}
            for i = 1, segments + 1 do
                local angle = ((i - 1) / segments) * math_tau
                table_push(points, radius * math_cos(angle))
                table_push(points, radius * math_sin(angle))
            end
            return points
        end

        local radius = 0.5 * _settings_stage_progress_bar_height * graphics_get_height()
        local spacing = 3 * radius
        local center_x = bounds.x + 0.5 * bounds.width
        local line_width = 3

        local first_entry = self.entries[1]
        local beaten_h = label_get_height(first_entry.beaten_label)
        local not_beaten_h = label_get_height(first_entry.not_beaten_label)
        local status_h = math.max(beaten_h, not_beaten_h)
        local center_y = first_entry.beaten_y + 0.5 * status_h

        local contour = make_circle_contour(radius, n_segments)

        for i, entry in ipairs(self.entries) do
            local x = center_x + (i - 0.5 * (n_entries + 1)) * spacing

            graphics_push_transform()
            graphics_translate(x, center_y)

            if i == self.selected_entry_i then
                local t = (1.5 * self.elapsed) % 1
                graphics_translate(0, 0.5 * radius + -2 * t * (1 - t) * radius)
            end

            rgba_bind(palette_gray)
            graphics_draw_polygon("fill", table_unpack(contour))

            if state_get_stage_is_completed(entry.id) then
                rgba_bind(entry.color)
                graphics_draw_polygon("fill", table_unpack(contour))
            end

            graphics_set_line_state(line_width + 1.5)
            rgba_bind(palette_black)
            graphics_draw_line(contour)

            graphics_set_line_state(line_width)
            rgba_bind(palette_white)
            graphics_draw_line(contour)

            graphics_pop_transform()
        end
    end
end