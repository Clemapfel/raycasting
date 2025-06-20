require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.control_indicator"
require "common.timed_animation"
require "common.fade"
require "menu.stage_select_page_indicator"
require "menu.stage_grade_label"

rt.settings.menu_scene = {
    player_max_falling_velocity = 1500,
    player_falling_x_damping = 0.98,
    player_falling_x_perturbation = 3,
    exit_acceleration = 60, -- per second

    title_screen = {
        title_font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
        player_velocity = 100, -- when reflecting
        player_offset_magnitude = 0.05 * 2 * math.pi, -- when holding left / right
        falling_fraction_threshold = 2000, -- how long it takes to transition to stage select
    },

    stage_select = {
        player_alignment = 1 / 3,
        reveal_animation_duration = 1,
        scroll_speed = 1,
        exititing_fraction = 2, -- number of screen heights until fade out starts
        scroll_ticks_per_second = 2
    },
}

--- @class mn.MenuScene
mn.MenuScene = meta.class("MenuScene", rt.Scene)

mn.MenuSceneState = meta.enum("MenuSceneState", {
    TITLE_SCREEN = "TITLE_SCREEN",
    FALLING = "FALLING",
    STAGE_SELECT = "STAGE_SELECT",
    EXITING = "EXITING"
})

local _title_shader_sdf, _title_shader_no_sdf, _background_shader = nil, nil, nil

local _long_dash = "\u{2014}"
local function _create_flow_percentage_label(fraction)
    local percentage = math.floor(fraction * 1000) / 10
    if math.fmod(percentage, 1) == 0 then
        return percentage .. ".0%"
    else
        return percentage .. "%"
    end
end

local _filled_star = "\u{2605}"
local _outlined_star = "\u{2606}"
local function _create_difficulty_label(score)
    local n_filled = 0
    local out = {}
    for i = 1, 5 do
        if n_filled < score then
            table.insert(out, _filled_star)
            n_filled = n_filled + 1
        else
            table.insert(out, _outlined_star)
        end
    end

    return table.concat(out)
end

local function _create_grade_label(grade)
    if grade == rt.StageGrade.DOUBLE_S then
        return "<wave><rainbow>SS</rainbow></wave>"
    elseif grade == rt.StageGrade.S then
        return "<color=GREEN>S</color>"
    elseif grade == rt.StageGrade.A then
        return "<color=YELLOW>A</color>"
    elseif grade == rt.StageGrade.B then
        return "<color=ORANGE>B</color>"
    elseif grade == rt.StageGrade.F then
        return "<outline_color=WHITE><color=BLACK>F</color></outline_color>"
    elseif grade == rt.StageGrade.NONE then
        return _long_dash -- long dash
    end
end

