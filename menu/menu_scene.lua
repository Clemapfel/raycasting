require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.control_indicator"
require "common.timed_animation"

rt.settings.menu_scene = {
    player_max_falling_velocity = 1500,
    player_falling_x_damping = 0.98,
    player_falling_x_perturbation = 3,
    title_screen_player_velocity = 200, -- when reflecting
    falling_fraction_threshold = 2000, -- how long it takes to transition to stage select
    title_font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",

    stage_select_player_alignment = 1 / 3,
}

--- @class mn.MenuScene
mn.MenuScene = meta.class("MenuScene", rt.Scene)

mn.MenuSceneState = meta.enum("MenuSceneState", {
    TITLE_SCREEN = "TITLE_SCREEN",
    FALLING = "FALLING",
    STAGE_SELECT = "STAGE_SELECT",
    CREDITS = "CREDITS"
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
        _background_shader = rt.Shader("menu/title_screen_scene_background.glsl")
    end

    if _title_shader_no_sdf == nil then
        _title_shader_no_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 0 })
    end

    if _title_shader_sdf == nil then
        _title_shader_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 1 })
    end

    self._world = b2.World()
    self._world:set_use_fixed_timestep(false)

    self._player = state:get_player()
    self._player_velocity_x, self._player_velocity_y = -1, -1

    self._camera = rt.Camera()

    self._shader_camera_offset = { 0, 0 }
    self._shader_elapsed = 0
    self._shader_fraction = 0

    do -- title screen
        local translation = rt.Translation.menu_scene.title_screen
        local title_screen = {}
        self._title_screen = title_screen

        title_screen.control_indicator = rt.ControlIndicator({
                [rt.ControlIndicatorButton.JUMP] = translation.control_indicator_select,
                [rt.ControlIndicatorButton.UP_DOWN] = translation.control_indicator_move
            })
        title_screen.control_indicator:set_use_frame(false)

        title_screen.menu_items = {}
        title_screen.n_menu_items = 0
        title_screen.selected_item_i = 1

        for text in range(
            translation.stage_select,
            translation.settings,
            translation.credits,
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
            rt.error("TODO")
            rt.SceneManager:set_scene(mn.SettingsScene)
        end

        -- menu item: credits
        local credits_item = title_screen.menu_items[3]
        credits_item.activate = function()
            rt.error("TODO: credits")
            self:_set_state(mn.MenuSceneState.CREDITS)
        end

        -- menu item: quit
        local quit_item = title_screen.menu_items[4]
        quit_item.activate = function()
            exit(0)
        end

        title_screen.input = rt.InputSubscriber()
        title_screen.input:signal_connect("pressed", function(_, which)
            if which == rt.InputButton.JUMP then
                local item = title_screen.menu_items[title_screen.selected_item_i]
                item.activate()
            elseif which == rt.InputButton.UP then
                if title_screen.selected_item_i > 1 then
                    title_screen.selected_item_i = title_screen.selected_item_i - 1
                end
            elseif which == rt.InputButton.DOWN then
                if title_screen.selected_item_i < title_screen.n_menu_items then
                    title_screen.selected_item_i = title_screen.selected_item_i + 1
                end
            end
        end)

        title_screen.title_label_no_sdf = nil
        title_screen.title_label_sdf = nil
        title_screen.title_x, title_screen.title_y = 0, 0
        title_screen.boundaries = {}

        local duration = 2 * self._player:get_radius() / rt.settings.menu_scene.title_screen_player_velocity
        title_screen.opacity_fade_animation = rt.TimedAnimation(4 * duration)
    end

    do -- stage select
        local stage_select = {}
        self._stage_select = stage_select

        stage_select.input = rt.InputSubscriber()
        stage_select.input:signal_connect("pressed", function(_, which)
            if which == rt.InputButton.B then
                self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
            end
        end)

        stage_select.item_reveal_animation = rt.TimedAnimation(0.2, 0, 1, rt.InterpolationFunctions.SIGMOID)
        stage_select.items = {}
        stage_select.selected_item_i = 1
        stage_select.n_items = 0
        stage_select.menu_x = 0
        stage_select.menu_y = 0
        stage_select.menu_height = 1
        stage_select.menu_width = 1

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

            local item = {
                id = id,
                title_label = rt.Label(title_prefix .. title .. title_postfix, rt.FontSize.LARGE),

                flow_prefix_label = rt.Label(prefix_prefix .. translation.flow_prefix .. prefix_postfix),
                flow_colon_label = rt.Label(colon),
                flow_value_label = rt.Label(flow_prefix .. flow .. flow_postfix),

                time_prefix_label = rt.Label(prefix_prefix ..translation.time_prefix .. prefix_postfix),
                time_colon_label = rt.Label(colon),
                time_value_label = rt.Label(time_prefix .. time .. time_postfix),

                difficulty_prefix_label = rt.Label(prefix_prefix ..translation.difficulty_prefix .. prefix_postfix),
                difficulty_colon_label = rt.Label(colon),
                difficulty_value_label = rt.Label(difficulty_prefix .. difficulty .. difficulty_postfix),

                hrule_x = 0,
                hrule_y = 0,
                hrule_width = 1,
                hrule_height = 2 * love.graphics.getHeight() / rt.settings.native_height,
                frame = rt.Frame(),

                description_label = rt.Label(description_prefix .. description .. description_postfix, rt.FontSize.SMALL)
            }

            table.insert(stage_select.items, item)
            stage_select.n_items = stage_select.n_items + 1
        end
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
            item.difficulty_prefix_label,
            item.difficulty_colon_label,
            item.difficulty_value_label,
            item.flow_prefix_label,
            item.flow_colon_label,
            item.flow_value_label,
            item.time_prefix_label,
            item.time_colon_label,
            item.time_value_label,
            item.description_label
        ) do
            widget:realize()
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
        local font = rt.Font(rt.settings.menu_scene.title_font_path)
        title_screen.title_label_no_sdf = love.graphics.newTextBatch(font:get_native(font_size, rt.FontStyle.REGULAR, false), title)
        title_screen.title_label_sdf = love.graphics.newTextBatch(font:get_native(font_size, rt.FontStyle.REGULAR, true), title)

        local font_native = font:get_native(font_size)
        local title_w, title_h = font_native:getWidth(title), font_native:getHeight()

        title_screen.title_x = math.floor(0 - 0.5 * title_w)
        title_screen.title_y = math.floor(0 - title_h - outer_margin)

        local boundaries = title_screen.boundaries
        for boundary in values(boundaries) do
            boundary:destroy()
        end

        do -- physics walls
            local scale = self._camera:get_scale_delta()
            local w, h = width / scale, height / scale
            local cx, cw = 0 - 0.5 * w, 0 - 0.5 * h
            title_screen.enable_boundary_on_enter = true
            title_screen.boundaries = {
                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx, cw, cx + w, cw
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx + w, cw, cx + w, cw + h
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx + w, cw + h, cx, cw + h
                )),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                    cx, cw + h, cx, cw
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
        local menu_x = rt.settings.menu_scene.stage_select_player_alignment * width
        local menu_y = outer_margin
        local menu_w = rt.settings.menu_scene.stage_select_player_alignment * width - outer_margin
        local menu_h = height - 2 * outer_margin
        local menu_m = m

        stage_select.menu_x = menu_x
        stage_select.menu_y = menu_y
        stage_select.menu_height = menu_h
        stage_select.menu_width = menu_w

        --[[
        local max_prefix_w, max_value_w, max_colon_w = -math.huge, -math.huge, -math.huge
        for item in values(stage_select.items) do
            for label in range(
                item.flow_prefix_label,
                item.time_prefix_label,
                item.difficulty_prefix_label
            ) do
                max_prefix_w = math.max(max_prefix_w, select(1, label:measure()))
            end

            for label in range(
                item.flow_value_label,
                item.time_value_label,
                item.difficulty_value_label
            ) do
                max_value_w = math.max(max_value_w, select(1, label:measure()))
            end

            for label in range(
                item.flow_colon_label,
                item.time_colon_label,
                item.difficulty_colon_label
            ) do
                max_colon_w = math.max(max_colon_w, select(1, label:measure()))
            end
        end
        ]]--

        for item in values(stage_select.items) do
            local current_x, current_y = m, m
            item.title_label:reformat(current_x, current_y, menu_w)
            current_y = current_y + select(2, item.title_label:measure())

            for prefix_colon_value in range(
                { item.difficulty_prefix_label, item.difficulty_colon_label, item.difficulty_value_label },
                { item.flow_prefix_label, item.flow_colon_label, item.flow_value_label },
                { item.time_prefix_label, item.time_colon_label, item.time_value_label }
            ) do
                local prefix, colon, value = table.unpack(prefix_colon_value)

                local prefix_w, prefix_h = prefix:measure()
                prefix:reformat(current_x, current_y, math.huge)

                local value_w, value_h = value:measure()
                value:reformat(current_x + menu_w - menu_m - value_w, current_y, math.huge)

                local colon_w, colon_h = colon:measure()
                colon:reformat(current_x + 0.5 * menu_w - 0.5 * colon_w, math.huge)

                current_y = current_y + math.max(prefix_h, value_h, colon_h)
            end

            item.hrule_x, item.hrule_y = current_x, current_y
            item.hrule_width = menu_w - 2 * menu_m

            item.description_label:set_justify_mode(rt.JustifyMode.CENTER)
            item.description_label:reformat(current_x, current_y, menu_w - 2 * menu_m, math.huge)

            current_y = current_y + select(2, item.description_label:measure())
            item.frame:reformat(menu_x, menu_y, menu_w, menu_h)
        end
    end
