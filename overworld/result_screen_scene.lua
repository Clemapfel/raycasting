require "common.label"
require "overworld.result_screen_frame"
require "overworld.fireworks"

rt.settings.overworld.result_screen_scene = {
    exit_transition_fall_duration = 2, -- seconds
    title_font = "assets/fonts/Baloo2/Baloo2-Bold.ttf",
    glyph_font = "assets/fonts/Baloo2/Baloo2-Medium.ttf",

    coin_indicator_n_vertices = 16,
    coin_indicator_line_width = 1.5,

    reveal_animation_duration = 2,
}

--- @class ow.ResultScreenScene
ow.ResultScreenScene = meta.class("ResultScreenScene", rt.Scene)

local _title_font, _glyph_font

local _format_count = function(n, max_n)
    return string.paste(n, " / ", max_n)
end

local _format_title = function(text)
    return "<b><o><u>" .. text .. "</u></o></b>"
end

--- @brief
function ow.ResultScreenScene:instantiate(state)
    if _title_font == nil then _title_font = rt.Font(rt.settings.overworld.result_screen_scene.title_font) end
    if _glyph_font == nil then _glyph_font = rt.Font(rt.settings.overworld.result_screen_scene.glyph_font) end

    -- grades
    local translation = rt.Translation.result_screen_scene

    local new_heading = function(text)
        return rt.Glyph(text, {
            style = rt.FontStyle.BOLD,
            is_outlined = true,
            font_size = rt.FontSize.BIG,
            font = _title_font
        })
    end

    local new_value = function(text, override)
        return rt.Glyph(text, {
            style = rt.FontStyle.BOLD,
            is_outlined = true,
            font_size = override or rt.FontSize.REGULAR,
            font = _glyph_font
        })
    end

    self._stage_name_label = rt.Label(_format_title(""), rt.FontSize.BIG, _title_font)
    self._stage_name_label:set_justify_mode(rt.JustifyMode.CENTER)

    self._grade_to_grade_label = {}
    self._grade_label_font_size = nil
    self._grade_label_width, self._grade_label_height = 1, 1

    self._flow_title_label = new_heading(translation.flow)
    self._time_title_label = new_heading(translation.time)
    self._coins_title_label = new_heading(translation.coins)

    self._flow_value_label_x, self._flow_value_label_y = 0, 0
    self._time_value_label_x, self._time_value_label_y = 0, 0
    self._coins_value_label_x, self._coins_value_label_y = 0, 0

    self._coin_indicators = {}

    self._flow_value_label = new_value(string.format_percentage(0))
    self._time_value_label = new_value(string.format_time(0))
    self._coins_value_label = new_value(_format_count(0, 0))
    self._animations_active = false

    self._total_label = new_heading(translation.total)

    local grade_size = rt.FontSize.LARGER
    self._total_grade = mn.StageGradeLabel(rt.StageGrade.S, rt.FontSize.GIGANTIC)
    self._flow_grade_label_x, self._flow_grade_label_y = 0, 0
    self._time_grade_label_x, self._time_grade_label_y = 0, 0
    self._coins_grade_label_x, self._coins_grade_label_y = 0, 0

    local scale_duration = 1
    local easing = rt.InterpolationFunctions.ENVELOPE
    local max_scale = 2
    self._flow_grade_label_scale_animation = rt.TimedAnimation(scale_duration, 1, max_scale, easing, 0.05)
    self._time_grade_label_scale_animation = rt.TimedAnimation(scale_duration, 1, max_scale, easing, 0.05)
    self._coins_grade_label_scale_animation = rt.TimedAnimation(scale_duration, 1, max_scale, easing, 0.05)

    for to_skip in range(
        self._flow_grade_label_scale_animation,
        self._time_grade_label_scale_animation,
        self._coins_grade_label_scale_animation
    ) do
        to_skip:skip()
    end

    self._flow_grade = rt.StageGrade.NONE
    self._current_flow_grade = self._flow_grade

    self._time_grade = rt.StageGrade.NONE
    self._current_time_grade = self._time_grade
    self._target_time = 0
    self._max_time = 0

    self._coins_grade = rt.StageGrade.NONE
    self._current_coins_grade = self._coins_grade

    -- reveal animation
    local duration = rt.settings.overworld.result_screen_scene.reveal_animation_duration
    local easing = rt.InterpolationFunctions.SINUSOID_EASE_OUT
    self._coins_animation = rt.TimedAnimation(duration, 0, 1, easing)
    self._flow_animation = rt.TimedAnimation(duration, 0, 1, easing)
    self._time_animation = rt.TimedAnimation(duration, 0, 1, easing)
    self._coin_indicator_animation = rt.TimedAnimation(duration, 0, 1, rt.InterpolationFunctions.LINEAR)

    self._flow = 0
    self._max_n_coins = 0
    self._n_coins = 0
    self._time = 0

    -- exit animation
    self._transition_active = false
    self._transition_next = nil -- Type<rt.Scene>
    self._transition_elapsed = 0
    self._transition_final_y = nil -- Number
    self._fade = rt.Fade(2, "overworld/overworld_scene_fade.glsl")
    self._fade_active = false

    -- result animations
    self._frame = ow.ResultScreenFrame()
    self._fireworks = ow.Fireworks()
    self._camera = rt.Camera()
    self._screenshot = nil -- rt.RenderTexture, cf :enter

    self._bloom = nil -- initialized on first draw

    self._is_paused = false
    do -- options
        local unselected_prefix, unselected_postfix = rt.settings.menu.pause_menu.label_prefix, rt.settings.menu.pause_menu.label_postfix
        local selected_prefix, selected_postfix = unselected_prefix .. "<color=SELECTION>", "</color>" .. unselected_postfix
        local blocked_prefix, blocked_postfix = unselected_prefix .. "<s><color=GRAY>", "</color></s>" .. unselected_postfix
        self._options = {}
        self._option_unblocked_selection_graph = rt.SelectionGraph()
        self._option_blocked_selection_graph = rt.SelectionGraph()
        self._option_background = rt.Background("menu/pause_menu.glsl", true) -- sic, use same as level pause

        self._option_first_blocked_node = nil
        self._option_first_unblocked_node = nil
        self._options = {}

        local function add_option(text, function_name, can_be_blocked)
            local option = {
                unselected_label = rt.Label(
                    unselected_prefix .. text .. unselected_postfix,
                    rt.FontSize.LARGE
                ),
                selected_label = rt.Label(
                    selected_prefix .. text .. selected_postfix,
                    rt.FontSize.LARGE
                ),

                frame = rt.Frame(),
                node = rt.SelectionGraphNode(),
            }

            if can_be_blocked then
                option.blocked_label = rt.Label(
                    blocked_prefix .. text .. blocked_postfix,
                    rt.FontSize.LARGE
                )
            end
            option.can_be_blocked = can_be_blocked

            option.frame:set_base_color(0, 0, 0, 0)
            option.frame:set_selection_state(rt.SelectionState.ACTIVE)
            option.frame:set_thickness(rt.settings.menu.pause_menu.selection_frame_thickness)


            option.blocked_node = rt.SelectionGraphNode()
            option.unblocked_node = rt.SelectionGraphNode()

            local to_invoke = function(_)
                self[function_name](self)
            end

            option.blocked_node:signal_connect(rt.InputAction.A, to_invoke)
            option.unblocked_node:signal_connect(rt.InputAction.A, to_invoke)

            if self._option_first_blocked_node == nil then
                self._option_first_blocked_node = option.blocked_node
            end

            if self._option_first_unblocked_node == nil then
                self._option_first_unblocked_node = option.unblocked_node
            end

            table.insert(self._options, option)

            return option
        end

        local retry_option = add_option(
            translation.option_retry_stage,
            "_on_retry_stage",
            false
        )

        local next_stage_option = add_option(
            translation.option_next_stage,
            "_on_next_stage",
        true
        )

        local return_to_main_menu_option = add_option(
            translation.option_return_to_main_menu,
            "_on_return_to_main_menu",
            false
        )

        local show_splits_option = add_option(
            translation.option_show_splits,
            "_on_show_splits",
            false
        )

        -- connect nodes
        local add_options = function(graph, options, is_blocked)
            for i = 1, #options, 1 do
                local before = math.wrap(i-1, #options)
                local after = math.wrap(i+1, #options)

                local element = options[i]

                if is_blocked then
                    graph:add(element.blocked_node)
                    element.blocked_node:set_up(options[before].blocked_node)
                    element.blocked_node:set_down(options[after].blocked_node)
                else
                    graph:add(element.unblocked_node)
                    element.unblocked_node:set_up(options[before].unblocked_node)
                    element.unblocked_node:set_down(options[after].unblocked_node)
                end
            end
        end

        add_options(self._option_unblocked_selection_graph, {
            retry_option,
            next_stage_option,
            return_to_main_menu_option,
            show_splits_option
        }, false)

        add_options(self._option_blocked_selection_graph, {
            retry_option,
            -- next_stage_option disabled
            return_to_main_menu_option,
            show_splits_option
        }, true)

        self._next_level_blocked = false
    end

    self._option_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.UP_DOWN, translation.option_control_indicator_move,
        rt.ControlIndicatorButton.A, translation.option_control_indicator_select,
        rt.ControlIndicatorButton.PAUSE, translation.option_control_indicator_go_back
    )
    self._option_control_indicator:set_has_frame(false)

    self._grade_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.A, translation.grade_control_indicator_continue
    )
    self._grade_control_indicator:set_has_frame(false)

    -- player boundaries
    self._entry_x, self._entry_y = 0, 0
    self._player_velocity_x, self._player_velocity_y = 0, 0
    self._player = state:get_player()

    do
        self._world = b2.World()
        -- body and teleport updated in size_allocate

        if self._body ~= nil then self._body:set_is_enabled(true) end
    end

    -- input
    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button(which)
    end)
    self._input:deactivate()