-- @brief
function mn.MenuScene:instantiate(state)
    if _background_shader == nil then
        _background_shader = rt.Shader("menu/menu_scene_background.glsl")
    end

    if _title_shader_no_sdf == nil then
        _title_shader_no_sdf = rt.Shader("menu/menu_scene_label.glsl", { MODE = 0 })
    end

    if _title_shader_sdf == nil then
        _title_shader_sdf = rt.Shader("menu/menu_scene_label.glsl", { MODE = 1 })
    end

    self._input_blocked = true

    self._world = b2.World()
    self._world:set_use_fixed_timestep(false)

    self._player = state:get_player()
    self._player_velocity_x, self._player_velocity_y = -1, -1

    self._camera = rt.Camera()

    -- fade in when starting
    self._fade = rt.Fade(0.8)
    self._fade:start()
    self._initialized = false

    self._exit_x, self._exit_y = 0, 0
    self._exit_velocity = 0
    self._exit_elapsed = 0

    self._shader_camera_offset = { 0, 0 }
    self._shader_elapsed = 0
    self._shader_fraction = 0

    do -- title screen
        local translation = rt.Translation.menu_scene.title_screen
        local title_screen = {}
        self._title_screen = title_screen

        title_screen.control_indicator = rt.ControlIndicator(
            rt.ControlIndicatorButton.A, translation.control_indicator_select,
            rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move
        )
        title_screen.control_indicator:set_has_frame(false)

        title_screen.menu_items = {}
        title_screen.n_menu_items = 0
        title_screen.selected_item_i = 1

        for text in range(
            translation.stage_select,
            translation.settings,
            translation.controls,
            translation.quit
        ) do
            local item = {
                unselected_label = rt.Label("<o>" .. text .. "</o>", rt.FontSize.LARGE),
                selected_label = rt.Label("<o><b><color=SELECTION>" .. text .. "</color></b></o>", rt.FontSize.LARGE),
            }

            table.insert(title_screen.menu_items, item)
            title_screen.n_menu_items =  title_screen.n_menu_items + 1
        end

        -- menu item: stage select
        local stage_select_item = title_screen.menu_items[1]
        stage_select_item.activate = function()
            self:_set_state(mn.MenuSceneState.FALLING)
        end

        -- menu item: settings
        local settings_item = title_screen.menu_items[2]
        settings_item.activate = function()
            require "menu.settings_scene"
            rt.SceneManager:push(mn.SettingsScene)
        end

        -- menu item: controls
        local controls_item = title_screen.menu_items[3]
        controls_item.activate = function()
            require "menu.keybinding_scene"
            rt.SceneManager:push(mn.KeybindingScene)
        end

        -- menu item: quit
        local quit_item = title_screen.menu_items[4]
        quit_item.activate = function()
            exit(0)
        end

        title_screen.input = rt.InputSubscriber()
        title_screen.input:signal_connect("pressed", function(_, which)
            if self._initialized == false or self._input_blocked == true then return end

            if which == rt.InputAction.JUMP then
                local item = title_screen.menu_items[title_screen.selected_item_i]
                item.activate()
            elseif which == rt.InputAction.UP then
                if title_screen.selected_item_i > 1 then
                    title_screen.selected_item_i = title_screen.selected_item_i - 1
                end
            elseif which == rt.InputAction.DOWN then
                if title_screen.selected_item_i < title_screen.n_menu_items then
                    title_screen.selected_item_i = title_screen.selected_item_i + 1
                end
            end
        end)

        title_screen.title_label_no_sdf = nil
        title_screen.title_label_sdf = nil
        title_screen.title_x, title_screen.title_y = 0, 0
        title_screen.boundaries = {}

        local duration = 2 * self._player:get_radius() / rt.settings.menu_scene.title_screen.player_velocity
        title_screen.opacity_fade_animation = rt.TimedAnimation(4 * duration)
    end

    do -- stage select
        local stage_select = {}
        self._stage_select = stage_select

        stage_select.input = rt.InputSubscriber()
        stage_select.input:signal_connect("pressed", function(_, which)
            if self._initialized == false or self._input_blocked == true or not stage_select.item_reveal_animation:get_is_done() then return end
            if self._state == mn.MenuSceneState.FALLING then
                return
            end

            if which == rt.InputAction.A then
                self:_set_state(mn.MenuSceneState.EXITING)
                stage_select.waiting_for_exit = true
            elseif which == rt.InputAction.B then
                self._fade:start()
                self._fade:signal_connect("hidden", function()
                    self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
                    return meta.DISCONNECT_SIGNAL
                end)
            elseif which == rt.InputAction.UP then
                stage_select.scroll_direction = -1
                stage_select.scroll_elapsed = 1 / rt.settings.menu_scene.stage_select.scroll_ticks_per_second
            elseif which == rt.InputAction.DOWN then
                stage_select.scroll_direction = 1
                stage_select.scroll_elapsed = 1 / rt.settings.menu_scene.stage_select.scroll_ticks_per_second
            end
        end)

        stage_select.input:signal_connect("released", function(_, which)
            if which == rt.InputAction.UP or which == rt.InputAction.DOWN then
                stage_select.scroll_direction = 0
            end
        end)

        stage_select.item_reveal_animation = rt.TimedAnimation(
            rt.settings.menu_scene.stage_select.reveal_animation_duration,
            1, 0,
            rt.InterpolationFunctions.SIGMOID
        )
        stage_select.reveal_width = 1

        stage_select.items = {}
        stage_select.selected_item_i = 1
        stage_select.n_items = 0
        stage_select.menu_x = 0
        stage_select.menu_y = 0
        stage_select.menu_height = 1
        stage_select.menu_width = 1
        stage_select.hrule_height = 2 * rt.get_pixel_scale()

        stage_select.scroll_elapsed = 0
        stage_select.scroll_direction = 0 -- -1 up, 1 down, 0 no scroll
        stage_select.motion = rt.SmoothedMotion1D(0, rt.settings.menu_scene.stage_select.scroll_speed)

        local stage_ids = rt.GameState:list_stage_ids()
        table.sort(stage_ids, function(a, b)
            return rt.GameState:get_stage_difficulty(a) < rt.GameState:get_stage_difficulty(b)
        end)

        local translation = rt.Translation.menu_scene.stage_select
        local title_prefix, title_postfix = "<b><u>", "</u></b>"
        local flow_prefix, flow_postfix = "", ""
        local time_prefix, time_postfix = "", ""
        local grade_prefix, grade_postfix = "<b><o>", "</b></o>"
        local difficulty_prefix, difficulty_postfix = "", ""
        local prefix_prefix, prefix_postfix = "", ""
        local description_prefix, description_postfix = "<color=GRAY>", "</color>"
        local header_prefix, header_postfix = "", ""
        local colon = "<color=GRAY>:</color>"

        local game_state = rt.GameState
        for id in values(stage_ids) do
            local title = game_state:get_stage_title(id)
            local was_beaten = game_state:get_stage_was_beaten(id)

            local time = not was_beaten and _long_dash or string.format_time(game_state:get_stage_best_time(id))
            local flow = not was_beaten and _long_dash or _create_flow_percentage_label(game_state:get_stage_best_flow_percentage(id))
            local grade = not was_beaten and _long_dash or _create_grade_label(game_state:get_stage_grade(id))
            local difficulty = _create_difficulty_label(game_state:get_stage_difficulty(id))
            local description = game_state:get_stage_description(id)
            local time_grade, flow_grade, total_grade = game_state:get_stage_grades(id)
            local item = {
                id = id,
                title_label = rt.Label(title_prefix .. title .. title_postfix, rt.FontSize.BIG),

                flow_prefix_label = rt.Label(prefix_prefix .. translation.flow_prefix .. prefix_postfix),
                flow_colon_label = rt.Label(colon),
                flow_value_label = rt.Label(flow_prefix .. flow .. flow_postfix),
                flow_grade = mn.StageGradeLabel(flow_grade, rt.FontSize.BIG),

                time_prefix_label = rt.Label(prefix_prefix ..translation.time_prefix .. prefix_postfix),
                time_colon_label = rt.Label(colon),
                time_value_label = rt.Label(time_prefix .. time .. time_postfix),
                time_grade = mn.StageGradeLabel(time_grade, rt.FontSize.BIG),

                difficulty_prefix_label = rt.Label(prefix_prefix ..translation.difficulty_prefix .. prefix_postfix),
                difficulty_colon_label = rt.Label(colon),
                difficulty_value_label = rt.Label(difficulty_prefix .. difficulty .. difficulty_postfix),

                frame = rt.Frame(),
                description_label = rt.Label(description_prefix .. description .. description_postfix, rt.FontSize.SMALL),
                total_grade = mn.StageGradeLabel(total_grade, rt.FontSize.HUGE),
                
                personal_best_header = rt.Label(header_prefix .. translation.personal_best_header .. header_postfix, rt.FontSize.SMALL),
                grade_header = rt.Label(header_prefix .. translation.grade_header .. header_postfix),

                hrules = {},
                target_y = 0,
                bounds = rt.AABB(),
            }

            table.insert(stage_select.items, item)
            stage_select.n_items = stage_select.n_items + 1
        end

        stage_select.page_indicator = mn.StageSelectPageIndicator(stage_select.n_items)
        translation = rt.Translation.menu_scene.stage_select
        stage_select.control_indicator = rt.ControlIndicator(
            rt.ControlIndicatorButton.A, translation.control_indicator_confirm,
            rt.ControlIndicatorButton.B, translation.control_indicator_back,
            rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_select
        )
    end
