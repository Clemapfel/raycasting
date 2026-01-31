require "common.label"
require "overworld.result_screen_frame"
require "overworld.fireworks"
require "menu.stage_grade_label"
require "common.camera"

rt.settings.overworld.result_screen_scene = {
    exit_transition_fall_duration = 2, -- seconds
    title_font = "assets/fonts/Baloo2/Baloo2-Bold.ttf",
    glyph_font = "assets/fonts/Baloo2/Baloo2-Medium.ttf",

    coin_indicator_n_vertices = 16,
    coin_indicator_line_width = 1.5,

    frame_reveal_animation_duration = 1, -- how long frame takes to expand
    values_reveal_animation = 2, -- how long it takes to get scroll to actual value
    screenshot_animation_duration = 2, -- how long background animation takes
    rainbow_transition_duration = 1,

    title_font_size = rt.FontSize.LARGE,
    heading_font_size = rt.FontSize.BIG,
    value_font_size = rt.FontSize.BIG,
    grade_font_size = rt.FontSize.GIGANTIC,

    fireworks_max_n_particles = math.huge,
    fireworks_n_particles = 300,
    fireworks_hue_range = 0.1,
    fireworks_max_n_per_instance = 3
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

local _screenshot_shader = rt.Shader("overworld/result_screen_scene_screenshot.glsl")

--- @brief
function ow.ResultScreenScene:instantiate()
    if _title_font == nil then _title_font = rt.Font(rt.settings.overworld.result_screen_scene.title_font) end
    if _glyph_font == nil then _glyph_font = rt.Font(rt.settings.overworld.result_screen_scene.glyph_font) end

    -- grades
    local translation = rt.Translation.result_screen_scene

    local new_heading = function(text)
        return rt.Glyph(text, {
            style = rt.FontStyle.BOLD,
            is_outlined = true,
            font_size = rt.settings.overworld.result_screen_scene.heading_font_size,
            font = _title_font
        })
    end

    local new_value = function(text, override)
        return rt.Glyph(text, {
            style = rt.FontStyle.BOLD,
            is_outlined = true,
            font_size = rt.settings.overworld.result_screen_scene.value_font_size,
            font = _glyph_font
        })
    end

    self._stage_name_label = rt.Label(_format_title(""), rt.settings.overworld.result_screen_scene.title_font_size, _title_font)
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

    self._flow_grade_label_x, self._flow_grade_label_y = 0, 0
    self._time_grade_label_x, self._time_grade_label_y = 0, 0
    self._coins_grade_label_x, self._coins_grade_label_y = 0, 0

    local scale_duration = 1
    local easing = rt.InterpolationFunctions.ENVELOPE
    local attack, decay = 0.05, 0.05
    local max_scale = 2
    self._flow_grade_label_scale_animation = rt.TimedAnimation(scale_duration, 1, max_scale, easing, attack, decay)
    self._time_grade_label_scale_animation = rt.TimedAnimation(scale_duration, 1, max_scale, easing, attack, decay)
    self._coins_grade_label_scale_animation = rt.TimedAnimation(scale_duration, 1, max_scale, easing, attack, decay)

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
    local duration = rt.settings.overworld.result_screen_scene.values_reveal_animation
    local easing = rt.InterpolationFunctions.SINUSOID_EASE_OUT
    self._coins_animation = rt.TimedAnimation(duration, 0, 1, easing)
    self._flow_animation = rt.TimedAnimation(duration, 0, 1, easing)
    self._time_animation = rt.TimedAnimation(duration, 0, 1, easing)
    self._coin_indicator_animation = rt.TimedAnimation(duration, 0, 1, rt.InterpolationFunctions.LINEAR)

    self._flow = 0
    self._max_n_coins = 0
    self._n_coins = 0
    self._time = 0
    self._time_rainbow_active = false
    self._coins_rainbow_active = false
    self._flow_rainbow_active = false
    self._rainbow_transition_animation = rt.TimedAnimation(
        rt.settings.overworld.result_screen_scene.rainbow_transition_duration,
        0, 1,
        rt.InterpolationFunctions.LINEAR
    )

    -- exit animation
    self._transition_active = false
    self._transition_next = nil -- Type<rt.Scene>
    self._transition_elapsed = 0
    self._transition_final_y = nil -- Number
    self._transition_fraction = 0
    self._fade = rt.Fade(2, "overworld/overworld_scene_fade.glsl")
    self._fade_active = false

    -- result animations
    self._frame = ow.ResultScreenFrame()
    self._fireworks = ow.Fireworks()

    self._camera = rt.Camera()
    self._screenshot_fraction_animation = rt.TimedAnimation(
        rt.settings.overworld.result_screen_scene.screenshot_animation_duration,
        0, 1,
        rt.InterpolationFunctions.LINEAR
    )
    self._screenshot_mesh = rt.MeshRectangle(0, 0, 1, 1)

    self._bloom = nil -- initialized on first draw

    self._is_paused = false
    do -- options
        require "menu.pause_menu"
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

            option.blocked_node:signal_connect(rt.InputAction.CONFIRM, to_invoke)
            option.unblocked_node:signal_connect(rt.InputAction.CONFIRM, to_invoke)

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
            return_to_main_menu_option
        }, false)

        add_options(self._option_blocked_selection_graph, {
            retry_option,
            -- next_stage_option disabled
            return_to_main_menu_option
        }, true)

        self._next_level_blocked = false
    end

    self._option_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.UP_DOWN, translation.option_control_indicator_move,
        rt.ControlIndicatorButton.CONFIRM, translation.option_control_indicator_select,
        rt.ControlIndicatorButton.PAUSE, translation.option_control_indicator_go_back
    )
    self._option_control_indicator:set_has_frame(false)

    self._grade_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.CONFIRM, translation.grade_control_indicator_continue
    )
    self._grade_control_indicator:set_has_frame(false)

    -- player boundaries
    self._entry_x, self._entry_y = 0, 0
    self._player_velocity_x, self._player_velocity_y = 0, 0
    self._player = rt.GameState:get_player()

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
function ow.ResultScreenScene:_spawn_fireworks(instance, x, y, hue)
    meta.assert_typeof(x, "Number", 2)
    meta.assert_typeof(y, "Number", 3)
    meta.assert_typeof(hue, "Number", 4)

    local settings = rt.settings.overworld.result_screen_scene
    local batch_state = "result_screen_scene_n_batches"

    if self._fireworks:get_n_particles() < settings.fireworks_max_n_particles
        and self._flow_rainbow_active
        and self._coins_rainbow_active
        and self._time_rainbow_active
        and (instance[batch_state] == nil or instance[batch_state] < settings.fireworks_max_n_per_instance)
    then
        local hue_range = rt.settings.overworld.result_screen_scene.fireworks_hue_range
        local batch_id = self._fireworks:spawn(settings.fireworks_n_particles,
            x, y, x, y,
            math.fract(hue - hue_range),
            math.fract(hue + hue_range)
        )

        -- store fireworks state so there is only one fireworks per instance
        if instance[batch_state] == nil then
            instance[batch_state] = 0
        end

        instance[batch_state] = instance[batch_state] + 1

        self._fireworks:signal_connect("done", function(_, done_id)
            if done_id == batch_id then
                instance[batch_state] = instance[batch_state] - 1
                if instance[batch_state] == 0 then instance[batch_state] = nil end
                return meta.DISCONNECT_SIGNAL
            end
        end)
    end
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
            local label = mn.StageGradeLabel(grade, rt.settings.overworld.result_screen_scene.grade_font_size)
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
        local bounds_x, bounds_y = x, y

        local aspect_ratio = width / height
        local w = aspect_ratio * rt.settings.native_height
        local h = rt.settings.native_height

        for body in values(self._bodies) do body:destroy() end

        self._bodies = {}
        for shape in range(
            b2.Segment(bx + 0, by + 0, bx + w, by + 0),
            b2.Segment(bx + w, by + 0, bx + w, by + h),
            b2.Segment(bx + w, by + h, bx + 0, by + h),
            b2.Segment(bx + 0, by + h, bx + 0, by + 0)
        ) do
            local body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, shape)
            body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, collision_x, collision_y)
                if other_body:has_tag("player") then
                    local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
                    self._player_velocity_x, self._player_velocity_y = math.reflect(
                        current_vx, current_vy,
                        normal_x, normal_y
                    )

                    local px, py = self._player:get_position()
                    self:_spawn_fireworks(self._player, px, py, self._player:get_hue())
                else -- coin
                    local entry = other_body:get_user_data()
                    entry.velocity_x, entry.velocity_y = math.reflect(
                        entry.velocity_x, entry.velocity_y,
                        normal_x, normal_y
                    )

                    local px, py = entry.body:get_position()
                    self:_spawn_fireworks(entry.body, px, py, entry.coin:get_hue())
                end
            end)

            body:set_collides_with(rt.settings.player.bounce_collision_group)
            body:set_collision_group(rt.settings.player.bounce_collision_group)
            body:set_mass(10e-3)
            table.insert(self._bodies, body)
        end

        self._camera:set_position(bounds_x + 0.5 * w, bounds_y + 0.5 * h)
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

    self._screenshot_mesh = rt.MeshRectangle(x, y, width, height)

    -- mutable elements
    self:_reformat_frame()
    self:update(0)