end

--- @brief
function ow.ResultScreenScene:realize()
    if self:already_realized() then return end

    for widget in range(
        self._option_retry_stage_unselected_label,
        self._option_next_stage_unselected_label,
        self._option_return_to_main_menu_unselected_label,
        self._option_retry_stage_selected_label,
        self._option_next_stage_selected_label,
        self._option_return_to_main_menu_selected_label,
        self._option_background,

        self._frame,
        self._stage_name_label,

        self._coins_title_label,
        self._coins_value_label,

        self._flow_title_label,
        self._flow_value_label,
        self._total_grade,

        self._time_title_label,
        self._time_value_label,

        self._option_control_indicator,
        self._grade_control_indicator
    ) do
        widget:realize()
    end

    for option in values(self._options) do
        for label in range(
            option.selected_label,
            option.unselected_label,
            option.blocked_label -- can be nil
        ) do
            label:realize()
        end
    end
end

--- @brief
function ow.ResultScreenScene:size_allocate(x, y, width, height)
    do -- preallocate grades
        self._grade_to_grade_label = {}
        local max_w, max_h = -math.huge, -math.huge
        for grade in values(meta.instances(rt.StageGrade)) do
            local label = mn.StageGradeLabel(grade, rt.FontSize.LARGER)
            label:realize()
            local w, h = label:measure()
            label:reformat(0, 0, w, h)
            self._grade_to_grade_label[grade] = label
            max_w = math.max(max_w, w)
            max_h = math.max(max_h, h)
        end

        self._grade_label_w, self._grade_label_h = max_w, max_h
    end

    local m = rt.settings.margin_unit
    do -- physics world
        local bx, by = 0, 0
        local _, _, w, h = self:get_bounds():unpack()
        for body in values(self._bodies) do body:destroy() end

        self._bodies = {}
        for shape in range(
            b2.Segment(bx + 0, by + 0, bx + w, by + 0),
            b2.Segment(bx + w, by + 0, bx + w, by + h),
            b2.Segment(bx + w, by + h, bx + 0, by + h),
            b2.Segment(bx + 0, by + h, bx + 0, by + 0)
        ) do
            local body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, shape)
            body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
                if other_body:has_tag("player") then
                    local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
                    self._player_velocity_x, self._player_velocity_y = math.reflect(
                        current_vx, current_vy,
                        normal_x, normal_y
                    )
                else -- coin
                    local entry = other_body:get_user_data()
                    entry.velocity_x, entry.velocity_y = math.reflect(
                        entry.velocity_x, entry.velocity_y,
                        normal_x, normal_y
                    )
                end
            end)

            body:set_collides_with(rt.settings.player.bounce_collision_group)
            body:set_collision_group(rt.settings.player.bounce_collision_group)
            body:set_mass(10e-3)
            table.insert(self._bodies, body)
        end

        self:_teleport_player(self._entry_x, self._entry_y)
    end

    do -- options
        local total_h = 0
        for option in values(self._options) do
            total_h = total_h + math.max(
                select(2, option.unselected_label:measure()),
                select(2, option.selected_label:measure())
            ) + m
        end

        self._option_background:reformat(x, y, width, height)
        local current_y = y + 0.5 * height - 0.5 * total_h
        local label_xm, label_ym = 2 * m, 0.5 * m
        for option in values(self._options) do
            local selected_w, selected_h = option.selected_label:measure()
            local unselected_w, unselected_h = option.unselected_label:measure()
            local blocked_w, blocked_h

            local w, h
            if option.can_be_blocked then
                blocked_w, blocked_h = option.blocked_label:measure()
                w, h = math.max(selected_w, unselected_w, blocked_w), math.max(selected_h, unselected_h, blocked_h)
            else
                w, h = math.max(selected_w, unselected_w), math.max(selected_h, unselected_h)
            end

            option.frame:reformat(
                x + 0.5 * width - 0.5 * w - label_xm,
                current_y - label_ym,
                w + 2 * label_xm, h + 2 * label_ym
            )

            option.selected_label:reformat(
                x + 0.5 * width - 0.5 * selected_w,
                current_y + 0.5 * h - 0.5 * selected_h,
                math.huge, math.huge
            )

            option.unselected_label:reformat(
                x + 0.5 * width - 0.5 * unselected_w,
                current_y + 0.5 * h - 0.5 * selected_h,
                math.huge, math.huge
            )

            if option.can_be_blocked then
                option.blocked_label:reformat(
                    x + 0.5 * width - 0.5 * blocked_w,
                    current_y + 0.5 * h - 0.5 * blocked_h,
                    math.huge, math.huge
                )
            end

            current_y = current_y + h + m
        end
    end

    for indicator in range(
        self._option_control_indicator,
        self._grade_control_indicator
    ) do
        local control_w, control_h = indicator:measure()
        indicator:reformat(
            x + width - control_w,
            y + height - control_h,
            control_w, control_h
        )
    end

    self:_reformat_frame()
