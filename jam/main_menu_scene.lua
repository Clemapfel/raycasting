MainMenuScene_t = "MainMenuScene"

local _item_id_new_game = "new_game"
local _item_id_choose_skin = "choose_skin"
local _item_id_stage_select = "stage_select"
local _item_id_settings = "settings"
local _item_id_quit = "quit"

local _settings_labels = {
    [_item_id_new_game] = "New Game",
    [_item_id_choose_skin] = "Choose Skin",
    [_item_id_stage_select] = "Select Stage",
    [_item_id_settings] = "Settings",
    [_item_id_quit] = "Quit"
}

local _settings_labels_in_order = {
    _item_id_new_game,
    _item_id_choose_skin,
    _item_id_stage_select,
    _item_id_settings,
    -- _item_id_quit
}

local _settings_menu_font_size = 40 / 800
local _settings_credits_font_size = 18 / 800
local _settings_title_texture = "assets/barboach.png"

main_menu_scene_new = function()
    return main_menu_scene_init(object_new(MainMenuScene_t, {
        is_active = false
    }))
end

main_menu_scene_init = function(self)
    local w, h = graphics_get_size()
    self.bounds = aabb_new(0, 0, w, h)

    local label_max_h = math_negative_inf
    local native_h = graphics_get_height()

    self.selected_i = 1
    self.n_labels = 0
    self.menu_label_entries = {}
    for i, key in ipairs(_settings_labels_in_order) do
        local unselected = label_new(_settings_labels[key], _settings_menu_font_size * native_h, TextStyle.BOLD)
        local selected = label_new(_settings_labels[key], _settings_menu_font_size * native_h, TextStyle.BOLD)

        label_set_is_rainbow(selected, true)
        label_set_is_wave(selected, true)
        label_set_is_outlined(unselected, true)
        label_set_is_outlined(selected, true)

        table_push(self.menu_label_entries, {
            unselected_label = unselected,
            selected_label = selected
        })

        label_max_h = math_max(
            label_max_h,
            label_get_height(unselected),
            label_get_height(selected)
        )

        self.n_labels = self.n_labels + 1
    end

    self.menu_label_height = label_max_h

    self.title_texture = texture_new(_settings_title_texture)
    self.credits_label = label_new("By: Clem (github.com/clemapfel)", _settings_credits_font_size * native_h, TextStyle.MONO)
    self.date_label = label_new("Love2D Jam 2026 [B-Side]", _settings_credits_font_size * native_h, TextStyle.MONO)

    label_set_is_outlined(self.credits_label, true)
    label_set_is_outlined(self.date_label, true)

    -- input

    input_disconnect_pressed(self.pressed_handler)
    self.pressed_handler = input_connect_pressed(function(which)
        if state_get_scene_is_active(STATE, self) ~= true then return end

        if which == input_action_move_up then
            if self.selected_i > 1 then
                self.selected_i = self.selected_i - 1
                audio_play_sound(self, SoundID.menu_up)
            end
        elseif which == input_action_move_down then
            if self.selected_i < self.n_labels then
                self.selected_i = self.selected_i + 1
                audio_play_sound(self, SoundID.menu_down)
            end
        elseif which == input_action_accept then
            local id = _settings_labels_in_order[self.selected_i]
            audio_play_sound(self, SoundID.menu_accept)

            if id == _item_id_new_game then
                local level_ids = state_get_level_ids(STATE)
                if #level_ids > 0 then
                    state_push_scene(STATE, SkinSelectScene_t, level_ids[1]) -- queue stage after
                end
            elseif id == _item_id_stage_select then
                state_push_scene(STATE, StageSelectScene_t)
            elseif id == _item_id_choose_skin then
                state_push_scene(STATE, SkinSelectScene_t)
            elseif id == _item_id_settings then
                state_push_scene(STATE, SettingsScene_t)
            end
        end
    end, self.pressed_handler)

    self.control_indicator = control_indicator_new(
        input_action_move_up, "Up",
        input_action_move_down, "Down",
        input_action_accept, "Select"
    )

    -- layout
    main_menu_scene_reformat(self, 0, 0, graphics_get_size())
    return self
end

main_menu_scene_reformat = function(self, aabb_or_x, y, w, h)
    local bounds = aabb_init(self.bounds, aabb_or_x, y, w, h)

    -- reformat
    local m = _global_margin_unit
    local outer_m = _global_outer_margin
    local label_h = self.menu_label_height + m

    local current_x = bounds.x
    local current_y = bounds.y + bounds.height - outer_m - self.n_labels * label_h

    for i = 1, self.n_labels do
        local entry = self.menu_label_entries[i]

        label_set_justify_mode(entry.selected_label, JustifyMode.CENTER)
        label_reformat(entry.selected_label,
            current_x, current_y, bounds.width, 0
        )

        label_set_justify_mode(entry.unselected_label, JustifyMode.CENTER)
        label_reformat(entry.unselected_label,
            current_x, current_y, bounds.width, 0
        )

        current_y = current_y + label_h
    end

    local credits_w, credits_h = label_get_size(self.credits_label)
    local padding = 0.25 * outer_m
    local sub_bounds = aabb_new(
        bounds.x + padding,
        bounds.y + padding,
        bounds.width - 2 * padding,
        credits_h
    )

    label_set_justify_mode(self.credits_label, JustifyMode.LEFT)
    label_reformat(self.credits_label, sub_bounds)

    local date_w, date_h = label_get_size(self.date_label)
    label_set_justify_mode(self.date_label, JustifyMode.RIGHT)
    label_reformat(self.date_label, sub_bounds)
end

main_menu_scene_update = function(self, delta)
    log_typecheck(self, MainMenuScene_t, delta, Number_t)

    for _, entry in ipairs(self.menu_label_entries) do
        label_update(entry.selected_label, delta)
        label_update(entry.unselected_label, delta)
    end

    label_update(self.credits_label, delta)
    control_indicator_update(self.control_indicator, delta)
end

main_menu_scene_draw = function(self)
    log_typecheck(self, MainMenuScene_t)

    for entry_i, entry in ipairs(self.menu_label_entries) do
        if entry_i == self.selected_i then
            label_draw(entry.selected_label)
        else
            label_draw(entry.unselected_label)
        end
    end

    label_draw(self.credits_label)
    label_draw(self.date_label)
end

main_menu_scene_get_control_indicator = function(self)
    log_typecheck(self, MainMenuScene_t)
    return self.control_indicator
end

main_menu_scene_enter = function(self)
    log_typecheck(self, MainMenuScene_t)
end

main_menu_scene_exit = function(self)
    log_typecheck(self, MainMenuScene_t)
end