end

--- @brief
--- @param player_x Number in screen coordinates
--- @param player_y Number
function ow.ResultScreenScene:enter(player_x, player_y, screenshot, config)
    self._input:activate()

    rt.SceneManager:set_use_fixed_timestep(true)
    if rt.SceneManager:get_is_bloom_enabled() then
        rt.SceneManager:get_bloom():set_bloom_strength(rt.settings.menu_scene.bloom_strength)
    end

    meta.assert_typeof(player_x, "Number", 1)
    meta.assert_typeof(player_x, "Number", 2)
    meta.assert_typeof(config, "Table", 4)

    self._screenshot = screenshot
    self._screenshot_mesh:set_texture(screenshot)

    self._player:reset()
    self._player:move_to_world(self._world)
    self._player:set_gravity(0)
    self._player:set_is_bubble(true)

    local required_keys = {}
    for key in range(
        "stage_id",
        "coins",
        "time",
        "flow"
    ) do
        required_keys[key] = true
    end

    for key in keys(required_keys) do
        if config[key] == nil then
            rt.error("In ow.ResultScreenScene.enter: config does not have `",  key,  "` field")
        end
    end

    local id = config.stage_id
    config.stage_name = rt.GameState:get_stage_name(id)

    config.target_time = rt.GameState:get_stage_target_time(id)
    config.time_grade = rt.GameState:time_to_time_grade(config.time, config.target_time)
    config.flow_grade = rt.GameState:flow_to_flow_grade(config.flow)

    local n_coins = 0
    for coin in values(config.coins) do
        if coin == true then n_coins = n_coins + 1 end
    end

    config.coins_grade = rt.GameState:n_coins_to_coin_grade(n_coins, #config.coins)



    -- TODO
    config.flow_grade = rt.StageGrade.S
    config.time_grade = rt.StageGrade.S
    config.coins_grade = rt.StageGrade.S
    config.target_time = math.huge
    config.flow = 1
    for i = 1, #config.coins do
        config.coins[i] = true
    end
    n_coins = #config.coins
    -- TODO

    self._config = config
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

    self._rainbow_transition_animation:reset()
    self._time_rainbow_active = false
    self._flow_rainbow_active = false
    self._coins_rainbow_active = false

    self._current_time_grade = rt.StageGrade.NONE
    self._current_flow_grade = rt.StageGrade.NONE
    self._current_coins_grade = rt.StageGrade.NONE

    -- player position continuity
    self._entry_x, self._entry_y = player_x, player_y
    self:_teleport_player(self._entry_x, self._entry_y)
    self._camera:set_position(self._bounds.x + 0.5 * self._bounds.width, self._bounds.y + 0.5 * self._bounds.height)

    for entry in values(self._coin_indicators) do
        if entry.body ~= nil then
            entry.body:destroy()
        end
    end
    self._coin_indicators = {}

    self._max_n_coins = #config.coins
    self._n_coins = n_coins

    self:_initialize_coin_indicators()

    -- labels
    self._flow_value_label:set_text(string.format_percentage(0))
    self._time_value_label:set_text(string.format_time(0))
    self._coins_value_label:set_text(_format_count(0, self._max_n_coins))

    self:_reformat_frame() -- realign all mutable ui elements

    -- reset animations
    self._frame:reset_hue_range()

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

    self._frame:present()
    self._frame:signal_connect("presented", function(_)
        self._animations_active = true
        return meta.DISCONNECT_SIGNAL
    end)

    self._transition_active = false
    self._transition_fraction = 0
    self._transition_elapsed = math.huge
    for body in values(self._bodies) do
        body:set_is_enabled(true)
    end
    self._camera:set_position(self._bounds.x + 0.5 * self._bounds.width, self._bounds.y + 0.5 * self._bounds.height)
    self._fade:reset()
    self._fade_active = false

    -- reset pause menu
    self._option_blocked_selection_graph:set_selected_node(self._option_first_blocked_node)
    self._option_unblocked_selection_graph:set_selected_node(self._option_first_unblocked_node)
    self:_unpause()

    self._input:activate()
end

--- @brief
function ow.ResultScreenScene:_initialize_coin_indicators()
    if #self._coin_indicators == 0 or self._last_window_height ~= love.graphics.getHeight() then
        self._last_window_height = love.graphics.getHeight()
        self._coin_indicators = {}

        require "overworld.objects.coin"
        local radius = 1.5 * rt.settings.overworld.coin.radius * rt.get_pixel_scale()
        for i = 1, self._max_n_coins do
            local coin = ow.CoinParticle(radius)
            coin:set_hue(ow.Coin.index_to_hue(i, self._max_n_coins))

            local is_collected = self._config.coins[i]
            coin:set_is_outline(not is_collected)

            table.insert(self._coin_indicators, {
                radius = radius,
                coin = coin,
                x = 0,
                y = 0,
                velocity_x = 0,
                velocity_y = 0,
                mass = rt.random.number(0.5, 1.5),
                body = nil, -- b2.Body
                is_collected = is_collected,
                active = false
            })
        end
    end
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
    local current_y = y

    local max_title_w = -math.huge
    for title in range(
        self._coins_title_label,
        self._time_title_label,
        self._flow_title_label,
        self._coins_value_label,
        self._time_value_label,
        self._flow_value_label
    ) do
        title:reformat() -- force upscaling on window size change
        max_title_w = math.max(max_title_w, select(1, title:measure()))
    end

    local center_y = y + 0.5 * height

    -- columns
    local grade_ym = 10 -- sic, no pixel scale
    local grade_xm = 6 * m

    local column_w = max_title_w
    local column_total_w = 3 * column_w + 2 * grade_xm
    local column_x = x + 0.5 * width - 0.5 * column_total_w

    local column_top_y = math.huge
    local column_bottom_y = -math.huge

    for i, column in ipairs({
        { "coins", self._coins_title_label, self._coins_value_label },
        { "time", self._time_title_label, self._time_value_label },
        { "flow", self._flow_title_label, self._flow_value_label }
    }) do
        local which, title, value = table.unpack(column)

        local title_w, title_h = title:measure()
        local grade_w, grade_h = self._grade_label_w, self._grade_label_h
        local value_w, value_h = value:measure()

        -- align grade with center, everything else depends on its position
        local grade_y = center_y - 0.5 * grade_h

        if which == "flow" then
            self._flow_grade_label_x = column_x + 0.5 * column_w - 0.5 * grade_w
            self._flow_grade_label_y = grade_y

            self._flow_value_label_x = column_x + 0.5 * column_w
            self._flow_value_label_y = grade_y + grade_h + grade_ym
        elseif which == "time" then
            self._time_grade_label_x = column_x + 0.5 * column_w - 0.5 * grade_w
            self._time_grade_label_y = grade_y

            self._time_value_label_x = column_x + 0.5 * column_w
            self._time_value_label_y = grade_y + grade_h + grade_ym
        elseif which == "coins" then
            self._coins_grade_label_x = column_x + 0.5 * column_w - 0.5 * grade_w
            self._coins_grade_label_y = grade_y

            self._coins_value_label_x = column_x + 0.5 * column_w
            self._coins_value_label_y = grade_y + grade_h + grade_ym
        end

        local title_y = grade_y - grade_ym - title_h
        title:reformat(
            column_x + 0.5 * column_w - 0.5 * title_w,
            title_y
        )

        local value_y = grade_y + grade_h + grade_ym
        value:reformat(
            column_x + 0.5 * column_w - 0.5 * value_w,
            value_y
        )

        column_top_y = math.min(column_top_y, title_y)
        column_bottom_y = math.max(column_bottom_y, value_y + value_h)

        column_x = column_x + column_w + grade_xm
    end

    -- stage name
    local stage_name_w, stage_name_h = self._stage_name_label:measure()
    local stage_name_y = column_top_y - stage_name_h - grade_ym,
    self._stage_name_label:set_justify_mode(rt.JustifyMode.CENTER)
    self._stage_name_label:reformat(
        x,
        stage_name_y,
        width,
        math.huge
    )

    current_y = current_y + stage_name_h

    -- indicators
    self:_initialize_coin_indicators() -- check for window size change

    local indicator_y = column_bottom_y + m
    local indicator_width = column_total_w - 4 * m
    local indicator_x, indicator_height = x + 0.5 * width - 0.5 * indicator_width, stage_name_h

    local n_coins = #self._coin_indicators
    local coin_left_x, coin_right_x = math.huge, -math.huge
    local coin_bottom_y = indicator_y

    if n_coins > 0 then
        local radius = self._coin_indicators[1].radius
        local spacing = 0.5 * m
        local max_coins_per_row = math.floor((indicator_width + spacing) / (2 * radius + spacing))
        local n_rows = math.ceil(n_coins / max_coins_per_row)
        local row_height = 2 * radius + spacing
        local row_y = math.max(indicator_y + (indicator_height - (n_rows * row_height - spacing)) / 2, indicator_y)

        local fill_radius = radius - 2 * rt.settings.overworld.result_screen_scene.coin_indicator_line_width * rt.get_pixel_scale()
        fill_radius = fill_radius * 2 / 3

        coin_bottom_y = row_y + n_rows * row_height

        local coin_index = 1
        for row = 0, n_rows - 1 do
            local coins_in_row = math.floor(n_coins / n_rows) + ternary(row < (n_coins % n_rows), 1, 0)
            local row_width = coins_in_row * (2 * radius + spacing) - spacing
            local row_x = indicator_x + (indicator_width - row_width) / 2

            for col = 0, coins_in_row - 1 do
                local entry = self._coin_indicators[coin_index]
                entry.x = row_x + col * (2 * radius + spacing) + radius
                entry.y = row_y + row * row_height + radius

                coin_left_x = math.min(coin_left_x, entry.x)
                coin_right_x = math.max(coin_right_x, entry.x + radius)

                coin_index = coin_index + 1
            end
        end
    end


    local frame_xm, frame_ym = 8 * m, 4 * m

    local frame_w = math.max(column_total_w, stage_name_w, coin_right_x - coin_left_x) + 2 * frame_xm
    local frame_h = coin_bottom_y - stage_name_y + 2 * frame_ym
    self._frame:reformat(
        x + 0.5 * width - 0.5 * frame_w,
        y + 0.5 * height - 0.5 * frame_h,
        frame_w, frame_h
    )
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
    body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, collision_x, collision_y)
        if other_body:get_type() ~= b2.BodyType.STATIC then
            local entry = body:get_user_data()
            entry.velocity_x, entry.velocity_y = math.reflect(entry.velocity_x, entry.velocity_y, normal_x, normal_y)

            local px, py = entry.body:get_position()
            self:_spawn_fireworks(entry.body, px, py, entry.coin:get_hue())

            if other_body:has_tag("player") then
                self._player_velocity_x, self._player_velocity_y = math.reflect(
                    self._player_velocity_x, self._player_velocity_y,
                    -normal_x, -normal_y
                )

                px, py = self._player:get_position()
                self:_spawn_fireworks(self._player, px, py, self._player:get_hue())
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

        self._screenshot_fraction_animation
    ) do
        updatable:update(delta)
    end

    self._frame:set_hue(self._player:get_hue())

    if self._animations_active then
        local done = true
        for animation in range(
            self._flow_animation,
            self._coins_animation,
            self._time_animation,
            self._coin_indicator_animation,
            self._flow_grade_label_scale_animation,
            self._coins_grade_label_scale_animation,
            self._time_grade_label_scale_animation
        ) do
            if animation:update(delta) == false then
                done = false
            end
        end

        local update_grade = function(current, new, animation)
            local is_done = false
            if current ~= new then
                animation:reset()
                if new == rt.StageGrade.S then is_done = true end
            end
            return new, is_done
        end

        local flow = self._flow_animation:get_value() * self._flow
        self._flow_value_label:set_text(string.format_percentage(flow))

        local flow_w, flow_h = self._flow_value_label:measure()
        self._flow_value_label:reformat(self._flow_value_label_x - 0.5 * flow_w, self._flow_value_label_y)

        local flow_rainbow = false
        self._current_flow_grade, flow_rainbow = update_grade(
            self._current_flow_grade,
            rt.GameState:flow_to_flow_grade(flow),
            self._flow_grade_label_scale_animation
        )
        if flow_rainbow == true then
            self._flow_rainbow_active = true
        end

        local time = math.mix(self._max_time, self._time, self._time_animation:get_value())
        self._time_value_label:set_text(string.format_time(time))

        local time_w, time_h = self._time_value_label:measure()
        self._time_value_label:reformat(self._time_value_label_x - 0.5 * time_w, self._time_value_label_y)

        local time_rainbow = false
        self._current_time_grade, time_rainbow = update_grade(
            self._current_time_grade,
            rt.GameState:time_to_time_grade(time, self._target_time),
            self._time_grade_label_scale_animation
        )
        if time_rainbow then
            self._time_rainbow_active = true
        end

        local coins = math.round(self._coins_animation:get_value() * self._n_coins)
        self._coins_value_label:set_text(_format_count(coins, self._max_n_coins))

        local coins_w, coins_h = self._coins_value_label:measure()
        self._coins_value_label:reformat(self._coins_value_label_x - 0.5 * coins_w, self._coins_value_label_y)

        local coins_rainbow = false
        self._current_coins_grade, coins_rainbow = update_grade(
            self._current_coins_grade,
            rt.GameState:n_coins_to_coin_grade(coins, self._max_n_coins),
            self._coins_grade_label_scale_animation
        )
        if coins_rainbow then
            self._coins_rainbow_active = true
        end

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

        if self._time_rainbow_active and self._flow_rainbow_active and self._coins_rainbow_active then
            if self._rainbow_transition_animation:get_elapsed() == 0 then -- on first update
                local px, py = self._player:get_position()
                self:_spawn_fireworks(self._player, px, py, self._player:get_hue())

                for entry in values(self._coin_indicators) do
                    px, py = entry.body:get_position()
                    self:_spawn_fireworks(entry.body, px, py, entry.coin:get_hue())
                end
            end

            if not self._rainbow_transition_animation:update(delta) then
                done = false
            end

            self._frame:set_hue_range(2 * self._rainbow_transition_animation:get_value())
        end

        if done then
            self._animations_active = false
        end
    end

    -- coin and player velocity
    require "menu.menu_scene"
    local magnitude = 2 * rt.settings.menu_scene.title_screen.player_velocity

    if self._transition_active then
        self._fade:update(delta)

        local player_x, player_y = self._player:get_position()
        local player_r = self._player:get_radius()

        -- follow player, after duration wait to exit screen
        self._transition_elapsed = self._transition_elapsed + delta

        local duration = rt.settings.overworld.result_screen_scene.exit_transition_fall_duration
        self._transition_fraction = self._transition_elapsed / duration
        self._player:set_flow(self._transition_fraction)

        local px, py = self._player:get_position()
        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.velocity_x, entry.velocity_y = math.normalize(math.subtract(px, py, entry.x, entry.y))
                local coin_magnitude = math.distance(entry.x, entry.y, px, py) / self._bounds.height * magnitude
                entry.body:set_velocity(entry.velocity_x * coin_magnitude, entry.velocity_y * coin_magnitude)
            end
        end

        if self._transition_elapsed > duration then
            if self._transition_final_y == nil then
                self._transition_final_y = player_y
            else
                local screen_h = self._camera:get_world_bounds().height
                if self._fade_active ~= true and player_y > self._transition_final_y + 2 * screen_h then -- to make sure trail is off screen
                    self._fade:signal_connect("hidden", function(_)
                        require "overworld.overworld_scene"
                        rt.SceneManager:set_scene(ow.OverworldScene, table.unpack(self._transition_next))
                        return meta.DISCONNECT_SIGNAL
                    end)
                    self._fade:start()
                    self._fade_active = true
                end
            end
        else
            self._camera:move_to(self._player:get_position())
        end
    else
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

    local fraction = self._screenshot_fraction_animation:get_value()
    love.graphics.setColor(1, 1, 1, fraction)

    _screenshot_shader:bind()
    _screenshot_shader:send("rainbow_fraction", self._rainbow_transition_animation:get_value())
    _screenshot_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _screenshot_shader:send("fraction", self._screenshot_fraction_animation:get_value())
    _screenshot_shader:send("transition_fraction", self._transition_fraction)
    _screenshot_shader:send("screen_to_world_transform", self._camera:get_transform():inverse())
    _screenshot_shader:send("player_color", { self._player:get_color():unpack() })
    self._screenshot_mesh:draw()
    _screenshot_shader:unbind()

    self._camera:bind()

    love.graphics.push()

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
        self._flow_value_label
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

    self._fireworks:draw()

    -- draw floating coins
    for entry in values(self._coin_indicators) do
        if entry.body ~= nil then
            entry.coin:draw(entry.body:get_position())
        end
    end
    self._player:draw()

    self._camera:unbind()

    if rt.SceneManager:get_is_bloom_enabled() then
        love.graphics.push("all")
        love.graphics.reset()

        self._camera:bind()

        local bloom = rt.SceneManager:get_bloom()
        bloom:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        self._frame:draw_bloom()

        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.coin:draw_bloom(entry.x, entry.y)
            end
        end
        love.graphics.pop()

        for entry in values(self._coin_indicators) do
            if entry.body ~= nil then
                entry.coin:draw_bloom(entry.body:get_position())
            end
        end

        self._player:draw_bloom()

        bloom:unbind()
        love.graphics.pop()

        self._camera:unbind()

        bloom:composite(rt.settings.menu_scene.bloom_composite)
    end


    if self._is_paused and not self._transition_active then
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

    if self._fade:get_is_active() then
        self._fade:draw()
    end
end

--- @brief
function ow.ResultScreenScene:_transition_to(...)
    self._transition_active = true
    self._transition_next = { ... }
    self._transition_elapsed = 0
    self._transition_final_y = nil
    self._player:set_gravity(0.5)
    self._player:set_is_bubble(false)
    self._player:set_flow(1)
    self._player:set_trail_is_visible(true)

    for body in values(self._bodies) do
        body:set_is_enabled(false)
    end
end

--- @brief
function ow.ResultScreenScene:_handle_button(which)
    if self._is_paused then
        if which == rt.InputAction.PAUSE or which == rt.InputAction.BACK then
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
    self:_transition_to(self._next_stage_id, true)
end

--- @brief
function ow.ResultScreenScene:_on_retry_stage()
    if not self._is_paused then return end
    self:_transition_to(self._current_stage_id, false)
end

--- @brief
function ow.ResultScreenScene:_on_return_to_main_menu()
    if not self._is_paused then return end

    require "menu.menu_scene"
    rt.SceneManager:set_scene(mn.MenuScene, true) -- skip title screen
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