end

--- @brief
--- @param player_x Number in screen coordinates
--- @param player_y Number
--- @param screenshot RenderTexture?
function ow.ResultScreenScene:enter(player_x, player_y, screenshot, config)
    if screenshot == nil then screenshot = self._screenshot end

    self._input:activate()

    rt.SceneManager:set_use_fixed_timestep(true)
    self._screenshot = screenshot -- can be nil

    if rt.SceneManager:get_is_bloom_enabled() then
        rt.SceneManager:get_bloom():set_bloom_strength(rt.settings.menu_scene.bloom_strength)
    end

    meta.assert_typeof(player_x, "Number", 1)
    meta.assert_typeof(player_x, "Number", 2)
    if screenshot ~= nil then
        meta.assert_typeof(screenshot, rt.RenderTexture, 3)
    end
    meta.assert_typeof(config, "Table", 4)

    self._player:reset()
    self._player:move_to_world(self._world)
    self._player:set_gravity(0)
    self._player:set_is_bubble(true)

    self._frame:present()

    self._config = config
    local required_keys = {}
    for key in range(
        "stage_name",
        "stage_id",
        "coins",
        "time",
        "flow",
        "time_grade",
        "flow_grade",
        "coins_grade",
        "target_time"
    ) do
        required_keys[key] = true
    end

    for key in keys(required_keys) do
        if self._config[key] == nil then
            rt.error("In ow.ResultScreenScene.enter: config does not have `" .. key .. "` field")
        end
    end

    self._stage_name_label:set_text(_format_title(config.stage_name))

    self._current_stage_id = config.stage_id
    self._next_stage_id = rt.GameState:get_next_stage(self._current_stage_id)
    self._next_level_blocked = self._next_stage_id == nil -- disables menu option

    self._flow = config.flow
    self._time = config.time
    self._target_time = config.time

    -- calculate maximum time
    self._max_time = rt.settings.game_state.stage.grade_time_thresholds[rt.StageGrade.F]

    self._flow_grade = config.flow_grade
    self._time_grade = config.time_grade
    self._coins_grade = config.coins_grade

    self._current_time_grade = rt.StageGrade.F
    self._current_flow_grade = rt.StageGrade.F
    self._current_coins_grade = rt.StageGrade.F

    -- player position continuity
    self._entry_x, self._entry_y = player_x, player_y
    self:_teleport_player(self._entry_x, self._entry_y)
    self._camera:set_position(self._bounds.x + 0.5 * self._bounds.width, self._bounds.y + 0.5 * self._bounds.height)

    self._coin_indicators = {}

    do -- coins
        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.body:destroy()
            end
        end

        self._max_n_coins = #(self._config.coins)
        self._n_coins = 0
        for b in values(self._config.coins) do
            if not meta.is_boolean(b) then
                rt.error("In ow.ResultScreen.enter: `coins` field does not contain exclusively booleans")
            end

            if b then self._n_coins = self._n_coins + 1 end
        end

        local radius = 0.9 * rt.settings.overworld.coin.radius * rt.get_pixel_scale()
        for i = 1, self._max_n_coins do
            local coin = ow.CoinParticle(radius)
            coin:set_hue(ow.Coin.index_to_hue(i, self._max_n_coins))
            coin:set_is_outline(true)

            table.insert(self._coin_indicators, {
                radius = radius,
                coin = coin,
                x = 0,
                y = 0,
                velocity_x = 0,
                velocity_y = 0,
                body = nil, -- b2.Body
                is_collected = self._config.coins[i],
                active = false
            })
        end
    end

    -- labels
    self._flow_value_label:set_text(string.format_percentage(0))
    self._time_value_label:set_text(string.format_time(0))
    self._coins_value_label:set_text(_format_count(0, self._max_n_coins))

    self:_reformat_frame() -- realign all mutable ui elements

    -- reset animations
    for animation in range(
        self._flow_animation,
        self._coins_animation,
        self._time_animation,
        self._coin_indicator_animation
    ) do
        animation:reset()
    end

    for animation in range(
        self._flow_grade_label_scale_animation,
        self._coins_grade_label_scale_animation,
        self._time_grade_label_scale_animation
    ) do
        animation:skip()
    end

    self._animations_active = false

    self._fade:reset()
    self._fade_active = false
    self._frame:signal_connect("presented", function(_)
        self._animations_active = true
        return meta.DISCONNECT_SIGNAL
    end)

    -- reset pause menu
    self._option_blocked_selection_graph:set_selected_node(self._option_first_blocked_node)
    self._option_unblocked_selection_graph:set_selected_node(self._option_first_unblocked_node)
    self:_unpause()

    self._input:activate()
