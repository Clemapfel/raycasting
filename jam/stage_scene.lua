StageScene_t = "StageScene"

local _settings_player_angular_velocity = math_tau -- radians / s
local _settings_player_linear_velocity = 100

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

stage_scene_new = function(stage)
    local res = object_new(StageScene_t, {
        stage = stage,
        players = {},
        pause_menu_visible = false,

        mouse_handler = nil,
        pressed_handler = nil
    })

    if stage ~= nil then
        log_typecheck(stage, Stage_t)
        return stage_scene_init(res)
    else
        return res
    end
end

stage_scene_init = function(self)
    log_typecheck(self, StageScene_t)

    -- pause

    local w, h = graphics_get_size()
    self.bounds = aabb_new(0, 0, w, h)

    local label_max_h = math_negative_inf
    local native_h = graphics_get_height()

    self.selected_i = 1
    self.n_labels = 0
    self.menu_label_entries = {}
    for i, key in ipairs(_settings_pause_menu_labels_in_order) do
        local unselected = label_new(_settings_pause_menu_labels[key], _settings_pause_menu_font_size * native_h, TextStyle.BOLD)
        local selected = label_new(_settings_pause_menu_labels[key], _settings_pause_menu_font_size * native_h, TextStyle.BOLD)

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

    -- proxies for player requests
    self.left_move_proxy, self.right_move_proxy, self.up_move_proxy, self.down_move_proxy = {}, {}, {}, {}

    input_disconnect_pressed(self.pressed_handler)
    self.pressed_handler = input_connect_pressed(function(which)
        if state_get_scene_is_active(STATE, self) ~= true then return end

        local active = stage_scene_get_active_players(self)
        if which == input_action_accept then
            -- on click: select player
            for player in iter_values(self.players) do
                if player_get_is_clickable(player) then
                    player_set_is_active(player, not player_get_is_active(player))
                end
            end
        elseif which == input_action_move_left then
            iter_map(active, player_request_angular_velocity, self.left_move_proxy, -1 * _settings_player_angular_velocity)
            iter_map(active, player_request_linear_velocity, self.left_move_proxy, -1 * _settings_player_linear_velocity, 0)
        elseif which == input_action_move_right then
            iter_map(active, player_request_angular_velocity, self.right_move_proxy, _settings_player_angular_velocity)
            iter_map(active, player_request_linear_velocity, self.right_move_proxy, 1 * _settings_player_linear_velocity, 0)
        end
    end)

    input_disconnect_released(self.released_handler)
    self.released_handler = input_connect_released(function(which)
        local active = stage_scene_get_active_players(self)

        -- remove requests
        if which == input_action_move_left then
            iter_map(active, player_request_angular_velocity, self.left_move_proxy, nil)
            iter_map(active, player_request_linear_velocity, self.left_move_proxy, nil)
        elseif which == input_action_move_right then
            iter_map(active, player_request_angular_velocity, self.right_move_proxy, nil)
            iter_map(active, player_request_linear_velocity, self.right_move_proxy, nil)
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

    player_set_is_active(self.players[1], true)

    stage_scene_reformat(self, 0, 0, graphics_get_size())
    return self
end

stage_scene_reformat = function(self, aabb_or_x, y, w, h)
    local bounds = aabb_init(self.bounds, aabb_or_x, y, w, h)

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

    for _, entry in ipairs(self.menu_label_entries) do
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

    if self.pause_menu_visible then
        for entry_i, entry in ipairs(self.menu_label_entries) do
            if entry_i == self.selected_i then
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

stage_scene_set_pause_menu_visible = function(self, is_visible)
    log_typecheck(self, StageScene_t)
    self.pause_menu_visible = is_visible
    return self
end

stage_scene_enter = function(self, level_id)
    log_typecheck(self, StageScene_t, level_id, String_t)
    self.stage = state_get_stage(STATE, level_id)
    local spawn_points = stage_get_spawn_points(self.stage)
    for i = 1, table_sizeof(spawn_points) do
        local spawn_point = spawn_points[i]
        local x, y, r = spawn_point.x, spawn_point.y, spawn_point.radius
        if self.players[i] ~= nil then
            player_init(self.players[i], x, y, r)
        else
            self.players[i] = player_new(x, y, r)
        end
    end

    stage_reset(self.stage)
end

stage_scene_exit = function(self)
    log_typecheck(self, StageScene_t)
end