end
--- @brief
function mn.MenuScene:enter()
    if self._player:get_world() ~= self._world then
        self._player:move_to_world(self._world)
    end

    self._player:disable()
    rt.SceneManager:set_use_fixed_timestep(true)

    if self._state == nil then
        self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
    else
        self:_set_state(self._state)
    end
end

--- @brief
function mn.MenuScene:exit()
    self._title_screen.input:deactivate()
    self._player:enable()
    self._camera:set_is_shaking(false)
end

--- @brief
function mn.MenuScene:_set_state(next)
    assert(next ~= nil)

    self._state = next
    self._title_screen.input:deactivate()
    self._stage_select.input:deactivate()

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
        self._player:set_opacity(0)
        self._title_screen.opacity_fade_animation:reset()

        return
    end

    if next == mn.MenuSceneState.FALLING or next == mn.MenuSceneState.STAGE_SELECT then
        self._stage_select.input:activate()
        self._player:set_gravity(1)
        self._player:set_is_bubble(false)

        for boundary in values(self._title_screen.boundaries) do
            boundary:set_is_sensor(true)
            boundary:signal_set_is_blocked("collision_start", true)
        end
    end
end

--- @brief
function mn.MenuScene:update(delta)
    self._world:update(delta)
    self._camera:update(delta)
    self._player:update(delta)

    self._shader_elapsed = self._shader_elapsed + delta
    self._shader_camera_offset = { self._camera:get_offset() }
    self._shader_camera_scale = self._camera:get_scale()
    self._shader_fraction = 0

    if self._state == mn.MenuSceneState.TITLE_SCREEN then
        -- stay centered, reflect player around walls
        self._camera:set_position(0, 0)
        local magnitude = rt.settings.menu_scene.title_screen_player_velocity
        self._player:set_velocity(
            self._player_velocity_x * magnitude,
            self._player_velocity_y * magnitude
        )

        local title_screen = self._title_screen

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

        self._player:set_opacity(title_screen.opacity_fade_animation:get_value())
        title_screen.opacity_fade_animation:update(delta)
        return
    end

    -- falling or level select
    local px, py = self._player:get_predicted_position()
    self._shader_fraction = math.clamp(py / rt.settings.menu_scene.falling_fraction_threshold, 0, 1)
    self._player:set_flow(self._shader_fraction)

    self._camera:set_shake_frequency(rt.InterpolationFunctions.EXPONENTIAL_ACCELERATION(self._shader_fraction))

    -- clamp velocity
    local vx, vy = self._player:get_velocity()
    local max_velocity = rt.settings.menu_scene.player_max_falling_velocity
    vx = math.min(vx * rt.settings.menu_scene.player_falling_x_damping, max_velocity)
    vy = math.min(vy, max_velocity)
    vx = vx + (rt.random.noise(self._shader_elapsed * 10, 0) * 2 - 1) * (rt.settings.menu_scene.player_falling_x_perturbation * (love.graphics.getHeight() / rt.settings.native_height)) * self._shader_fraction
    self._player:set_velocity(vx, vy)

    self._camera:set_shake_frequency(vy / max_velocity)

    -- transition player to left side of screen
    local offset_fraction = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(self._shader_fraction)
    local x_offset = offset_fraction * rt.settings.menu_scene.stage_select_player_alignment * self._bounds.width
    self._camera:move_to(px + x_offset, py)

    if self._state == mn.MenuSceneState.FALLING then
        -- transition to stage screen once player is in position
        if self._shader_fraction >= 1 then
            self:_set_state(mn.MenuSceneState.STAGE_SELECT)
        end
    elseif self._state == mn.MenuSceneState.STAGE_SELECT then

    end

end

local _black = { rt.Palette.BLACK:unpack() }

--- @brief
function mn.MenuScene:draw()
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
    elseif self._state == mn.MenuSceneState.STAGE_SELECT then
        local stage_select = self._stage_select
        local item = stage_select.items[stage_select.selected_item_i]

        love.graphics.push()
        love.graphics.translate(stage_select.menu_x, stage_select.menu_y)

        for widget in range(
            item.frame,
            item.title_label,
            item.difficulty_prefix_label,
            item.difficulty_colon_label,
            item.difficulty_value_label,
            item.flow_prefix_label,
            item.flow_colon_label,
            item.flow_value_label,
            item.time_prefix_label,
            item.time_colon_label,
            item.time_value_label,
            item.description_label
        ) do
            widget:draw()
        end

        rt.Palette.FOREGROUND:bind()
        love.graphics.rectangle("fill", item.hrule_x, item.hrule_y, item.hrule_width, item.hrule_height)
        love.graphics.pop()
    end

    self._camera:bind()
    self._player:draw()

    if self._dbg ~= nil then
        love.graphics.rectangle("line", self._dbg:unpack())
    end
    self._camera:unbind()
end

--- @brief
function mn.MenuScene:get_camera()
    return self._camera
end