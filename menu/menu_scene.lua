require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.control_indicator"
require "common.timed_animation"
require "common.fade"
require "menu.stage_select_page_indicator"
require "menu.stage_select_particle_frame"
require "menu.stage_grade_label"
require "menu.stage_select_debris_emitter"
require "overworld.coin_particle"

rt.settings.menu_scene = {
    player_max_falling_velocity = 1000,
    player_falling_x_damping = 0.98,
    player_falling_x_perturbation = 3,
    exit_acceleration = 60, -- per second

    title_screen = {
        title_font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
        menu_font_path_regular = "assets/fonts/Baloo2/Baloo2-Medium.ttf",
        menu_font_path_bold = "assets/fonts/Baloo2/Baloo2-ExtraBold.ttf",
        player_velocity = 100, -- when reflecting
        player_offset_magnitude = 0.05 * 2 * math.pi, -- when holding left / right
        falling_fraction_threshold = 2000, -- how long it takes to transition to stage select
    },

    stage_select = {
        player_alignment = 1 / 3,
        reveal_animation_duration = 1,
        scroll_speed = 1,
        exititing_fraction = 2, -- number of screen heights until fade out starts
        scroll_ticks_per_second = 2,
        max_debris_speedup = 4
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

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then _background_shader:recompile() end
    end)

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

        title_screen.menu_font = rt.Font(
            rt.settings.menu_scene.title_screen.menu_font_path_regular,
            rt.settings.menu_scene.title_screen.menu_font_path_bold
        )

        title_screen.menu_font:set_line_spacing(0.75)

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
                unselected_label = rt.Label("<o>" .. text .. "</o>", rt.FontSize.LARGE, title_screen.menu_font),
                selected_label = rt.Label("<o><rainbow><b><color=SELECTION>" .. text .. "</color></b></o></rainbow>", rt.FontSize.LARGE, title_screen.menu_font),
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

        stage_select.scroll_elapsed = 0
        stage_select.scroll_direction = 0 -- -1 up, 1 down, 0 no scroll

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
                    stage_select.debris_emitter:reset()
                    stage_select.debris_emitter_initialized = false
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

        local stage_ids = rt.GameState:list_stage_ids()
        table.sort(stage_ids, function(a, b)
            return rt.GameState:get_stage_difficulty(a) < rt.GameState:get_stage_difficulty(b)
        end)

        stage_select.n_items = 0


        stage_select.items = {}
        for id in values(stage_ids) do
            table.insert(stage_select.items, mn.StageSelectItem(id))
            stage_select.n_items = stage_select.n_items + 1
        end

        stage_select.item_frame = mn.StageSelectParticleFrame(table.unpack(stage_select.items))
        stage_select.page_indicator = mn.StageSelectPageIndicator(stage_select.n_items)
        stage_select.debris_emitter = mn.StageSelectDebrisEmitter()
        stage_select.debris_emitter_initialized = false

        for id in values(stage_ids) do
            table.insert(stage_select.items, mn.StageSelectItem(id))
        end

        local translation = rt.Translation.menu_scene.stage_select
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
        item:realize()
    end

    self._stage_select.page_indicator:realize()
    self._stage_select.item_frame:realize()
    self._stage_select.debris_emitter:realize()
    self._stage_select.control_indicator:realize()
    self._stage_select.control_indicator:set_has_frame(false)

    self:_create_from_state()
end

function mn.MenuScene:_create_from_state()
    local stage_select = self._stage_select
    for i = 1, stage_select.n_items do
        local item = stage_select.items[i]
        item:create_from_state()

        local time, flow, total = rt.GameState:get_stage_grades(item:get_stage_id())
        stage_select.page_indicator:set_stage_grade(i, total)
        stage_select.page_indicator:set_stage_grade(i, ({
            rt.StageGrade.A,
            rt.StageGrade.S,
            rt.StageGrade.SS
        })[i]) -- TODO
    end
end

--- @brief
function mn.MenuScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 3 * m

    if rt.GameState:get_is_bloom_enabled() then
        self._bloom = rt.Bloom(width, height)
    end

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
        stage_select.debris_emitter:reformat(self._bounds)

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
        local w = (1 - rt.settings.menu_scene.stage_select.player_alignment) * width - 2 * outer_margin - page_indicator_w - 2 * outer_margin
        local menu_x = math.round(current_x - w)
        local menu_w = w
        stage_select.item_frame:reformat(menu_x, y + 0.5 * height - 0.5 * menu_h, menu_w, menu_h)
        stage_select.reveal_width = menu_w + page_indicator_w + 4 * outer_margin
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
    self._player:update(delta)
    self._camera:update(delta)

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

        for menu_item in values(self._title_screen.menu_items) do
            menu_item.unselected_label:update(delta)
            menu_item.selected_label:update(delta)
        end

        return
    end

    -- falling or level select
    local px, py = self._player:get_predicted_position()
    self._shader_fraction = math.clamp(py / rt.settings.menu_scene.title_screen.falling_fraction_threshold, 0, 1)
    self._player:set_flow(self._shader_fraction)

    local max_speedup = rt.settings.menu_scene.stage_select.max_debris_speedup
    local speedup = math.max(0.1, self._stage_select.item_frame:get_hue() * max_speedup)

    -- clamp velocity
    local vx, vy = self._player:get_velocity()
    local max_velocity = rt.settings.menu_scene.player_max_falling_velocity

    vx = math.min(vx * rt.settings.menu_scene.player_falling_x_damping, max_velocity)
    vy = math.min(vy, max_velocity)

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

    if offset_fraction > 0.95 then
        stage_select.debris_emitter:update(delta)
        stage_select.debris_emitter:set_player_position(self._camera:world_xy_to_screen_xy(self._player:get_position()))

        if stage_select.initial_offset == nil then
            stage_select.initial_offset = self._camera:get_offset()
        end
        stage_select.debris_emitter:set_offset(select(1, self._camera:get_offset()) - stage_select.initial_offset, 0)
    end

    if offset_fraction > 0.5 then
        stage_select.item_reveal_animation:update(delta)
        stage_select.page_indicator:update(delta)
        stage_select.item_frame:update(delta)
    end

    stage_select.page_indicator:set_hue(stage_select.item_frame:get_hue())
    stage_select.debris_emitter:set_speedup(speedup)

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
                stage_select.item_frame:set_selected_page(stage_select.selected_item_i)
            end

            stage_select.scroll_elapsed = stage_select.scroll_elapsed + delta
        end
    elseif self._state == mn.MenuSceneState.EXITING then
        if stage_select.waiting_for_exit then
            -- wait for player to exit screen, then fade out
            if select(2, self._camera:world_xy_to_screen_xy(self._player:get_position())) > rt.settings.menu_scene.stage_select.exititing_fraction * love.graphics.getHeight() then
                self._fade:start(true, false)
                self._fade:signal_connect("hidden", function()
                    require "overworld.overworld_scene"
                    local item = stage_select.items[stage_select.selected_item_i]
                    if item ~= nil then
                        rt.SceneManager:push(ow.OverworldScene, item:get_stage_id(), true) -- with titlecard
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

    if rt.GameState:get_is_bloom_enabled() and self._bloom == nil then
        self._bloom = rt.Bloom(self._bounds.width, self._bounds.height)
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

    local bloom_updated = false

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

        if rt.GameState:get_is_bloom_enabled() then
            self._bloom:bind()
            love.graphics.clear(0, 0, 0, 0)

            self._camera:bind()
            self._player:draw_bloom()
            self._camera:unbind()

            love.graphics.push()
            love.graphics.translate(self._camera:get_offset())
            _title_shader_no_sdf:bind()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(title_screen.title_label_no_sdf, title_screen.title_x, title_screen.title_y)
            _title_shader_no_sdf:unbind()
            love.graphics.pop()

            self._bloom:unbind()
            bloom_updated = true
        end
    end

    if self._state == mn.MenuSceneState.FALLING or self._state == mn.MenuSceneState.STAGE_SELECT or self._state == mn.MenuSceneState.EXITING then
        local stage_select = self._stage_select

        stage_select.debris_emitter:draw()

        love.graphics.push()
        local offset_x = stage_select.item_reveal_animation:get_value()
        love.graphics.translate(offset_x * stage_select.reveal_width, 0)

        stage_select.item_frame:draw()
        stage_select.page_indicator:draw()
        self._stage_select.control_indicator:draw()

        love.graphics.pop()

        if not bloom_updated and rt.GameState:get_is_bloom_enabled() then
            self._bloom:bind()
            love.graphics.clear()

            local stencil_value = rt.graphics.get_stencil_value()
            rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
            stage_select.page_indicator:draw()
            stage_select.item_frame:draw_mask()

            rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

            stage_select.debris_emitter:draw()

            rt.graphics.set_stencil_mode(nil)

            love.graphics.push()
            love.graphics.translate(offset_x * stage_select.reveal_width, 0)
            stage_select.item_frame:draw_bloom()
            stage_select.page_indicator:draw_bloom()
            love.graphics.pop()

            self._camera:bind()
            self._player:draw_bloom()
            self._camera:unbind()

            self._bloom:unbind()
        end
    end

    self._camera:bind()
    self._player:draw()
    self._camera:unbind()

    self._stage_select.debris_emitter:draw_above()

    if rt.GameState:get_is_bloom_enabled() then
        self._bloom:composite()
    end

    self._fade:draw()
end

--- @brief
function mn.MenuScene:get_camera()
    return self._camera
end