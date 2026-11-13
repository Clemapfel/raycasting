StageScene_t = "StageScene"

local _settings_player_angular_velocity = math_tau -- radians / s
local _settings_player_linear_velocity = 1000
local _settings_jump_impulse = 3000
local _settings_player_gravity = 1000

local _item_id_unpause = "unpause"
local _item_id_respawn = "respawn"
local _item_id_stage_select = "stage_select"
local _item_id_exit = "exit"

local _settings_pause_menu_labels = {
    [_item_id_unpause] = "Unpause",
    [_item_id_respawn] = "Respawn",
    [_item_id_stage_select] = "Stage Select",
    [_item_id_exit] = "Exit"
}

local _settings_pause_menu_labels_in_order = {
    _item_id_unpause,
    _item_id_respawn,
    _item_id_stage_select,
    _item_id_exit
}

local _settings_pause_menu_font_size = 40 / 800

local _set_is_paused = function(self, b)
    if self.pause_active ~= b then
        self.pause_active = b
    end
end

stage_scene_new = function()
    return stage_scene_init(object_new(StageScene_t, {
        stage = nil,
        stage_id = nil,
        players = {},
        pause_active = false,

        mouse_handler = nil,
        pressed_handler = nil
    }))
end

stage_scene_init = function(self)
    log_typecheck(self, StageScene_t)

    -- pause menu

    local w, h = graphics_get_size()
    self.bounds = aabb_new(0, 0, w, h)

    local label_max_h = math_negative_inf
    local native_h = graphics_get_height()

    self.pause_selected_i = 1
    self.n_pause_entries = 0
    self.pause_entries = {}
    for i, id in ipairs(_settings_pause_menu_labels_in_order) do
        local unselected = label_new(_settings_pause_menu_labels[id], _settings_pause_menu_font_size * native_h, TextStyle.BOLD)
        local selected = label_new(_settings_pause_menu_labels[id], _settings_pause_menu_font_size * native_h, TextStyle.BOLD)

        label_set_is_rainbow(selected, true)
        label_set_is_wave(selected, true)
        label_set_is_outlined(unselected, true)
        label_set_is_outlined(selected, true)

        table_push(self.pause_entries, {
            id = id,
            unselected_label = unselected,
            selected_label = selected
        })

        label_max_h = math_max(
            label_max_h,
            label_get_height(unselected),
            label_get_height(selected)
        )

        self.n_pause_entries = self.n_pause_entries + 1
    end

    self.pause_menu_label_height = label_max_h

    -- control indicator
    self.gameplay_control_indicator = control_indicator_new(
        input_action_move_up, "Move Up",
        input_action_move_left, "Move Left",
        input_action_move_down, "Move Down",
        input_action_move_right, "Move Right",
        input_action_jump, "Jump",
        input_action_become_liquid, "Liquify",
        input_action_reset, "Reset Stage",
        "Mouse", "Select Player",
        input_action_pause, "Pause"
    )

    self.pause_control_indicator = control_indicator_new(
        input_action_move_up, "Move Up",
        input_action_move_down, "Move Down",
        input_action_accept, "Select",
        input_action_pause, "Unpause"
    )

    -- proxies for player requests

    self.input_action_to_proxy = {}
    for action in iter_varargs(
        input_action_move_up,
        input_action_move_left,
        input_action_move_down,
        input_action_move_right,
        input_action_jump,
        input_action_become_liquid,
        input_action_become_solid,
        input_action_pause,
        input_action_reset,
        "Mouse"
    ) do
        self.input_action_to_proxy[action] = {}
    end

    input_disconnect_pressed(self.pressed_handler)
    self.pressed_handler = input_connect_pressed(function(which)
        if state_get_scene_is_active(STATE, self) ~= true then return end

        if self.pause_active then
            if which == input_action_move_up then
                self.pause_selected_i = math.max(1, self.pause_selected_i - 1)
            elseif which == input_action_move_down then
                self.pause_selected_i = math.min(self.n_pause_entries, self.pause_selected_i + 1)
            elseif which == input_action_pause then
                _set_is_paused(self, false)
            elseif which == input_action_accept then
                local id = self.pause_entries[self.pause_selected_i].id
                if id == _item_id_unpause then
                    _set_is_paused(self, false)
                elseif id == _item_id_respawn then
                    stage_scene_reset(self)
                    _set_is_paused(self, false)
                elseif id == _item_id_stage_select then
                    state_set_scene(STATE, StageSelectScene_t)
                elseif id == _item_id_exit then
                    state_set_scene(STATE, MainMenuScene_t)
                end
            end
        else
            local active = stage_scene_get_active_players(self)
            if which == input_action_accept then
                for player in iter_values(self.players) do
                    if player_get_is_clickable(player) then
                        player_set_is_active(player, not player_get_is_active(player))
                    end
                end
            elseif which == input_action_move_left then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which],
                    -1 * _settings_player_linear_velocity, 0
                )
            elseif which == input_action_move_right then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which],
                    1 * _settings_player_linear_velocity, 0
                )
            elseif which == input_action_move_up then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which],
                    0, -1 * _settings_player_linear_velocity
                )
            elseif which == input_action_move_down then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which],
                    0, 1 * _settings_player_linear_velocity
                )
            elseif which == input_action_jump then
                iter_map(active, player_apply_linear_impulse,
                    0, -1 * _settings_jump_impulse
                )
            elseif which == input_action_become_liquid then
                iter_map(active, player_request_constraint_mode, self.input_action_to_proxy[which],
                    SoftbodyConstraintMode.LIQUID
                )
            elseif which == input_action_pause then
                _set_is_paused(self, true)
            end
        end
    end)

    input_disconnect_pressed(self.released_handler)
    self.released_handler = input_connect_released(function(which)
        if state_get_scene_is_active(STATE, self) ~= true then return end

        if not self.pause_active then
            local active = stage_scene_get_active_players(self)
            if which == input_action_accept then
                -- noop
            elseif which == input_action_move_left then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which], nil)
            elseif which == input_action_move_right then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which], nil)
            elseif which == input_action_move_up then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which], nil)
            elseif which == input_action_move_down then
                iter_map(active, player_request_linear_velocity, self.input_action_to_proxy[which], nil)
            elseif which == input_action_become_liquid then
                iter_map(active, player_request_constraint_mode, self.input_action_to_proxy[which], nil)
            end
        end
    end)

    input_disconnect_cursor_moved(self.mouse_handler)
    self.mouse_handler = input_connect_cursor_moved(function(mouse_x, mouse_y)
        local active_player = nil
        for i, player in ipairs(self.players) do
            if polyline_test_point(player_get_player_collision_contour(player), mouse_x, mouse_y)
                and active_player == nil
            then
                active_player = player
            else
                player_set_is_clickable(player, false)
            end
        end

        if active_player ~= nil then
            player_set_is_clickable(active_player, true)
            cursor_set_type(CursorType.CAN_CLICK)
        else
            cursor_set_type(CursorType.DEFAULT)
        end
    end)

    stage_scene_reformat(self, 0, 0, graphics_get_size())
    return self
