require "common.label"
require "overworld.result_screen_frame"
require "overworld.fireworks"

rt.settings.overworld.result_screen_scene = {
    exit_transition_fall_duration = 2, -- seconds
    title_font = "assets/fonts/Baloo2/Baloo2-Bold.ttf",
    glyph_font = "assets/fonts/Baloo2/Baloo2-Medium.ttf",

    coin_indicator_n_vertices = 16
}

--- @class ow.ResultScreenScene
ow.ResultScreenScene = meta.class("ResultScreenScene", rt.Scene)

local _title_font, _glyph_font

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

    self._stage_name_label = rt.Glyph("TODO", {
        style = rt.FontStyle.BOLD,
        is_underlined = true,
        is_outlined = true,
        font_size = rt.FontSize.LARGE,
        font = _title_font
    })

    self._flow_title_label = new_heading(translation.flow)
    self._time_title_label = new_heading(translation.time)
    self._coins_title_label = new_heading(translation.coins)
    self._coins = {}
    self._coin_indicators = {}

    self._flow_value_label = new_value(string.format_percentage(0))
    self._time_value_label = new_value(string.format_time(0))
    self._coins_value_label = new_value("0 / 0")

    self._total_label = new_heading(translation.total)

    local grade_size = rt.FontSize.LARGER
    self._total_grade = mn.StageGradeLabel(rt.StageGrade.S, rt.FontSize.GIGANTIC)
    self._flow_grade_label = mn.StageGradeLabel(rt.StageGrade.A, grade_size)
    self._time_grade_label = mn.StageGradeLabel(rt.StageGrade.B, grade_size)
    self._coins_grade_label = mn.StageGradeLabel(rt.StageGrade.F, grade_size)

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

    self._is_paused = false
    do -- options
        local unselected_prefix, unselected_postfix = rt.settings.menu.pause_menu.label_prefix, rt.settings.menu.pause_menu.label_postfix
        local selected_prefix, selected_postfix = unselected_prefix .. "<color=SELECTION>", "</color>" .. unselected_postfix
        self._options = {}
        self._option_selection_graph = rt.SelectionGraph()
        self._option_background = rt.Background("menu/pause_menu.glsl", true) -- sic, use same as level pause

        local function add_option(text, function_name)
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
                node = rt.SelectionGraphNode()
            }

            option.frame:set_base_color(1, 1, 1, 0)
            option.frame:set_selection_state(rt.SelectionState.ACTIVE)
            option.frame:set_thickness(rt.settings.menu.pause_menu.selection_frame_thickness)

            option.node:signal_connect(rt.InputAction.A, function(_)
                self[function_name](self) -- self:function_name()
            end)

            option.node:signal_connect(rt.InputAction.B, function(_)
                self:_unpause()
            end)

            self._option_selection_graph:add(option.node)
            table.insert(self._options, option)
        end

        add_option(translation.option_retry_stage, "_on_retry_stage")
        add_option(translation.option_next_stage, "_on_next_stage")
        add_option(translation.option_return_to_main_menu, "_on_return_to_main_menu")

        -- connect nodes
        for i = 1, #self._options, 1 do
            local before = math.wrap(i-1, #self._options)
            local after = math.wrap(i+1, #self._options)

            local element = self._options[i]
            element.node:set_up(self._options[before].node)
            element.node:set_down(self._options[after].node)
        end
    end

    -- player boundaries
    self._entry_x, self._entry_y = 0, 0
    self._player_velocity_x, self._player_velocity_y = 0, 0
    self._player = state:get_player()

    do
        self._world = b2.World()
        -- body and teleport updated in size_allocate

        self._player:reset()
        self._player:move_to_world(self._world)
        self._player:set_gravity(0)
        self._player:set_is_bubble(true)

        if self._body ~= nil then self._body:set_is_enabled(true) end
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if not self._is_paused then
            if which == rt.InputAction.PAUSE then
                self:_pause()
            end
        else
            if which == rt.InputAction.PAUSE then
                self:_unpause()
            else
                self._option_selection_graph:handle_button(which)
            end
        end
    end)


    -- TODO
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then
            self:_transition_to(mn.MenuScene)
        end
    end)
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
        self._coins_grade_label,
        self._coins_value_label,

        self._flow_title_label,
        self._flow_grade_label,
        self._flow_value_label,
        self._total_grade,

        self._time_title_label,
        self._time_grade_label,
        self._time_value_label
    ) do
        widget:realize()
    end
end

--- @brief
function ow.ResultScreenScene:size_allocate(x, y, width, height)
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
            local w, h = math.max(selected_w, unselected_w), math.max(selected_h, unselected_h)

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

            current_y = current_y + h + m
        end
    end

    self:_reformat_frame()