end

--- @brief
function mn.MenuScene:realize()
    self._title_screen.control_indicator:realize()
    for item in values(self._title_screen.menu_items) do
        item.unselected_label:realize()
        item.selected_label:realize()
    end

    for item in values(self._stage_select.items) do
        for widget in range(
            item.frame,
            item.title_label,
            item.personal_best_header,
            item.grade_header,
            item.difficulty_prefix_label,
            item.difficulty_colon_label,
            item.difficulty_value_label,
            item.flow_prefix_label,
            item.flow_colon_label,
            item.flow_value_label,
            item.flow_grade,
            item.time_prefix_label,
            item.time_colon_label,
            item.time_value_label,
            item.time_grade,
            item.description_label,
            item.total_grade
        ) do
            widget:realize()
        end
    end

    self._stage_select.page_indicator:realize()
    self._stage_select.control_indicator:realize()
    self._stage_select.control_indicator:set_has_frame(false)

    self:_create_from_state()
end

function mn.MenuScene:_create_from_state()
    local stage_select = self._stage_select

    local from = {
        rt.StageGrade.SS,
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.F,
        rt.StageGrade.NONE
    }

    local from_i = 1
    for i = 1, stage_select.n_items do
        -- TODO: from state
        local grade = from[from_i]
        stage_select.page_indicator:set_stage_grade(i, grade)

        local item = stage_select.items[i]
        item.flow_grade:set_grade(grade)
        item.time_grade:set_grade(grade)
        item.total_grade:set_grade(grade)

        from_i = from_i + 1
        if from_i > #from then
            from_i = 1
        end
    end

