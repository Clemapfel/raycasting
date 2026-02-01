require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.control_indicator"
require "common.timed_animation"
require "common.fade"
require "menu.stage_select_page_indicator"
require "menu.stage_select_item_frame"
require "menu.stage_select_debris_emitter"
require "menu.stage_select_clouds"
require "menu.coin_particle_swarm"
require "menu.menu_scene_background"
require "overworld.coin_particle"

rt.settings.menu_scene = {
    player_max_falling_velocity = 1000,
    player_falling_x_damping = 0.98,
    player_falling_x_perturbation = 3,
    exit_acceleration = 60, -- per second
    bloom_strength = 1,
    bloom_composite = 0.1,

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

local _title_shader_no_sdf = rt.Shader("menu/menu_scene_label.glsl", { MODE = 0 })
local _title_shader_sdf = rt.Shader("menu/menu_scene_label.glsl", { MODE = 1 })

-- @brief
function mn.MenuScene:instantiate(state)
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
    self._background = mn.MenuSceneBackground(self)

    self._active_sounds = {}

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
            rt.ControlIndicatorButton.CONFIRM, translation.control_indicator_select,
            rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move
        )
        title_screen.control_indicator:set_has_frame(false)

        title_screen.menu_items = {}
        title_screen.n_menu_items = 0
        title_screen.selected_item_i = 1
        title_screen.skip_selected_item_i = 2

        local item_to_item_i = {
            stage_select = 1,
            new_speedrun = 2,
            settings = 3,
            controls = 4,
            quit = 5
        }


        local item_i_to_translation = {
            [item_to_item_i.stage_select] = translation.stage_select,
            [item_to_item_i.new_speedrun] = translation.new_speedrun,
            [item_to_item_i.settings] = translation.settings,
            [item_to_item_i.controls] = translation.controls,
            [item_to_item_i.quit] = translation.quit
        }

        for item_i = 1, table.sizeof(item_to_item_i) do
            local text = item_i_to_translation[item_i]

            local item = {
                unselected_label = rt.Label("<o>" .. text .. "</o>", rt.FontSize.LARGE, title_screen.menu_font),
                selected_label = rt.Label("<o><rainbow><b><color=SELECTION>" .. text .. "</color></b></o></rainbow>", rt.FontSize.LARGE, title_screen.menu_font),
            }

            title_screen.menu_items[item_i] = item
            title_screen.n_menu_items =  title_screen.n_menu_items + 1
        end

        -- menu item: stage select
        local stage_select_item = title_screen.menu_items[item_to_item_i.stage_select]
        stage_select_item.activate = function()
            self:_set_state(mn.MenuSceneState.FALLING)
        end

        -- menu item: new speedrun
        local new_speedrun_item = title_screen.menu_items[item_to_item_i.new_speedrun]
        new_speedrun_item.activate = function()
            rt.critical("In menu_scene: item `", item_i_to_translation[item_to_item_i.new_speedrun], "` is not yet implemented")
        end

        -- menu item: settings
        local settings_item = title_screen.menu_items[item_to_item_i.settings]
        settings_item.activate = function()
            require "menu.settings_scene"
            rt.SceneManager:push(mn.SettingsScene)
        end

        -- menu item: controls
        local controls_item = title_screen.menu_items[item_to_item_i.controls]
        controls_item.activate = function()
            require "menu.keybinding_scene"
            rt.SceneManager:push(mn.KeybindingScene)
        end

        -- menu item: quit
        local quit_item = title_screen.menu_items[item_to_item_i.quit]
        quit_item.activate = function()
            love.event.push("close")
        end

        title_screen.input = rt.InputSubscriber()
        title_screen.input:signal_connect("pressed", function(_, which)
            if self._initialized == false or self._input_blocked == true then return end

            local offset = nil

            if which == rt.InputAction.CONFIRM then
                local item = title_screen.menu_items[title_screen.selected_item_i]
                item.activate()
                rt.SoundManager:play(rt.SoundIDs.menu_scene.title_screen.confirm)
            elseif which == rt.InputAction.UP then
                if title_screen.selected_item_i > 1 then
                    offset = -1
                end
            elseif which == rt.InputAction.DOWN then
                if title_screen.selected_item_i < title_screen.n_menu_items then
                    offset = 1
                end
            end

            if offset ~= nil then
                rt.SoundManager:play(rt.SoundIDs.menu_scene.title_screen.selection)
                title_screen.selected_item_i = title_screen.selected_item_i + offset
                while title_screen.selected_item_i == title_screen.skip_selected_item_i
                    and title_screen.selected_item_i >= 1
                    and title_screen.selected_item_i <= title_screen.n_menu_items
                do
                    title_screen.selected_item_i = title_screen.selected_item_i + offset
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

            if which == rt.InputAction.CONFIRM then
                self:_set_state(mn.MenuSceneState.EXITING)
                stage_select.waiting_for_exit = true
            elseif which == rt.InputAction.BACK then
                self._fade:start()
                self._fade:signal_connect("hidden", function()
                    stage_select.debris_emitter:reset()
                    stage_select.debris_emitter_initialized = false
                    stage_select.coin_particle_swarm:reset()
                    self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
                    self._shader_fraction = 0
                    self._background:set_fraction(0)
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

        stage_select.item_frame = mn.StageSelectItemframe()
        stage_select.page_indicator = mn.StageSelectPageIndicator()
        stage_select.debris_emitter = mn.StageSelectDebrisEmitter()
        stage_select.clouds = mn.StageSelectClouds()
        stage_select.coin_particle_swarm = mn.CoinParticleSwarm()
        stage_select.coin_particle_swarm:set_target(self._camera:world_xy_to_screen_xy(self._player:get_position()))
        stage_select.coin_particle_swarm:reset()

        stage_select.exit_fade = rt.Fade(3, "overworld/overworld_scene_fade.glsl")
        stage_select.debris_emitter_initialized = false

        local translation = rt.Translation.menu_scene.stage_select
        stage_select.control_indicator = rt.ControlIndicator(
            rt.ControlIndicatorButton.CONFIRM, translation.control_indicator_confirm,
            rt.ControlIndicatorButton.BACK, translation.control_indicator_back,
            rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_select
        )

        stage_select.debris_emitter:signal_connect("collision", function(_, x, y)
            local id = rt.SoundIDs.menu_scene.stage_select.debris_collision
            rt.SoundManager:play(id, {
                position_x = x,
                position_y = y
            })
        end)
    end
end

--- @brief
function mn.MenuScene:realize()
    self._background:realize()

    self._title_screen.control_indicator:realize()
    for item in values(self._title_screen.menu_items) do
        item.unselected_label:realize()
        item.selected_label:realize()
    end

    local stage_select = self._stage_select
    for widget in range(
        stage_select.page_indicator,
        stage_select.item_frame,
        stage_select.debris_emitter,
        stage_select.clouds,
        stage_select.control_indicator
    ) do
        widget:realize()
    end

    self._stage_select.control_indicator:set_has_frame(false)
    self:_create_from_state()
end

function mn.MenuScene:_create_from_state()
    local stage_select = self._stage_select
    stage_select.item_frame:create_from_state()
    stage_select.page_indicator:create_from_state()
end

--- @brief
function mn.MenuScene:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 3 * m

    self._background:reformat(x, y, width, height)

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
                b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
                    b2.Segment(cx - r, cw - r, cx + w + r, cw - r)
                ),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
                    b2.Segment(cx + w + r, cw - r, cx + w + r, cw + h + r)
                ),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
                    b2.Segment(cx + w + r, cw + h + r, cx - r, cw + h + r)
                ),

                b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
                    b2.Segment(cx - r, cw + h + r, cx - r, cw - r)
                )
            }

            -- reflect player along normal
            for body in values(title_screen.boundaries) do
                body:set_collides_with(rt.settings.player.bounce_collision_group)
                body:set_collision_group(rt.settings.player.bounce_collision_group)
                body:set_use_continuous_collision(true)
                body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
                    local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
                    self._player_velocity_x, self._player_velocity_y = math.reflect(current_vx, current_vy, normal_x, normal_y)
                    rt.SoundManager:play(rt.SoundIDs.menu_scene.title_screen.player_reflected)
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
            0.5 * width - control_w - m, 0.5 * height - control_h - m,
            control_w, control_h
        )
    end

    do -- stage select
        local stage_select = self._stage_select
        local bounds = self:get_bounds()

        stage_select.debris_emitter:reformat(bounds)
        stage_select.clouds:reformat(bounds)

        -- control indicator
        local control_w, control_h = stage_select.control_indicator:measure()
        stage_select.control_indicator:reformat(
            x,
            y + height - control_h,
            control_w, control_h
        )

        local menu_y = math.round(outer_margin + control_h) -- for symmetry
        local menu_h = height - 2 * outer_margin - 2 * control_h

        -- page indicator
        local current_x = x + width - outer_margin
        local page_indicator_w = 30 * rt.get_pixel_scale()
        local page_indicator_m = math.max(3 * outer_margin, outer_margin + control_h + m)
        local page_indicator_h = height
        stage_select.page_indicator:reformat(
            current_x - page_indicator_w,
            y,
            page_indicator_w,
            height
        )

        current_x = current_x - page_indicator_w - outer_margin

        local fraction = rt.settings.menu_scene.stage_select.player_alignment

        -- level tiles
        local menu_right_margin = 2 * outer_margin + page_indicator_w
        local menu_w = (1 - fraction) * width
        local item_frame_x = x + width - menu_w

        local item_frame_page_w, item_frame_page_h = stage_select.item_frame:measure()
        if item_frame_x + 0.5 * menu_w + 0.5 * item_frame_page_w > x + width - menu_right_margin then
            -- aligning with fraction would overlap page indicator, push as far right as possible
            item_frame_x = x + width - menu_right_margin - menu_w
            local space_left = width - menu_right_margin - item_frame_page_w

            stage_select.item_frame:set_justify_mode(rt.JustifyMode.RIGHT)
            stage_select.player_alignment = 0.5 * width
                - space_left / 2
        else
            -- else keep at thirds
            stage_select.item_frame:set_justify_mode(rt.JustifyMode.CENTER)
            stage_select.player_alignment = 0.5 * width
                - width * fraction / 2
                - self._player:get_radius() * 2 -- why is this necessary?
        end

        stage_select.item_frame:reformat(
            item_frame_x,
            y + control_h,
            menu_w,
            self._bounds.height - 2 * control_h
        )
        stage_select.reveal_width = menu_w + page_indicator_w + 4 * outer_margin
    end