end

--- @brief
--- @param player_x Number in screen coordinates
--- @param player_y Number
--- @param screenshot RenderTexture?
function ow.ResultScreenScene:enter(player_x, player_y, screenshot, config)
    if screenshot == nil then screenshot = self._screenshot end
    rt.SceneManager:set_use_fixed_timestep(true)
    self._screenshot = screenshot -- can be nil

    meta.assert_typeof(player_x, "Number", 1)
    meta.assert_typeof(player_x, "Number", 2)
    if screenshot ~= nil then
        meta.assert_typeof(screenshot, rt.RenderTexture, 3)
    end
    meta.assert_typeof(config, "Table", 4)

    self._config = config
    local required_keys = {
        coins = true
    }

    for key in keys(required_keys) do
        if self._config[key] == nil then
            rt.error("In ow.ResultScreenScene.enter: config does not have `" .. key .. "` field")
        end
    end

    -- player position continuity
    self._entry_x, self._entry_y = player_x, player_y
    self:_teleport_player(self._entry_x, self._entry_y)
    self._camera:set_position(self._bounds.x + 0.5 * self._bounds.width, self._bounds.y + 0.5 * self._bounds.height)

    self._coin_indicators = {}

    do -- coins
        for entry in values(self._coins) do entry.body:destroy() end

        self._max_n_coins = #(self._config.coins)
        self._n_coins = 0
        for b in values(self._config.coins) do
            if not meta.is_boolean(b) then
                rt.error("In ow.ResultScreen.enter: `coins` field does not contain exclusively booleans")
            end

            if b then self._n_coins = self._n_coins + 1 end
        end

        self._coins_value_label:set_text(self._n_coins .. " / " .. self._max_n_coins)

        self._coins = {}
        local radius = rt.settings.overworld.coin.radius * rt.get_pixel_scale()
        local coin_shape = b2.Circle(0, 0, radius)
        local min_x, max_x = self._bounds.x, self._bounds.x + self._bounds.width
        local min_y, max_y = self._bounds.y, self._bounds.y + self._bounds.height
        local padding = 50

        for i = 1, self._max_n_coins do
            local velocity_x, velocity_y = math.normalize(rt.random.number(0, 1), rt.random.number(0, 1))
            local position_x = rt.random.number(min_x + padding, max_x - padding)
            local position_y = rt.random.number(min_y + padding, max_y - padding)
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

            local coin = ow.CoinParticle(radius)
            local hue = ow.Coin.index_to_hue(i, self._max_n_coins)
            coin:set_hue(hue)

            local entry = {
                coin = coin,
                body = body,
                velocity_x = velocity_x,
                velocity_y = velocity_y
            }

            body:set_user_data(entry)
            table.insert(self._coins, entry)

            table.insert(self._coin_indicators, {
                radius = radius * 2 / 3,
                x = 0,
                y = 0,
                fill_color = { rt.lcha_to_rgba(0.5, 0.7, hue, 1) },
                fill_shape = { 0, 0, radius * 2 / 3 }, -- love.Circle
                line_color = { rt.lcha_to_rgba(0.8, 1, hue, 1) },
                line_shape = { 0, 0, 1, 1 }, -- love.Line
                is_collected = self._config.coins[i]
            })
        end
    end

    self:_reformat_frame() -- realign all mutable ui elements

    -- reset animations
    self._fade:reset()
    self._fade_active = false
    self._frame:present(self._entry_x, self._entry_y)

    -- reset pause menu
    self._option_selection_graph:set_selected_node(self._options[1].node)
    self:_unpause()

    self._input:activate()
end