end

--- @brief
function mn.MenuScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 3 * m

    do -- title screen
        local title_screen = self._title_screen
        local font_size = rt.FontSize.GIGANTIC
        local title = rt.Translation.menu_scene.title_screen.title
        local font = rt.Font(rt.settings.menu_scene.title_screen.title_font_path)
        title_screen.title_label_no_sdf = love.graphics.newTextBatch(font:get_native(font_size, rt.FontStyle.REGULAR, false), title)
        title_screen.title_label_sdf = love.graphics.newTextBatch(font:get_native(font_size, rt.FontStyle.REGULAR, true), title)

        local title_w, title_h = font:measure(font_size, title)

        title_screen.title_x = math.floor(0 - 0.5 * title_w)
        title_screen.title_y = math.floor(0 - title_h - outer_margin)

        local boundaries = title_screen.boundaries
        for boundary in values(boundaries) do
            boundary:destroy()
        end

        do -- physics walls
            local scale = self._camera:get_scale_delta()
            local w, h = width / scale, height / scale
            local r = self._player:get_radius() * 0.5
            local cx, cw = 0 - 0.5 * w, 0 - 0.5 * h
            title_screen.enable_boundary_on_enter = true
            title_screen.boundaries = {
                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx - r, cw - r, cx + w + r, cw - r
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx + w + r, cw - r, cx + w + r, cw + h + r
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx + w + r, cw + h + r, cx - r, cw + h + r
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx - r, cw + h + r, cx - r, cw - r
                )),
            }

            -- reflect player along normal
            for body in values(title_screen.boundaries) do
                body:set_collides_with(rt.settings.player.bounce_collision_group)
                body:set_collision_group(rt.settings.player.bounce_collision_group)
                body:set_use_continuous_collision(true)
                body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
                    local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
                    local dot_product = current_vx * normal_x + current_vy * normal_y
                    self._player_velocity_x = current_vx - 2 * dot_product * normal_x
                    self._player_velocity_y = current_vy - 2 * dot_product * normal_y
                end)
                body:set_is_sensor(true)
                body:signal_set_is_blocked("collision_start", true)
            end
        end

        -- menu items
        local current_y = 2 * m
        local menu_center_x = 0
        for item in values(title_screen.menu_items) do
            local selected_w, selected_h = item.selected_label:measure()
            local unselected_w, unselected_h = item.unselected_label:measure()

            item.selected_label:reformat(menu_center_x - 0.5 * selected_w, current_y, math.huge)
            item.unselected_label:reformat(menu_center_x - 0.5 * unselected_w, current_y, math.huge)
            current_y = current_y + math.max(selected_h, unselected_h)
        end

        -- control indicator
        local control_w, control_h = title_screen.control_indicator:measure()
        title_screen.control_indicator:reformat(
            0 - 0.5 * width + width - m - control_w,
            0 - 0.5 * height + height - m - control_h,
            control_w, control_h
        )
    end

    do -- stage select
        local stage_select = self._stage_select

        -- control indicator
        local control_w, control_h = stage_select.control_indicator:measure()
        stage_select.control_indicator:reformat(
            x + width - control_w,
            y + height - control_h,
            control_w, control_h
        )

        local menu_y = math.round(outer_margin + control_h) -- for symmetry
        local menu_h = height - 2 * outer_margin - 2 * control_h

        -- page indicator
        local current_x = x + width - outer_margin
        local page_indicator_w = 30 * rt.get_pixel_scale()
        local page_indicator_m = math.max(3 * outer_margin, outer_margin + control_h + m)
        local page_indicator_h = math.min(menu_h, (7 + 2) * page_indicator_w) -- n balls + triangles
        stage_select.page_indicator:reformat(
            current_x - page_indicator_w,
            menu_y + 0.5 * menu_h - 0.5 * page_indicator_h,
            page_indicator_w,
            page_indicator_h
        )

        current_x = current_x - page_indicator_w - outer_margin

        -- level tiles
        local w = (1 - rt.settings.menu_scene.stage_select.player_alignment) * width - 2 * outer_margin - page_indicator_w - 2 * m
        local menu_x = math.round(current_x - w)
        local menu_w = w

        local max_prefix_w, max_colon_w, grade_line_h = -math.huge, -math.huge, -math.huge
        for item in values(stage_select.items) do
            for label in range(
                item.difficulty_prefix_label,
                item.flow_prefix_label,
                item.time_prefix_label
            ) do
                max_prefix_w = math.max(max_prefix_w, select(1, label:measure()))
            end

            for label in range(
                item.difficulty_colon_label,
                item.flow_colon_label,
                item.time_colon_label
            ) do
                max_colon_w = math.max(max_colon_w, select(1, label:measure()))
            end

            grade_line_h = math.max(grade_line_h,
                select(2, item.time_grade:measure()),
                select(2, item.flow_grade:measure()),
                select(2, item.flow_prefix_label:measure()),
                select(2, item.time_prefix_label:measure())
            )
        end

        local item_y = 0
        local item_area_w = w - 4 * m
        local hrule_x, hrule_width = menu_x + 4 * m, menu_w - 2 * 4 * m

        for i, item in ipairs(stage_select.items) do
            local ix, iy = menu_x, item_y + menu_y
            item.frame:reformat(ix, iy, menu_w, menu_h)
            item.bounds:reformat(ix, iy, menu_w, menu_h)
            item.hrules = {}

            ix = ix + 2 * m
            iy = iy + m

            local title_w, title_h = item.title_label:measure()
            item.title_label:reformat(ix + 0.5 * item_area_w - 0.5 * title_w, iy, item_area_w, math.huge)

            iy = iy + title_h + m

            do
                local line_x = ix
                item.difficulty_prefix_label:reformat(line_x, iy, math.huge)
                line_x = line_x + max_prefix_w + m

                local value_w, value_h = item.difficulty_value_label:measure()
                item.difficulty_value_label:reformat(ix + item_area_w - value_w, iy, math.huge)
                iy = iy + math.max(
                    select(2, item.difficulty_prefix_label:measure()),
                    select(2, item.difficulty_colon_label:measure()),
                    value_h
                )
            end

            item.description_label:reformat(ix, iy, item_area_w, math.huge)
            iy = iy + select(2, item.description_label:measure()) + m

            table.insert(item.hrules, rt.Line(
                hrule_x, iy, hrule_x + hrule_width, iy
            ))

            iy = iy + stage_select.hrule_height + m

            local small_grade_w = math.max(
                select(1, item.time_grade:measure()),
                select(1, item.flow_grade:measure())
            )
            do
                local prefix_w, prefix_h = item.flow_prefix_label:measure()
                local value_w, value_h = item.flow_value_label:measure()
                local grade_w, grade_h = item.flow_grade:measure()

                item.flow_prefix_label:reformat(
                    ix,
                    iy + 0.5 * grade_line_h - 0.5 * prefix_h,
                    math.huge
                )

                item.flow_grade:reformat(
                    ix + item_area_w - m - grade_w,
                    iy + 0.5 * grade_line_h - 0.5 * grade_h,
                    grade_w, grade_h
                )

                item.flow_value_label:reformat(
                    ix + item_area_w - m - grade_w - m - value_w,
                    iy + 0.5 * grade_line_h - 0.5 * value_h
                )
            end

            item.target_y = -1 * item_y
            item_y = item_y + height
        end

        stage_select.menu_stencil = rt.AABB(menu_x, menu_y, menu_w, menu_h)
        stage_select.reveal_width = math.max(control_w, menu_w) + 2 * outer_margin
    end