end

--- @brief
function ow.ResultScreenScene:_reformat_frame()
    local x, y, width, height = self:get_bounds():unpack()
    local m = rt.settings.margin_unit

    do
        local max_w, max_h = -math.huge, -math.huge
        for grade in values(self._grade_to_grade_label) do
            local w, h = grade:measure()
            max_w = math.max(max_w, w)
            max_h = math.max(max_h, h)
        end

        self._grade_label_width, self._grade_label_height = max_w, max_h
    end

    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

    local y = 0 -- aligned in draw
    min_y = y

    local max_title_w = -math.huge
    for title in range(
        self._coins_title_label,
        self._time_title_label,
        self._flow_title_label
    ) do
        max_title_w = math.max(max_title_w, select(1, title:measure()))
    end

    local title_area_w = 2 / 3 * width
    self._stage_name_label:reformat(
        x + 0.5 * width - 0.5 * title_area_w,
        y + m,
        2 / 3 * width,
        math.huge
    )
    local title_w, title_h = self._stage_name_label:measure()

    local col_w = (width / 2) / 3 + 4 * m --max_title_w + 4 * m
    local col_x = x + 0.5 * width - 0.5 * (3 * col_w)
    local col_y = y + m + title_h + 2 * m

    local start_x = col_x

    -- coins
    local coins_x, coins_y, coins_w = col_x, col_y, col_w
    col_x = col_x + col_w

    local coins_title_w, coins_title_h = self._coins_title_label:measure()
    self._coins_title_label:reformat(coins_x + 0.5 * coins_w - 0.5 * coins_title_w, coins_y, math.huge)
    coins_y = coins_y + coins_title_h + m

    local coins_grade_w, coins_grade_h = self._grade_label_width, self._grade_label_height
    self._coins_grade_label_x, self._coins_grade_label_y = coins_x + 0.5 * coins_w - 0.5 * coins_grade_w, coins_y
    coins_y = coins_y + coins_grade_h + m

    local coins_value_w, coins_value_h = self._coins_value_label:measure()
    self._coins_value_label:reformat(coins_x + 0.5 * coins_w - 0.5 * coins_value_w, coins_y, math.huge)

    self._coins_value_label_x, self._coins_value_label_y = coins_x + 0.5 * coins_w, coins_y

    -- time
    local time_x, time_y, time_w = col_x, col_y, col_w
    col_x = col_x + col_w

    local time_title_w, time_title_h = self._time_title_label:measure()
    self._time_title_label:reformat(time_x + 0.5 * time_w - 0.5 * time_title_w, time_y, math.huge)
    time_y = time_y + time_title_h + m

    local time_grade_w, time_grade_h = self._grade_label_width, self._grade_label_height
    self._time_grade_label_x, self._time_grade_label_y = time_x + 0.5 * time_w - 0.5 * time_grade_w, time_y
    time_y = time_y + time_grade_h + m

    local time_value_w, time_value_h = self._time_value_label:measure()
    self._time_value_label:reformat(time_x + 0.5 * time_w - 0.5 * time_value_w, time_y, math.huge)

    self._time_value_label_x, self._time_value_label_y = time_x + 0.5 * time_w, time_y

    -- flow
    local flow_x, flow_y, flow_w = col_x, col_y, col_w
    col_x = col_x + col_w

    local flow_title_w, flow_title_h = self._flow_title_label:measure()
    self._flow_title_label:reformat(flow_x + 0.5 * flow_w - 0.5 * flow_title_w, flow_y, math.huge)
    flow_y = flow_y + flow_title_h + m

    local flow_grade_w, flow_grade_h = self._grade_label_width, self._grade_label_height
    self._flow_grade_label_x, self._flow_grade_label_y = flow_x + 0.5 * flow_w - 0.5 * flow_grade_w, flow_y
    flow_y = flow_y + flow_grade_h + m

    local flow_value_w, flow_value_h = self._flow_value_label:measure()
    self._flow_value_label:reformat(flow_x + 0.5 * flow_w - 0.5 * flow_value_w, flow_y, math.huge)

    self._flow_value_label_x, self._flow_value_label_y = flow_x + 0.5 * flow_w, flow_y

    -- indicators
    local indicator_y = math.max(time_y, flow_y, coins_y) + m
    local indicator_width = math.abs(col_x - start_x) - 4 * m
    local indicator_x, indicator_height = x + 0.5 * width - 0.5 * indicator_width, indicator_y - col_y

    local n_coins = #self._coin_indicators
    if n_coins > 0 then
        local radius = self._coin_indicators[1].radius
        local spacing = 0.5 * m
        local max_coins_per_row = math.floor((indicator_width + spacing) / (2 * radius + spacing))
        local rows = math.ceil(n_coins / max_coins_per_row)
        local row_height = 2 * radius + spacing
        local row_y = math.max(indicator_y + (indicator_height - (rows * row_height - spacing)) / 2, indicator_y)

        local fill_radius = radius - 2 * rt.settings.overworld.result_screen_scene.coin_indicator_line_width * rt.get_pixel_scale()
        fill_radius = fill_radius * 2 / 3

        local coin_index = 1
        for row = 0, rows - 1 do
            local coins_in_row = math.floor(n_coins / rows) + ternary(row < (n_coins % rows), 1, 0)
            local row_width = coins_in_row * (2 * radius + spacing) - spacing
            local row_x = indicator_x + (indicator_width - row_width) / 2

            for col = 0, coins_in_row - 1 do
                local entry = self._coin_indicators[coin_index]
                entry.x = row_x + col * (2 * radius + spacing) + radius
                entry.y = row_y + row * row_height + radius

                min_x = math.min(min_x, entry.x - (radius + 2 * spacing))
                max_x = math.max(max_x, entry.x + (radius + 2 * spacing))
                min_y = math.min(min_y, entry.y - (radius + 2 * spacing))
                max_y = math.max(max_y, entry.y + (radius + 2 * spacing))

                coin_index = coin_index + 1
            end
        end
    end

    -- total
    local total_grade_w, total_grade_h = self._total_grade:measure()
    local total_y = indicator_y + indicator_height - 2 * m
    local total_label_w, total_label_h = self._total_label:measure()
    self._total_label:reformat(x + 0.5 * width - 0.5 * total_label_w - total_grade_w, total_y, math.huge)
    --total_y = total_y + total_label_h

    local total_x = x + 0.5 * width - 0.5 * total_grade_w
    self._total_grade:reformat(total_x, total_y, total_grade_w, total_grade_h)

    for widget in range(
        self._stage_name_label,
        self._flow_title_label,
        self._flow_value_label,

        self._time_title_label,
        self._time_value_label,

        self._coins_title_label,
        self._coins_value_label
    ) do
        local widget_x, widget_y = widget:get_position()
        local widget_w, widget_h = widget:measure()
        min_x = math.min(min_x, widget_x)
        max_x = math.max(max_x, widget_x + widget_w)
        min_y = math.min(min_y, widget_y)
        max_y = math.max(max_y, widget_y + widget_h)
    end

    min_x = min_x - 8 * m
    max_x = max_x + 8 * m
    min_y = min_y - 2 * m
    max_y = max_y + 4 * m
    self._frame:reformat(min_x, min_y, max_x - min_x, max_y - min_y)

    self._y_offset = self._bounds.y + 0.5 * self._bounds.height - 0.5 * (max_y - min_y)