end

stage_scene_reformat = function(self, aabb_or_x, y, w, h)
    local bounds = aabb_init(self.bounds, aabb_or_x, y, w, h)

    local m = _global_margin_unit
    local label_h = self.pause_menu_label_height + m

    local total_h = self.n_pause_entries * label_h - m
    local current_x = bounds.x
    local current_y = bounds.y + 0.5 * bounds.height - 0.5 * total_h + 0.5 * self.pause_menu_label_height

    for i = 1, self.n_pause_entries do
        local entry = self.pause_entries[i]

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
end

stage_scene_update = function(self, delta)
    log_typecheck(self, StageScene_t, delta, Number_t)

    local stage_contours = {}
    for _, contour in ipairs(stage_get_hitbox_collision_contours(self.stage)) do
        table_push(stage_contours, contour)
    end

    local player_contours = {}
    for _, player in ipairs(self.players) do
        table_push(player_contours, player_get_player_collision_contour(player))
    end

    for self_i, player in ipairs(self.players) do

        -- collect contours by reference
        local contours = {}
        for _, stage_contour in ipairs(stage_contours) do
            table_push(contours, stage_contour)
        end

        for other_i, player_contour in ipairs(player_contours) do
            if self_i ~= other_i then
                table_push(contours, player_contour)
            end
        end

        player_set_collision_contours(player, contours)
    end

    -- update after contour notification
    for _, player in ipairs(self.players) do
        player_update(player, delta)
    end
    stage_update(self.stage, delta)

    for _, entry in ipairs(self.pause_entries) do
        label_update(entry.selected_label, delta)
        label_update(entry.unselected_label, delta)
    end

    return self
end

stage_scene_draw = function(self)
    log_typecheck(self, StageScene_t)

    stage_draw(self.stage)
    for _, player in ipairs(self.players) do
        player_draw(player)
    end

    if self.pause_menu_overlay_color == nil then
        self.pause_menu_overlay_color = object_set(object_copy(palette_black), "a", 0.2)
    end

    if self.pause_active then
        rgba_bind(palette_black)
        graphics_draw_rectangle(0, 0, graphics_get_width())

        rgba_bind(palette_true_white)
        for entry_i, entry in ipairs(self.pause_entries) do
            if entry_i == self.pause_selected_i then
                label_draw(entry.selected_label)
            else
                label_draw(entry.unselected_label)
            end
        end
    end

    return self
end

stage_scene_get_active_players = function(self)
    log_typecheck(self, StageScene_t)
    local result = {}
    for player in iter_values(self.players) do
        if player_get_is_active(player) then
            table_push(result, player)
        end
    end
    return result
end

stage_scene_enter = function(self, level_id)
    log_typecheck(self, StageScene_t, level_id, String_t)
    self.id = level_id
    stage_scene_reset(self)
    _set_is_paused(self, false)
end

stage_scene_exit = function(self)
    log_typecheck(self, StageScene_t)
end

stage_scene_reset = function(self)
    self.stage = state_get_stage(STATE, self.id)
    local spawn_points = stage_get_spawn_points(self.stage)

    if table_sizeof(spawn_points) < 1 then
        log_error("In stage_scene_reset: stage `", self.id, "` does not have a spawn point")
        return
    end

    for i = 1, table_sizeof(spawn_points) do
        local spawn_point = spawn_points[i]
        local x, y, r = spawn_point.x, spawn_point.y, spawn_point.radius
        if self.players[i] ~= nil then
            player_init(self.players[i], x, y, r)
        else
            self.players[i] = player_new(x, y, r)
        end

        player_set_gravity(self.players[i], 0 * _settings_player_gravity, 1 * _settings_player_gravity)
        player_set_texture(self.players[i], state_get_player_skin(STATE))
    end

    player_set_is_active(self.players[1], true)
    stage_reset(self.stage)
end

stage_scene_get_control_indicator = function(self)
    log_typecheck(self, StageScene_t)
    if self.pause_active then
        return self.pause_control_indicator, self.gameplay_control_indicator
    else
        return self.gameplay_control_indicator, self.pause_control_indicator
    end
end