end
--- @brief
function mn.MenuScene:enter()
    if self._player:get_world() ~= self._world then
        self._player:move_to_world(self._world)
    end

    rt.SceneManager:set_use_fixed_timestep(true)
    self._player:set_opacity(1)

    self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
end

--- @brief
function mn.MenuScene:exit()
    self._player:enable()
    self._camera:set_is_shaking(false)
    self._title_screen.input:deactivate()
    self._stage_select.input:deactivate()
end

--- @brief
function mn.MenuScene:_set_state(next)
    assert(next ~= nil)

    self._state = next
    self._title_screen.input:deactivate()
    self._stage_select.input:deactivate()
    self._input_blocked = true

    local should_shake = next ~= mn.MenuSceneState
    self._camera:set_is_shaking(should_shake)
    if should_shake then
        self._camera:set_shake_intensity_in_pixels(1)
        self._camera:set_shake_frequency(0) -- modified in update
    end

    if next == mn.MenuSceneState.TITLE_SCREEN then
        self._title_screen.input:activate()

        local w, h = self._bounds.width, self._bounds.height
        local r = self._player:get_radius()
        local x, y = self._player:get_position()
        local new_x =  math.clamp(x, -0.5 * w + 2 * r, 0.5 * w - 2 * r)
        self._player:teleport_to(
           new_x,
            0
        )
        self._player:disable()

        self._player_velocity_x, self._player_velocity_y = new_x > 0 and -1 or 1, -1

        self._title_screen.enable_boundary_on_enter = true -- delay boundary until player is on screen
        for boundary in values(self._title_screen.boundaries) do
            boundary:set_is_sensor(true)
            boundary:signal_set_is_blocked("collision_start", true)
        end

        self._player:set_velocity(0, 0)
        self._player:set_gravity(0)
        self._player:set_is_bubble(true)
        self._player:set_flow(0)
        self._title_screen.opacity_fade_animation:reset()
        self._stage_select.item_reveal_animation:reset()
        return
    end

    if next == mn.MenuSceneState.FALLING or next == mn.MenuSceneState.STAGE_SELECT then
        self._stage_select.input:activate()
        self._stage_select.page_indicator:set_selected_page(1)
        self._stage_select.page_indicator:skip()

        self._player:set_gravity(1)
        self._player:set_is_bubble(false)
        self._player:enable()

        for boundary in values(self._title_screen.boundaries) do
            boundary:set_is_sensor(true)
            boundary:signal_set_is_blocked("collision_start", true)
        end

    elseif next == mn.MenuSceneState.EXITING then
        self._exit_x, self._exit_y = self._camera:get_position()
        self._exit_velocity = select(2, self._player:get_velocity())
        self._exit_elapsed = 0
    end