end

--- @brief
function ow.ResultScreenScene:_teleport_player(px, py)
    self._player:disable()

    local x, y, w, h = self._bounds:unpack()
    x, y = 0, 0

    local r = 2 * self._player:get_radius()
    local vx, vy = math.normalize(1, 0.5) --x + 0.5 * w - px, y + 0.5 * h - py)
    self._player:teleport_to(
        math.clamp(self._entry_x, x + r, x + w - r),
        math.clamp(self._entry_y, y + r, y + h - r)
    )

    self._player_velocity_x, self._player_velocity_y = math.normalize(vx, vy)
end

--- @brief
function ow.ResultScreenScene:exit()
    self._input:deactivate()
end

--- @brief
function ow.ResultScreenScene:_spawn_coin(x, y)
    local radius = rt.settings.overworld.coin.radius * rt.get_pixel_scale()
    local coin_shape = b2.Circle(0, 0, radius)
    local min_x, max_x = self._bounds.x, self._bounds.x + self._bounds.width
    local min_y, max_y = self._bounds.y, self._bounds.y + self._bounds.height
    local padding = 50

    local velocity_x, velocity_y = math.normalize(rt.random.number(-1, 1), rt.random.number(-1, 1))
    local position_x = math.clamp(x, min_x + padding, max_x - padding)
    local position_y = math.clamp(y, min_y + padding, max_y - padding)
    local body = b2.Body(self._world, b2.BodyType.DYNAMIC, position_x, position_y, coin_shape)
    body:set_collision_group(rt.settings.player.bounce_collision_group)
    body:set_collides_with(rt.settings.player.bounce_collision_group)
    body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
        if other_body:get_type() ~= b2.BodyType.STATIC then
            local entry = body:get_user_data()
            entry.velocity_x, entry.velocity_y = math.reflect(entry.velocity_x, entry.velocity_y, normal_x, normal_y)

            if other_body:has_tag("player") then
                self._player_velocity_x, self._player_velocity_y = math.reflect(
                    self._player_velocity_x, self._player_velocity_y,
                    -normal_x, -normal_y
                )
            end
        end
    end)

    return body, velocity_x, velocity_y
