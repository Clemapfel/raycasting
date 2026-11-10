SkinSelectScene_t = "SkinSelectScene"

SkinID = {
    DEFAULT = "DEFAULT",
    TOAST = "TOAST",
    LOVE_WHALE = "LOVE_WHALE",
    HATE_WHALE = "HATE_WHALE",
    NSFW = "NSFW"
}

local _skin_data = {
    [SkinID.DEFAULT] = {
        name = "Slime",
        path = "jam/assets/skins/slime.png",
        n_unlocks_required = 0
    },

    [SkinID.LOVE_WHALE] = {
        name = "Whale (Love)",
        path = "jam/assets/skins/love_whale.png",
        n_unlocks_required = 1
    },

    [SkinID.HATE_WHALE] = {
        name = "Whale (Hate)",
        path = "jam/assets/skins/hate_whale.png",
        n_unlocks_required = 3
    },

    [SkinID.TOAST] = {
        name = "Toast",
        path = "jam/assets/skins/toast.png",
        n_unlocks_required = 5
    },

    [SkinID.NSFW] = {
        name = "??? (nsfw)",
        path = "jam/assets/skins/nsfw.png",
        n_unlocks_required = 10
    }
}

local _skin_order = {
    SkinID.DEFAULT,
    SkinID.LOVE_WHALE,
    SkinID.HATE_WHALE,
    SkinID.TOAST,
    SkinID.NSFW
}

local _unlock_message = "(Beat %i Stage%s to unlock this Skin)"

local _settings_command_label_font_size = 80 / 800
local _question_mark_label_font_size = 350 / 800
local _settings_name_font_size = 40 / 800
local _settings_sub_message_font_size = 30 / 800
local _settings_softbody_radius = 128 / 800
local _settings_carousel_radius = 1000 / 800

local _skin_wheel_rotation_speed = 3
local _skin_wheel_min_scale = 0.5

skin_select_scene_new = function()
    return skin_select_scene_init(object_new(SkinSelectScene_t, {}))
end