end

--- @brief
function mn.MenuScene:update(delta)
    if self._initialized == false then
        if self._fade:get_is_active() == false then
            self._fade:start(false)
            self._fade:signal_connect("hidden", function()
                self._initialized = true
                return meta.DISCONNECT_SIGNAL
            end)
        end
    end

    if self._input_blocked then self._input_blocked = false end
    -- keep input subscribers from firing on the same frame they are activated

    self._fade:update(delta)
    if not self._initialized then return end

    self._world:update(delta)
    self._camera:update(delta)
    self._player:update(delta)

    self._shader_elapsed = self._shader_elapsed + delta
    self._shader_camera_offset = { self._camera:get_offset() }
    if self._state == mn.MenuSceneState.EXITING then
        local px, py = self._player:get_position()
        self._exit_elapsed = self._exit_elapsed + delta
        self._shader_camera_offset[1] = self._exit_x
        self._shader_camera_offset[2] = self._exit_y - self._exit_elapsed * self._exit_velocity -- continue scrolling as player accelerates
    end
    self._shader_camera_scale = self._camera:get_scale()
    self._shader_fraction = 0

    self._stage_select.item_reveal_offset = 0

    if self._state == mn.MenuSceneState.TITLE_SCREEN then
        local title_screen = self._title_screen
        local velocity_offset = 0
        if title_screen.input:get_is_down(rt.InputAction.LEFT) then
            velocity_offset = 1
        elseif title_screen.input:get_is_down(rt.InputAction.RIGHT) then
            velocity_offset = -1
        end

        -- stay centered, reflect player around walls
        self._camera:set_position(0, 0)
        local magnitude = rt.settings.menu_scene.title_screen.player_velocity
        local offset_magnitude = rt.settings.menu_scene.title_screen.player_offset_magnitude

        local vx, vy = self._player_velocity_x, self._player_velocity_y
        vx, vy = math.rotate(vx, vy, velocity_offset * offset_magnitude)

        self._player:set_velocity(
            vx * magnitude,
            vy * magnitude
        )

        -- wait for player to enter, then lock
        if title_screen.enable_boundary_on_enter == true then
            local r = self._player:get_radius()
            local w = love.graphics.getWidth() - 2 * r
            local h = love.graphics.getHeight() - 2 * r
            local bounds = rt.AABB(
                0 - 0.5 * w, 0 - 0.5 * h, w, h
            )

            if bounds:contains(self._player:get_position()) then
                for boundary in values(self._title_screen.boundaries) do
                    boundary:set_is_sensor(false)
                    boundary:signal_set_is_blocked("collision_start", false)
                end
                self._title_screen.enable_boundary_on_enter = false
            end
        end

        return
    end

    -- falling or level select
    local px, py = self._player:get_predicted_position()
    self._shader_fraction = math.clamp(py / rt.settings.menu_scene.title_screen.falling_fraction_threshold, 0, 1)
    self._player:set_flow(self._shader_fraction)

    -- clamp velocity
    local vx, vy = self._player:get_velocity()
    local max_velocity = rt.settings.menu_scene.player_max_falling_velocity

    vx = math.min(vx * rt.settings.menu_scene.player_falling_x_damping, max_velocity)
    vy = math.min(vy, max_velocity)
    vx = vx + (rt.random.noise(self._shader_elapsed * 10, 0) * 2 - 1) * (rt.settings.menu_scene.player_falling_x_perturbation * (love.graphics.getHeight() / rt.settings.native_height)) * self._shader_fraction

    if self._state == mn.MenuSceneState.EXITING then
        vy = vy + rt.settings.menu_scene.exit_acceleration * delta -- exponential acceleration
    end
    self._player:set_velocity(vx, vy)
    self._camera:set_shake_frequency(vy / max_velocity)

    -- transition player to left side of screen
    local offset_fraction = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(self._shader_fraction)
    local x_offset = offset_fraction * rt.settings.menu_scene.stage_select.player_alignment * self._bounds.width

    if self._state == mn.MenuSceneState.EXITING then
        self._camera:move_to(self._exit_x, self._exit_y)
    else
        self._camera:move_to(px + x_offset / self._camera:get_final_scale(), py)
    end

    local stage_select = self._stage_select
    if offset_fraction > 0.5 then
        stage_select.item_reveal_animation:update(delta)
        stage_select.page_indicator:update(delta)
    end

    if self._state == mn.MenuSceneState.FALLING then
        -- transition to stage screen once player is in position
        if self._shader_fraction >= 1 then
            self:_set_state(mn.MenuSceneState.STAGE_SELECT)
        end
    elseif self._state == mn.MenuSceneState.STAGE_SELECT then
        if stage_select.scroll_direction ~= 0 then
            local step = 1 / rt.settings.menu_scene.stage_select.scroll_ticks_per_second
            local updated = false
            while stage_select.scroll_elapsed >= step do
                if stage_select.scroll_direction == -1 and stage_select.selected_item_i > 1 then
                    stage_select.selected_item_i = stage_select.selected_item_i - 1
                elseif stage_select.scroll_direction == 1 and stage_select.selected_item_i < stage_select.n_items then
                    stage_select.selected_item_i = stage_select.selected_item_i + 1
                end

                stage_select.scroll_elapsed = stage_select.scroll_elapsed - step
                updated = true
            end

            if updated then
                stage_select.page_indicator:set_selected_page(stage_select.selected_item_i)
                stage_select.motion:set_target_value(stage_select.items[stage_select.selected_item_i].target_y)
            end

            stage_select.scroll_elapsed = stage_select.scroll_elapsed + delta
        end

        local item = stage_select.items[stage_select.selected_item_i]
        for widget in range(
            item.title_label,
            item.difficulty_prefix_label,
            item.difficulty_colon_label,
            item.difficulty_value_label,
            item.flow_prefix_label,
            item.flow_colon_label,
            item.flow_value_label,
            item.flow_grade,
            item.time_prefix_label,
            item.time_colon_label,
            item.time_value_label,
            item.time_grade,
            item.description_label,
            item.total_grade
        ) do
            widget:update(delta)
        end

        stage_select.motion:update(delta)

    elseif self._state == mn.MenuSceneState.EXITING then
        if stage_select.waiting_for_exit then
            -- wait for player to exit screen, then fade out
            if select(2, self._camera:world_xy_to_screen_xy(self._player:get_position())) > rt.settings.menu_scene.stage_select.exititing_fraction * love.graphics.getHeight() then
                self._fade:start(true, false)
                self._fade:signal_connect("hidden", function()
                    require "overworld.overworld_scene"
                    local item = stage_select.items[stage_select.selected_item_i]
                    if item ~= nil then
                        rt.SceneManager:push(ow.StageTitleCardScene, item.id)
                    end
                end)
                stage_select.waiting_for_exit = false
            end
        end
    end