end

--- @brief
function ow.ResultScreenScene:update(delta)
    for updatable in range(
        self._player,
        self._world,
        self._frame,
        self._fireworks,
        self._camera,

        self._stage_name_label,

        self._coins_title_label,
        self._coins_grade_label,
        self._coins_value_label,

        self._time_title_label,
        self._time_grade_label,
        self._time_value_label,

        self._flow_title_label,
        self._flow_grade_label,
        self._flow_value_label,

        self._total_grade,
        self._total_label
    ) do
        updatable:update(delta)
    end

    if self._animations_active then
        for animation in range(
            self._flow_animation,
            self._coins_animation,
            self._time_animation,
            self._coin_indicator_animation,
            self._flow_grade_label_scale_animation,
            self._coins_grade_label_scale_animation,
            self._time_grade_label_scale_animation
        ) do
            animation:update(delta)
        end

        local update_grade = function(current, new, animation)
            if current ~= new then animation:reset() end
            return new
        end

        local flow = self._flow_animation:get_value() * self._flow
        self._flow_value_label:set_text(string.format_percentage(flow))

        local flow_w, flow_h = self._flow_value_label:measure()
        self._flow_value_label:reformat(self._flow_value_label_x - 0.5 * flow_w, self._flow_value_label_y)

        self._current_flow_grade = update_grade(
            self._current_flow_grade,
            rt.GameState:flow_to_flow_grade(flow),
            self._flow_grade_label_scale_animation
        )

        local time = math.mix(self._max_time, self._time, self._time_animation:get_value())
        self._time_value_label:set_text(string.format_time(time))

        local time_w, time_h = self._time_value_label:measure()
        self._time_value_label:reformat(self._time_value_label_x - 0.5 * time_w, self._time_value_label_y)

        self._current_time_grade = update_grade(
            self._current_time_grade,
            rt.GameState:time_to_time_grade(time, self._target_time),
            self._time_grade_label_scale_animation
        )

        local coins = math.round(self._coins_animation:get_value() * self._n_coins)
        self._coins_value_label:set_text(_format_count(coins, self._max_n_coins))

        local coins_w, coins_h = self._coins_value_label:measure()
        self._coins_value_label:reformat(self._coins_value_label_x - 0.5 * coins_w, self._coins_value_label_y)

        self._current_coins_grade = update_grade(
            self._current_coins_grade,
            rt.GameState:n_coins_to_coin_grade(coins, self._max_n_coins),
            self._coins_grade_label_scale_animation
        )

        local active_indicators = math.round(self._coin_indicator_animation:get_value() * self._max_n_coins)
        for i = 1, active_indicators do
            local entry = self._coin_indicators[i]
            if entry.is_collected and entry.body == nil then
                local body, vx, vy = self:_spawn_coin(entry.x, entry.y)
                entry.body, entry.velocity_x, entry.velocity_y = body, vx, vy
                body:set_user_data(entry)
                entry.coin:set_is_outline(false)
            end
        end
    end

    if self._transition_active then
        self._fade:update(delta)

        local player_x, player_y = self._player:get_position()
        local player_r = self._player:get_radius()

        -- follow player, after duration wait to exit screen
        self._transition_elapsed = self._transition_elapsed + delta

        local duration = rt.settings.overworld.result_screen_scene.exit_transition_fall_duration
        self._player:set_flow(self._transition_elapsed / duration)

        if self._transition_elapsed > duration then
            if self._transition_final_y == nil then
                self._transition_final_y = player_y
            else
                local screen_h = self._camera:get_world_bounds().height
                if self._fade_active ~= true and player_y > self._transition_final_y + 2 * screen_h then -- to make sure trail is off screen
                    self._fade:signal_connect("hidden", function(_)
                        rt.SceneManager:set_scene(self._transition_next)
                        return meta.DISCONNECT_SIGNAL
                    end)
                    self._fade:start()
                    self._fade_active = true
                end
            end
        else
            self._camera:move_to(player_x, player_y)
        end
    else
        local magnitude = 2 * rt.settings.menu_scene.title_screen.player_velocity
        self._player:set_velocity(self._player_velocity_x * magnitude, self._player_velocity_y * magnitude)
        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.body:set_velocity(
                    entry.velocity_x * magnitude,
                    entry.velocity_y * magnitude
                )
            end
        end
    end
