LevelScene_t = "LevelScene"

local _settings_player_angular_velocity = math_tau -- radians / s
local _settings_player_linear_velocity = 100

level_scene_new = function(stage)
    local res = object_new(LevelScene_t, {
        stage = stage,
        players = {},

        mouse_handler = nil,
        pressed_handler = nil
    })

    if stage ~= nil then
        log_typecheck(stage, Stage_t)
        return level_scene_init(res)
    else
        return res
    end
end

level_scene_init = function(self)
    log_typecheck(self, LevelScene_t)

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

    -- proxies for player requests
    self.left_move_proxy, self.right_move_proxy, self.up_move_proxy, self.down_move_proxy = {}, {}, {}, {}

    input_disconnect_pressed(self.pressed_handler)
    self.pressed_handler = input_connect_pressed(function(which)
        local active = level_scene_get_active_players(self)
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
        local active = level_scene_get_active_players(self)

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
    return self
end

level_scene_update = function(self, delta)
    log_typecheck(self, LevelScene_t, delta, Number_t)

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

    return self
end

level_scene_draw = function(self)
    log_typecheck(self, LevelScene_t)

    stage_draw(self.stage)
    for _, player in ipairs(self.players) do
        player_draw(player)
    end

    return self
end

level_scene_get_active_players = function(self)
    log_typecheck(self, LevelScene_t)
    local result = {}
    for player in iter_values(self.players) do
        if player_get_is_active(player) then
            table_push(result, player)
        end
    end
    return result
end