end

--- @brief
function mn.MenuScene:enter(skip_title)
    if skip_title == nil then skip_title = false end
    meta.assert(skip_title, "Boolean")

    if self._player:get_world() ~= self._world then
        self._player:move_to_world(self._world)
    end

    rt.SceneManager:set_use_fixed_timestep(true)

    if rt.SceneManager:get_is_bloom_enabled() then
        rt.SceneManager:get_bloom():set_bloom_strength(rt.settings.menu_scene.bloom_strength)
    end

    if skip_title then
        self:_set_state(mn.MenuSceneState.STAGE_SELECT)
        self._shader_fraction = 1
        self._player:teleport_to(0, 2000) -- skip falling
        self._stage_select.item_reveal_animation:skip()
        self:update(0)
    else
        self:_set_state(mn.MenuSceneState.TITLE_SCREEN)
    end
end

--- @brief
function mn.MenuScene:exit()
    self._player:enable()
    self._camera:set_is_shaking(false)
    self._title_screen.input:deactivate()
    self._stage_select.input:deactivate()

    for sound_id, handler_id in pairs(self._active_sounds) do
        rt.SoundManager:stop(sound_id, handler_id)
    end
end

--- @brief
function mn.MenuScene:_set_state(next)
    assert(next ~= nil)

    local current = self._state
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

    do -- sound effects
        local neon_buzz_id = rt.SoundIDs.menu_scene.title_screen.neon_buzz
        if self._active_sounds[neon_buzz_id] == nil then -- always play, position handles muting
            self._active_sounds[neon_buzz_id] = rt.SoundManager:play(neon_buzz_id, {
                position_x = 0,
                position_y = 0,
                should_loop = true
            })
        end

        local wind_rush_id = rt.SoundIDs.menu_scene.stage_select.wind_rush
        if self._active_sounds[wind_rush_id] == nil then
            self._active_sounds[wind_rush_id] = rt.SoundManager:play(wind_rush_id, {
                should_loop = true
            })
        end

        if next == mn.MenuSceneState.TITLE_SCREEN then
            rt.SoundManager:set_volume(wind_rush_id, self._active_sounds[wind_rush_id], 0)
        else
            rt.SoundManager:set_volume(wind_rush_id, self._active_sounds[wind_rush_id], 1)
        end

        local debris_continuous_id = rt.SoundIDs.menu_scene.stage_select.debris_continuous
        if self._active_sounds[debris_continuous_id] == nil then
            self._active_sounds[debris_continuous_id] = rt.SoundManager:play(debris_continuous_id, {
                should_loop = true
            })
        end

        if next == mn.MenuSceneState.TITLE_SCREEN then
            rt.SoundManager:set_volume(debris_continuous_id, self._active_sounds[debris_continuous_id], 0)
        else
            rt.SoundManager:set_volume(debris_continuous_id, self._active_sounds[debris_continuous_id], 1)
        end
    end

    if next == mn.MenuSceneState.TITLE_SCREEN then
        self._title_screen.input:activate()
        self._player:set_flow(0)

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

        self._player:reset()
        self._player:set_is_bubble(true)
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

    rt.SoundManager:set_player_position(self._camera:get_position())

    if self._input_blocked then self._input_blocked = false end
    -- keep input subscribers from firing on the same frame they are activated

    self._fade:update(delta)
    if not self._initialized then return end

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
    else -- stage select
        -- falling or level select
        local px, py = self._player:get_position()
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
        local shake_t = vy / max_velocity * speedup
        self._camera:set_shake_frequency(shake_t)
        self._camera:set_shake_intensity_in_pixels(math.min(1, shake_t) * 1)
        self._stage_select.coin_particle_swarm:set_speedup(speedup)

        -- transition player to left side of screen
        local offset_fraction = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(self._shader_fraction)
        local stage_select = self._stage_select

        local w = love.graphics.getWidth()
        local x_offset = offset_fraction * stage_select.player_alignment

        if self._state == mn.MenuSceneState.EXITING then
            self._camera:move_to(self._exit_x, self._exit_y)
        else
            self._camera:move_to(px + x_offset, py)
        end

        stage_select.n_items = rt.GameState:get_n_stages()

        stage_select.clouds:set_opacity(self._player:get_flow())
        stage_select.clouds:update(delta)

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

        local hue = stage_select.item_frame:get_hue()
        stage_select.page_indicator:set_hue(hue)
        stage_select.clouds:set_hue(hue)
        stage_select.debris_emitter:set_speedup(speedup)
        stage_select.clouds:set_speedup(speedup)
        self._background:set_speedup(speedup)

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
                    stage_select.exit_fade:start(true, false)
                    stage_select.exit_fade:signal_connect("hidden", function()
                        require "overworld.overworld_scene"
                        rt.SceneManager:push(ow.OverworldScene, rt.GameState:list_stage_ids()[stage_select.selected_item_i], true) -- with titlecard
                    end)
                    stage_select.waiting_for_exit = false
                end
            end

            stage_select.exit_fade:update(delta)
        end
    end

    self._background:set_fraction(self._shader_fraction)

    do -- swarm
        local swarm = self._stage_select.coin_particle_swarm
        local screen_px, screen_py = self._camera:world_xy_to_screen_xy(self._player:get_position())
        screen_py = screen_py - 4 * self._player:get_radius()

        if self._state == mn.MenuSceneState.EXITING then
            -- on exit: move towards bottom of the screen
            swarm:set_target(screen_px, 2 * self._bounds.height)
            swarm:set_mode(mn.CoinParticleSwarmMode.DISPERSE)
        elseif self._state == mn.MenuSceneState.FALLING then
            -- transition: enter from the top towards circle position
            swarm:set_target(
                screen_px - 0.5 * self._stage_select.player_alignment,
                screen_py
            )
            swarm:set_mode(mn.CoinParticleSwarmMode.FOLLOW)
        elseif self._state == mn.MenuSceneState.STAGE_SELECT then
            -- stage select: circle
            swarm:set_target(screen_px, screen_py)
            swarm:set_mode(mn.CoinParticleSwarmMode.CIRCLE)
        end
    end

    if self._state ~= mn.MenuSceneState.TITLE_SCREEN then
        self._stage_select.coin_particle_swarm:update(delta)
    end

    self._player:update(delta)
    self._world:update(delta)
    self._camera:update(delta)
    self._background:update(delta)