end

--- @brief
function ow.ResultScreenScene:draw()
    if not self:get_is_active() then return end

    if self._screenshot ~= nil then
        love.graphics.setColor(1, 1, 1, 1)
        self._screenshot:draw()
    end

    self._camera:bind()

    love.graphics.push()
    love.graphics.translate(0, self._y_offset)
    self._frame:draw()

    local stencil = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.DRAW)
    self._frame:draw_mask()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    for widget in range(
        self._stage_name_label,

        self._coins_title_label,
        self._coins_value_label,

        self._time_title_label,
        self._time_value_label,

        self._flow_title_label,
        self._flow_value_label--,

        --self._total_grade,
        --self._total_label
    ) do
        widget:draw()
    end

    local draw = function(grade, x, y, scale)
        local w, h = self._grade_label_width, self._grade_label_height
        local label = self._grade_to_grade_label[grade]
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)
        label:draw()
        love.graphics.pop()
    end

    draw(self._current_flow_grade, self._flow_grade_label_x, self._flow_grade_label_y, self._flow_grade_label_scale_animation:get_value())
    draw(self._current_time_grade, self._time_grade_label_x, self._time_grade_label_y, self._time_grade_label_scale_animation:get_value())
    draw(self._current_coins_grade, self._coins_grade_label_x, self._coins_grade_label_y, self._coins_grade_label_scale_animation:get_value())

    -- draw ui coins
    for entry in values(self._coin_indicators) do
        entry.coin:draw(entry.x, entry.y)
    end

    rt.graphics.set_stencil_mode(nil)
    love.graphics.pop()

    -- draw floating coins
    for entry in values(self._coin_indicators) do
        if entry.body ~= nil then
            entry.coin:draw(entry.body:get_position())
        end
    end
    self._player:draw()

    if rt.SceneManager:get_is_bloom_enabled() then
        love.graphics.push("all")
        love.graphics.reset()
        local bloom = rt.SceneManager:get_bloom()
        bloom:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        love.graphics.translate(0, self._y_offset)
        self._frame:draw_bloom()
        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.coin:draw_bloom(entry.x, entry.y)
            end
        end
        love.graphics.pop()

        self._camera:bind()

        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.coin:draw_bloom(entry.body:get_position())
            end
        end
        self._player:draw_bloom()

        self._camera:unbind()

        bloom:unbind()
        love.graphics.pop()

        bloom:composite(rt.settings.menu_scene.bloom_composite)
    end

    if self._is_paused then
        self._option_background:draw()

        local graph = ternary(self._next_level_blocked,
            self._option_blocked_selection_graph,
            self._option_unblocked_selection_graph
        )

        if self._next_level_blocked then
            for option in values(self._options) do
                if option.can_be_blocked == true then
                    option.blocked_label:draw()
                elseif option.blocked_node:get_is_selected() then
                    option.frame:draw()
                    option.selected_label:draw()
                else
                    option.unselected_label:draw()
                end
            end
        else
            for option in values(self._options) do
                if option.unblocked_node:get_is_selected() then
                    option.frame:draw()
                    option.selected_label:draw()
                else
                    option.unselected_label:draw()
                end
            end
        end
    end

    if self._is_paused then
        self._option_control_indicator:draw()
    else
        self._grade_control_indicator:draw()
    end

    self._camera:unbind()

    if self._fade:get_is_active() then
        self._fade:draw()
    end