end

local _black = { rt.Palette.BLACK:unpack() }

--- @brief
function mn.MenuScene:draw()
    if not self._initialized then
        self._fade:draw()
        return
    end

    -- draw background
    love.graphics.push()
    love.graphics.origin()
    _background_shader:bind()
    _background_shader:send("black", _black)
    _background_shader:send("elapsed", self._shader_elapsed)
    _background_shader:send("camera_offset", self._shader_camera_offset)
    _background_shader:send("camera_scale", self._shader_camera_scale)
    _background_shader:send("fraction", self._shader_fraction)
    _background_shader:send("hue", self._player:get_hue())

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    _background_shader:unbind()
    love.graphics.pop()

    -- title screen
    if self._state == mn.MenuSceneState.TITLE_SCREEN or self._state == mn.MenuSceneState.FALLING then
        local title_screen = self._title_screen

        -- draw title
        love.graphics.push()
        love.graphics.translate(self._camera:get_offset())
        _title_shader_sdf:bind()
        _title_shader_sdf:send("elapsed", self._shader_elapsed)
        _title_shader_sdf:send("black", _black)
        _title_shader_sdf:send("camera_offset", self._shader_camera_offset)
        _title_shader_sdf:send("camera_scale", self._shader_camera_scale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(title_screen.title_label_sdf, title_screen.title_x, title_screen.title_y)
        _title_shader_sdf:unbind()

        _title_shader_no_sdf:bind()
        _title_shader_no_sdf:send("elapsed", self._shader_elapsed)
        _title_shader_no_sdf:send("hue", self._player:get_hue())
        _title_shader_no_sdf:send("black", _black)
        _title_shader_no_sdf:send("camera_offset", self._shader_camera_offset)
        _title_shader_no_sdf:send("camera_scale", self._shader_camera_scale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(title_screen.title_label_no_sdf, title_screen.title_x, title_screen.title_y)
        _title_shader_no_sdf:unbind()

        -- draw menu
        for i, item in ipairs(title_screen.menu_items) do
            if i == title_screen.selected_item_i then
                item.selected_label:draw()
            else
                item.unselected_label:draw()
            end
        end

        title_screen.control_indicator:draw()
        love.graphics.pop()
    end

    if self._state == mn.MenuSceneState.FALLING or self._state == mn.MenuSceneState.STAGE_SELECT or self._state == mn.MenuSceneState.EXITING then
        local stage_select = self._stage_select

        love.graphics.push()
        local offset_x = stage_select.item_reveal_animation:get_value()
        if math.fract(offset_x) == 0 then
            love.graphics.translate(math.round(offset_x * stage_select.reveal_width), 0)
        else
            love.graphics.translate(offset_x * stage_select.reveal_width, 0)
        end

        love.graphics.push()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", stage_select.menu_stencil:unpack())

        local y_offset = stage_select.motion:get_value()
        love.graphics.translate(0, y_offset)

        rt.Palette.FOREGROUND:bind() -- hrule color
        love.graphics.setLineWidth(stage_select.hrule_height)

        for item_i = 1, stage_select.n_items do
            local item = stage_select.items[item_i]

            if item.bounds.y + item.bounds.height + y_offset > 0 and -- only draw if item overlaps screen
                item.bounds.y + y_offset < love.graphics.getHeight()
            then
                for widget in range(
                    item.frame,
                    item.title_label,
                    item.personal_best_header,
                    item.grade_header,
                    item.difficulty_prefix_label,
                    item.difficulty_colon_label,
                    item.difficulty_value_label,
                    item.flow_prefix_label,
                    item.flow_colon_label,
                    item.flow_value_label,
                    item.flow_grade,
                    item.time_prefix_label,
                    item.time_colon_label,
                    item.time_value_label,
                    item.time_grade,
                    item.description_label,
                    item.personal_best_header,
                    item.grade_header,
                    item.total_grade
                ) do
                    widget:draw()
                end

                rt.Palette.FOREGROUND:bind()
                for hrule in values(item.hrules) do
                    hrule:draw()
                end
            end
        end

        love.graphics.pop()

        stage_select.page_indicator:draw()
        love.graphics.setColor(1, 1, 1, 1)
        self._stage_select.control_indicator:draw()

        love.graphics.pop()
    end

    self._camera:bind()
    self._player:draw()
    self._camera:unbind()

    self._fade:draw()
end

--- @brief
function mn.MenuScene:get_camera()
    return self._camera
end