end

local _black = { rt.Palette.BLACK:unpack() }

--- @brief
function mn.MenuScene:draw()
    if not self._initialized then
        self._fade:draw()
        return
    end

    self._background:draw()

    local title_screen = self._title_screen
    local stage_select = self._stage_select

    if self._state == mn.MenuSceneState.TITLE_SCREEN
        or self._state == mn.MenuSceneState.FALLING
    then
        -- title text
        love.graphics.push("all")

        self._camera:bind()

        -- menu
        for i, item in ipairs(title_screen.menu_items) do
            if i == title_screen.selected_item_i then
                item.selected_label:draw()
            else
                item.unselected_label:draw()
            end
        end

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

        self._player:draw()
        self._camera:unbind()

        if rt.GameState:get_is_bloom_enabled() then
            local bloom = rt.SceneManager:get_bloom()
            bloom:bind()
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

            bloom:unbind()
            bloom:composite()
        end

        self._camera:bind()
        title_screen.control_indicator:draw()
        self._camera:unbind()

        love.graphics.pop()
    end

    if self._state == mn.MenuSceneState.STAGE_SELECT
        or self._state == mn.MenuSceneState.EXITING
        or self._state == mn.MenuSceneState.FALLING
    then
        stage_select.debris_emitter:draw_below_player()

        local camera_bounds = self._camera:get_world_bounds()
        stage_select.coin_particle_swarm:set_offset(camera_bounds.x, camera_bounds.y)

        self._camera:bind()
        stage_select.coin_particle_swarm:draw_below_player()
        self._player:draw()
        stage_select.coin_particle_swarm:draw_above_player()
        self._camera:unbind()

        stage_select.debris_emitter:draw_above_player()

        if rt.GameState:get_is_bloom_enabled() then
            local bloom = rt.SceneManager:get_bloom()
            bloom:bind()
            love.graphics.clear(0, 0, 0, 0)

            self._camera:bind()
            self._player:draw_bloom()
            self._camera:unbind()

            bloom:unbind()
            bloom:composite()
        end

        local offset_x = stage_select.item_reveal_animation:get_value()
        love.graphics.push()
        love.graphics.translate(offset_x * stage_select.reveal_width, 0)
        stage_select.item_frame:draw()
        stage_select.page_indicator:draw()
        love.graphics.pop()

        stage_select.clouds:draw()

        love.graphics.push()
        love.graphics.translate(2 * offset_x * stage_select.reveal_width, 0)
        stage_select.control_indicator:draw()
        love.graphics.pop()
    end

    self._stage_select.exit_fade:draw()
    self._fade:draw()
end

--- @brief
function mn.MenuScene:get_camera()
    return self._camera
end

--- @brief
function mn.MenuScene:get_player()
    return self._player
end