skin_select_scene_init = function(self)
    log_typecheck(self, SkinSelectScene_t)

    self.bounds = aabb_new(0, 0, graphics_get_size())
    local native_h = graphics_get_height()

    local command_size = _settings_command_label_font_size * native_h
    self.command_label = label_set_is_wave(label_set_is_outlined(
        label_new("Select a Skin!", command_size, TextStyle.BOLD)
    ))

    self.left_label = label_set_is_wave(label_set_is_outlined(label_new(
        "<", 2 * command_size, TextStyle.BOLD
    )))

    self.right_label = label_set_is_wave(label_set_is_outlined(label_new(
        ">", 2 * command_size, TextStyle.BOLD
    )))

    self.selected_index = 1
    self.selection_lag = lag_new(1, _skin_wheel_rotation_speed)
    self.selection_position = 1
    self.selection_target = 1
    self.selection_is_animating = false

    self.entries = {}
    for _, id in ipairs(_skin_order) do
        local data = _skin_data[id]

        local body_radius = _settings_softbody_radius * native_h
        local body = player_new(0, 0, body_radius)
        local texture = texture_new(data.path)
        player_set_texture(body, texture)

        -- ground collision
        local x, y, w, h = -100, -100, 200, 200
        player_set_collision_contours(body, polyline_new(
            x + 0, y + 0,
            x + w, y + 0,
            x + w, y + h,
            x + 0, y + h
        ))

        local name_label = label_new(data.name, _settings_name_font_size * native_h, TextStyle.BOLD)
        local sub_message_label

        sub_message_label = label_new(
            string.format(_unlock_message, data.n_unlocks_required, data.n_unlocks_required > 1 and "s" or ""),
            _settings_sub_message_font_size * native_h
        )

        local questionmark_label = label_new("?", _question_mark_label_font_size * native_h, TextStyle.BOLD)

        for label in iter_varargs(name_label, sub_message_label, questionmark_label) do
            label_set_is_outlined(label, true)
        end

        label_set_is_wave(questionmark_label)

        table_push(self.entries, {
            body = body,
            body_x = 0,
            body_y = 0,
            body_radius = body_radius,
            texture = texture,
            questionmark_label = questionmark_label,
            name_label = name_label,
            sub_message_label = sub_message_label,
            n_unlocks_required = data.n_unlocks_required,
            x_offset = 0
        })
    end

    self.input_pressed_handler = input_connect_pressed(function(which)
        local scroll = function(direction)
            local target = lag_get_target_value(self.selection_lag) + direction
            lag_set_target_value(self.selection_lag, target)
            self.selected_index = ((target - 1) % #self.entries) + 1
            if direction == 1 then
                audio_replay_sound(self, SoundID.menu_swipe_left)
            else
                audio_replay_sound(self, SoundID.menu_swipe_right)
            end
        end

        if which == input_action_move_left then
            scroll(-1)
        elseif which == input_action_move_right then
            scroll(1)
        elseif which == input_action_accept then
            local current = self.entries[self.selected_index]
            audio_replay_sound(self, SoundID.menu_accept)
            state_set_active_skin(current.texture)
        end
    end, self.input_pressed_handler)

    return self
end

skin_select_scene_reformat = function(self, aabb_or_x, y, w, h)
    log_typecheck(self, SkinSelectScene_t)
    self.bounds = aabb_init(self.bounds, aabb_or_x, y, w, h)
    local bounds = self.bounds
    local outer_m = _global_outer_margin

    local content_x = bounds.x + outer_m
    local content_w = bounds.width - 2 * outer_m
    local center_x = bounds.x + 0.5 * bounds.width

    local command_w, command_h = label_get_size(self.command_label)
    local command_y = bounds.y + 1 / 4 * bounds.height - 0.5 * command_h
    label_set_justify_mode(self.command_label, JustifyMode.CENTER)
    label_reformat(self.command_label,
        content_x, command_y,
        content_w, 0
    )

    label_set_justify_mode(self.left_label, JustifyMode.LEFT)
    label_set_justify_mode(self.right_label, JustifyMode.RIGHT)

    local left_w, left_h = label_get_size(self.left_label)
    label_reformat(self.left_label,
        bounds.x + outer_m,
        bounds.y + outer_m,
        bounds.width - 2 * outer_m,
        bounds.height - 2 * outer_m
    )

    local right_w, right_h = label_get_size(self.right_label)
    label_reformat(self.right_label,
        bounds.x + outer_m,
        bounds.y + outer_m,
        bounds.width - 2 * outer_m,
        bounds.height - 2 * outer_m
    )

    local command_bottom = command_y + command_h

    for _, entry in ipairs(self.entries) do
        local name_w, name_h = label_get_size(entry.name_label)
        local sub_w, sub_h = label_get_size(entry.sub_message_label)

        local sub_y = bounds.y + bounds.height - outer_m - sub_h
        label_set_justify_mode(entry.sub_message_label, JustifyMode.CENTER)
        label_reformat(entry.sub_message_label, content_x, sub_y, content_w, 0)

        local name_y = sub_y - name_h
        label_set_justify_mode(entry.name_label, JustifyMode.CENTER)
        label_reformat(entry.name_label, content_x, name_y, content_w, 0)

        local center_y = 0.5 * (command_bottom + name_y)
        entry.body_x = bounds.x + 0.5 * bounds.width
        entry.body_y = bounds.y + 0.5 * bounds.height

        local _, question_h = label_get_size(entry.questionmark_label)
        label_set_justify_mode(entry.questionmark_label, JustifyMode.CENTER)
        label_reformat(entry.questionmark_label,
            bounds.x, bounds.y, bounds.width, bounds.height
        )
    end
end

skin_select_scene_update = function(self, delta)
    log_typecheck(self, SkinSelectScene_t)

    lag_update(self.selection_lag, delta)

    local n_completed = state_get_n_levels_completed()
    if self.selection_is_animating then
        local distance = self.selection_target - self.selection_position
        local step = _skin_wheel_rotation_speed * delta
        if math.abs(distance) <= step then
            self.selection_position = self.selection_target
            self.selection_is_animating = false
        else
            self.selection_position = self.selection_position + (distance > 0 and step or -step)
        end
    end

    label_update(self.command_label, delta)
    label_update(self.left_label, delta)
    label_update(self.right_label, delta)

    for _, entry in ipairs(self.entries) do
        if n_completed < entry.n_unlocks_required then
            label_update(entry.questionmark_label, delta)
            label_update(entry.sub_message_label, delta)
        else
            player_update(entry.body, delta)
        end

        label_update(entry.name_label, delta)
    end
end

skin_select_scene_draw = function(self)
    log_typecheck(self, SkinSelectScene_t)

    local n_completed = state_get_n_levels_completed()
    label_draw(self.command_label)

    local n_entries = #self.entries
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
        local scale = _skin_wheel_min_scale + (1 - _skin_wheel_min_scale) * (item.depth + 1) / 2

        if n_completed >= entry.n_unlocks_required then
            graphics_push_transform()
            graphics_set_translation(entry.body_x + offset_x, entry.body_y)
            graphics_set_scale(scale, scale)
            player_draw(entry.body)
            graphics_pop_transform()
        end

        graphics_push_transform()
        graphics_set_translation(
            entry.body_x + offset_x - scale * entry.body_x,
            entry.body_y - scale * entry.body_y
        )
        graphics_set_scale(scale, scale)
        if n_completed < entry.n_unlocks_required then
            label_draw(entry.questionmark_label)
            label_draw(entry.sub_message_label)
        end
        label_draw(entry.name_label)
        graphics_pop_transform()
    end

    label_draw(self.left_label)
    label_draw(self.right_label)
end