end

--- @brief
function ow.ResultScreenScene:_transition_to(scene)
    self._transition_active = true
    self._transition_next = scene
    self._transition_elapsed = 0
    self._transition_final_y = nil
    self._player:set_gravity(0.5)
    self._player:set_is_bubble(false)
    self._player:set_flow(1)
    self._player:set_trail_visible(true)
    self._body:set_is_enabled(false)
end

--- @brief
function ow.ResultScreenScene:_handle_button(which)
    if self._is_paused then
        if which == rt.InputAction.PAUSE then
            -- go back to result screen
            self:_unpause()
        else
            -- else handle menu
            if self._next_level_blocked == true then
                self._option_blocked_selection_graph:handle_button(which)
            else
                self._option_unblocked_selection_graph:handle_button(which)
            end
        end
    else
        -- skip animation on first press
        self._frame:skip()
        if self._animations_active then
            for animation in range(
                self._flow_animation,
                self._coins_animation,
                self._time_animation,
                self._coin_indicator_animation,
                self._flow_grade_label_scale_animation,
                self._coins_grade_label_scale_animation,
                self._time_grade_label_scale_animation
            ) do
                animation:skip()
            end

            self:update(0) -- update value labels
            self._animations_active = false
        else
            -- else transition to pause
            self:_pause()
        end
    end
end

--- @brief
function ow.ResultScreenScene:_on_next_stage()
    if not self._is_paused or self._next_level_blocked == true then return end

    require "overworld.overworld_scene"
    rt.SceneManager:set_scene(ow.OverworldScene, self._next_stage_id)
end

--- @brief
function ow.ResultScreenScene:_on_retry_stage()
    if not self._is_paused then return end

    require "overworld.overworld_scene"
    rt.SceneManager:set_scene(ow.OverworldScene, self._current_stage_id)
end

--- @brief
function ow.ResultScreenScene:_on_return_to_main_menu()
    if not self._is_paused then return end

    require "menu.menu_scene"
    rt.SceneManager:set_scene(mn.MenuScene, true) -- skip title screen
end

--- @brief
function ow.ResultScreenFrame:_on_show_splits()
    if not self._is_paused then return end
end

--- @brief
function ow.ResultScreenScene:_pause()
    self._is_paused = true
end

--- @brief
function ow.ResultScreenScene:_unpause()
    self._is_paused = false
end

--- @brief
function ow.ResultScreenScene:get_camera()
    return self._camera
end

--- @brief
function ow.ResultScreenScene:get_player()
    return self._player
end