--- @brief
function ow.ResultScreenScene:_reformat_frame()
    local x, y, width, height = self:get_bounds():unpack()
    self._frame:reformat(x, y, width, height)

    local m = rt.settings.margin_unit

    local max_title_w = -math.huge
    for title in range(
        self._coins_title_label,
        self._time_title_label,
        self._flow_title_label
    ) do
        max_title_w = math.max(max_title_w, select(1, title:measure()))
    end

    local title_w, title_h = self._stage_name_label:measure()
    self._stage_name_label:reformat(
        x + 0.5 * width - 0.5 * title_w,
        y + m,
        width, height
    )

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

    local coins_grade_w, coins_grade_h = self._coins_grade_label:measure()
    self._coins_grade_label:reformat(coins_x + 0.5 * coins_w - 0.5 * coins_grade_w, coins_y, coins_grade_w, coins_grade_h)
    coins_y = coins_y + coins_grade_h + m

    local coins_value_w, coins_value_h = self._coins_value_label:measure()
    self._coins_value_label:reformat(coins_x + 0.5 * coins_w - 0.5 * coins_value_w, coins_y, math.huge)

    -- time
    local time_x, time_y, time_w = col_x, col_y, col_w
    col_x = col_x + col_w

    local time_title_w, time_title_h = self._time_title_label:measure()
    self._time_title_label:reformat(time_x + 0.5 * time_w - 0.5 * time_title_w, time_y, math.huge)
    time_y = time_y + time_title_h + m

    local time_grade_w, time_grade_h = self._time_grade_label:measure()
    self._time_grade_label:reformat(time_x + 0.5 * time_w - 0.5 * time_grade_w, time_y, time_grade_w, time_grade_h)
    time_y = time_y + time_grade_h + m

    local time_value_w, time_value_h = self._time_value_label:measure()
    self._time_value_label:reformat(time_x + 0.5 * time_w - 0.5 * time_value_w, time_y, math.huge)

    -- flow
    local flow_x, flow_y, flow_w = col_x, col_y, col_w
    col_x = col_x + col_w

    local flow_title_w, flow_title_h = self._flow_title_label:measure()
    self._flow_title_label:reformat(flow_x + 0.5 * flow_w - 0.5 * flow_title_w, flow_y, math.huge)
    flow_y = flow_y + flow_title_h + m

    local flow_grade_w, flow_grade_h = self._flow_grade_label:measure()
    self._flow_grade_label:reformat(flow_x + 0.5 * flow_w - 0.5 * flow_grade_w, flow_y, flow_grade_w, flow_grade_h)
    flow_y = flow_y + flow_grade_h + m

    local flow_value_w, flow_value_h = self._flow_value_label:measure()
    self._flow_value_label:reformat(flow_x + 0.5 * flow_w - 0.5 * flow_value_w, flow_y, math.huge)

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

        local coin_index = 1
        for row = 0, rows - 1 do
            local coins_in_row = math.floor(n_coins / rows) + ternary(row < (n_coins % rows), 1, 0)
            local row_width = coins_in_row * (2 * radius + spacing) - spacing
            local row_x = indicator_x + (indicator_width - row_width) / 2

            for col = 0, coins_in_row - 1 do
                local entry = self._coin_indicators[coin_index]
                entry.x = row_x + col * (2 * radius + spacing) + radius
                entry.y = row_y + row * row_height + radius

                entry.fill_shape[1], entry.fill_shape[2] = entry.x, entry.y

                entry.line_shape = {}
                local n_vertices = rt.settings.overworld.result_screen_scene.coin_indicator_n_vertices
                for i = 1, n_vertices do
                    local angle = (i - 1) / n_vertices * (2 * math.pi)
                    table.insert(entry.line_shape, entry.x + math.cos(angle) * radius)
                    table.insert(entry.line_shape, entry.y + math.sin(angle) * radius)
                end

                table.insert(entry.line_shape, entry.line_shape[1])
                table.insert(entry.line_shape, entry.line_shape[2])

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
        for entry in values(self._coins) do
            entry.body:set_velocity(entry.velocity_x * magnitude, entry.velocity_y * magnitude)
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

    self._frame:draw()

    for entry in values(self._coins) do
        entry.coin:draw(entry.body:get_position())
    end
    self._player:draw()

    for widget in range(
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
        widget:draw()
    end

    love.graphics.setLineWidth(1.5)
    for entry in values(self._coin_indicators) do
        if entry.is_collected then
            love.graphics.setColor(entry.fill_color)
            love.graphics.circle("fill", table.unpack(entry.fill_shape))
        end
        love.graphics.setColor(entry.line_color)
        love.graphics.line(table.unpack(entry.line_shape))
    end

    if self._is_paused then
        self._option_background:draw()
        for option in values(self._options) do
            if option.node:get_is_selected() then
                option.frame:draw()
                option.selected_label:draw()
            else
                option.unselected_label:draw()
            end
        end
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
function ow.ResultScreenScene:_on_next_stage()
    if not self._is_paused then return end

end

--- @brief
function ow.ResultScreenScene:_on_retry_stage()
    if not self._is_paused then return end
end

--- @brief
function ow.ResultScreenScene:_on_return_to_main_menu()
    if not self._is_paused then return end
end

--- @brief
function ow.ResultScreenScene:_pause()

end

--- @brief
function ow.ResultScreenScene:_unpause()

end

--- @brief
function ow.ResultScreenScene:get_camera()
    return self._camera
end
