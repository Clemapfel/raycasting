require "common.scene"
require "common.mesh"
require "overworld.background"
require "common.control_indicator"
require "overworld.stage"
require "common.camera"
require "common.player"
require "physics.physics"
require "menu.pause_menu"
require "common.bloom"
require "common.fade"
require "overworld.stage_title_card"
require "common.impulse_manager"
require "overworld.reveal_particle_effect"
require "common.blur"

do
    local bloom = 0.2
    rt.settings.overworld_scene = {
        bloom_blur_strength = 1.5, -- > 0
        bloom_composite_strength = bloom, -- [0, 1]
        title_card_min_duration = 3, -- seconds

        idle_threshold_duration = 5,
        control_indicator_delay = 0.0,

        player_canvas_scale = rt.settings.player_body.texture_scale,
        player_canvas_size_radius_factor = rt.settings.player.bubble_radius_factor * 2.5,

        screenshot_texture_format = rt.RGBA8,

        max_blur_strength = 10, -- gaussian sigma
        max_blur_darkening = 0.82, -- fraction,

        position_override_keys = {
            [rt.KeyboardKey.LEFT_CONTROL] = true,
            [rt.KeyboardKey.RIGHT_CONTROL] = true
        },

        border_scroll_width = 1 / 3, -- fraction
        border_scroll_velocity = 400, -- px / s
        border_scroll_opacity = 0.25,
        scale_override_velocity = 0.25, -- % per mousewheel dy
        scale_override_min = 1 / 8,
        scale_override_max = 8
    }
end

--- @class ow.OverworldScene
ow.OverworldScene = meta.class("OverworldScene", rt.Scene)

ow.CameraMode = meta.enum("CameraMode", {
    FREEZE = "FREEZE",       -- all movement disabled
    CUTSCENE = "CUTSCENE",   -- fully controlled externally
    STATIC = "STATIC",       -- hold position, but not frozen
    BOUNDED = "BOUNDED",     -- follow player, stay in camera bounds
    UNBOUNDED = "UNBOUNDED", -- follow player, camera bounds ignored
})

local _bloom_shader = nil

--- @enum ow.ControlIndicatorType
ow.ControlIndicatorType = {
    MOTION_NON_BUBBLE = "MOTION_NON_BUBBLE",
    MOTION_BUBBLE = "MOTION_BUBBLE",
    INTERACT = "INTERACT",
    SLIDE = "SLIDE",
    HOLD_DOWN_TO_ACCELERATE = "HOLD_DOWN_TO_ACCELERATE",
    DIALOG_ADVANCE = "DIALOG_ADVANCE",
    DIALOG_SKIP = "DIALOG_SKIP",
    DIALOG_EXIT = "DIALOG_EXIT",
    DIALOG_SELECT_OPTION = "DIALOG_SELECT_OPTION",
    AIR_DASH = "AIR_DASH",
    DOUBLE_JUMP = "DOUBLE_JUMP",
    NONE = "NONE"
}
ow.ControlIndicatorType = meta.enum("ControlIndicatorType", ow.ControlIndicatorType)

--- @brief
function ow.OverworldScene:instantiate(state)
    ow.Stage._config_atlas = {}
    ow.StageConfig._tileset_atlas = {}
    rt.Sprite._path_to_spritesheet = {}

    meta.install(self, {
        _state = state,
        _camera = rt.Camera(),
        _current_stage_id = nil,
        _stage = nil,
        _player = state:get_player(),
        _input = rt.InputSubscriber(-math.huge),
        _background = nil, -- ow.Background

        _cursor_active = false,

        _pause_menu = mn.PauseMenu(self),
        _pause_menu_active = false,

        _fade = rt.Fade(2, "overworld/overworld_scene_fade.glsl"),
        _fade_active = false,

        _show_title_card = true,
        _title_card = ow.StageTitleCard("UNINITIALIZED"),
        _title_card_active = false,
        _title_card_elapsed = 0,

        _player_is_visible = true,

        _player_canvas = nil,
        _player_canvas_needs_update = true,

        _timer_started = false,
        _timer_paused = false,
        _timer_stopped = false,
        _timer = 0,

        _fade_to_black = 0,
        _blur_motion = rt.SmoothedMotion1D(0),
        _blur = nil, -- rt.Blur
        _screenshot = nil,

        _camera_modes = {},

        -- manual camera
        _camera_scale_override_active = false,
        _camera_scale_override = 1,

        _camera_override_active = false,
        _camera_position_override_x = 0,
        _camera_position_override_y = 0,
        _camera_velocity_x = 0,
        _camera_velocity_y = 0,

        _camera_top_border_t = 0,
        _camera_right_border_t = 0,
        _camera_bottom_border_t = 0,
        _camera_left_border_t = 0,

        _camera_top_border = nil, -- rt.Mesh
        _camera_right_border = nil,
        _camera_bottom_border = nil,
        _camera_left_border = nil
    })

    for mode in values(meta.instances(ow.CameraMode)) do
        self._camera_modes[mode] = 0
    end

    self._background = ow.Background(self)

    local translation = rt.Translation.overworld_scene

    local function create_non_bubble_indicator()
        local indicator
        if rt.settings.player.sprint_allowed then
            indicator = rt.ControlIndicator(
                rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_move,
                rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump,
                rt.ControlIndicatorButton.SPRINT, translation.control_indicator_sprint,
                rt.ControlIndicatorButton.DOWN, translation.control_indicator_down
            )
        else
            indicator = rt.ControlIndicator(
                rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_move,
                rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump,
                rt.ControlIndicatorButton.DOWN, translation.control_indicator_down
            )
        end
        indicator:set_has_frame(true)
        return indicator
    end

    local function create_indicator(...)
        local indicator = rt.ControlIndicator(...)
        indicator:set_has_frame(true)
        return indicator
    end

    local dialog_button = rt.settings.overworld.dialog_box.advance_button

    self._control_indicator_type_to_control_indicator = {
        [ow.ControlIndicatorType.MOTION_NON_BUBBLE] = create_non_bubble_indicator(),

        [ow.ControlIndicatorType.MOTION_BUBBLE] = create_indicator(
            rt.ControlIndicatorButton.ALL_DIRECTIONS, translation.control_indicator_bubble_move
        ),

        [ow.ControlIndicatorType.INTERACT] = create_indicator(
            rt.ControlIndicatorButton.INTERACT, translation.control_indicator_interact
        ),

        [ow.ControlIndicatorType.AIR_DASH] = create_indicator(
            rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump,
            rt.ControlIndicatorButton.JUMP, translation.control_indicator_air_dash
        ),

        [ow.ControlIndicatorType.DOUBLE_JUMP] = create_indicator(
            rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump,
            rt.ControlIndicatorButton.JUMP, translation.control_indicator_double_jump
        ),

        [ow.ControlIndicatorType.SLIDE] = create_indicator(
            rt.ControlIndicatorButton.DOWN, translation.control_indicator_slide
        ),

        [ow.ControlIndicatorType.HOLD_DOWN_TO_ACCELERATE] = create_indicator(
            rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_move,
            rt.ControlIndicatorButton.DOWN, translation.control_indicator_hold_down
        ),

        [ow.ControlIndicatorType.NONE] = nil,
        [ow.ControlIndicatorType.DIALOG_SKIP] = create_indicator(
            dialog_button, translation.control_indicator_dialog_skip
        ),

        [ow.ControlIndicatorType.DIALOG_ADVANCE] = create_indicator(
            dialog_button, translation.control_indicator_dialog_advance
        ),

        [ow.ControlIndicatorType.DIALOG_EXIT] = create_indicator(
            dialog_button, translation.control_indicator_dialog_exit
        ),

        [ow.ControlIndicatorType.DIALOG_SELECT_OPTION] = create_indicator(
            rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_dialog_select_option,
            dialog_button, translation.control_indicator_dialog_confirm_option
        )
    }

    for which in range(
        ow.ControlIndicatorType.DIALOG_SKIP,
        ow.ControlIndicatorType.DIALOG_ADVANCE,
        ow.ControlIndicatorType.DIALOG_EXIT,
        ow.ControlIndicatorType.DIALOG_SELECT_OPTION
    ) do
        self._control_indicator_type_to_control_indicator[which]:set_has_frame(false)
    end

    self._control_indicator_opacity_motion = rt.SmoothedMotion1D(0, 1) -- opacity
    self._control_indicator_offset_motion = rt.SmoothedMotion2D(
        0, 0,
        1.5 -- speed factor
    )
    self._control_indicator_max_offset = 0
    self._control_indicator_allow_override = true

    self._control_indicator_type = ow.ControlIndicatorType.NONE
    self._control_indicator_delay_elapsed = math.huge
    self._control_indicator_particle_effect = ow.RevealParticleEffect()

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.PAUSE then
            if not self._pause_menu_active then
                self:pause()
            elseif self._pause_menu_active then
                self:unpause()
            end
        end
    end)

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        -- debug reload
        if which == rt.KeyboardKey.CIRCUMFLEX then
            for reload in range(
                "common.player"
            ) do
                package.loaded[reload] = nil
                require(reload)
            end

            self._input:deactivate()
            self:unpause()
            self:reset()
            self._input:activate()
        elseif which == rt.KeyboardKey.ONE then
            rt.GameState:save()
        end
    end)

    local settings = rt.settings.overworld_scene

    self._input:signal_connect("mouse_wheel_moved", function(_, x, y)
        if self._camera_override_active then
            self._camera_scale_override = self._camera_scale_override + y * settings.scale_override_velocity
            -- clamped in _update_camera
        end
    end)

    self._input:signal_connect("left_trigger_moved", function(_, v, dv)
        if math.abs(dv) == 1 then return end -- controller does not have analog triggers
        self._camera_scale_override = self._camera_scale_override + dv
    end)

    self._input:signal_connect("right_trigger_moved", function(_, v, dv)
        if math.abs(dv) == 1 then return end
        self._camera_scale_override = self._camera_scale_override - dv
    end)

    for widget in range(
        self._background,
        self._pause_menu,
        self._title_card
    ) do
        widget:realize()
    end

    for indicator in values(self._control_indicator_type_to_control_indicator) do
        indicator:realize()
    end

    local settings = rt.settings.overworld_scene
    self._player_canvas_scale = settings.player_canvas_scale
    local radius = rt.settings.player.radius * settings.player_canvas_size_radius_factor
    local texture_w, texture_h = 2 * radius * self._player_canvas_scale, 2 * radius * self._player_canvas_scale
    self._player_canvas = rt.RenderTexture(texture_w, texture_h)
end

--- @brief
function ow.OverworldScene:enter(new_stage_id, show_title_card)
    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(true)

    self._fade_active = false
    self._fade:skip()

    self._show_title_card = show_title_card

    if new_stage_id ~= nil then
        self:set_stage(new_stage_id, show_title_card)
    end

    -- do not reset player or pause state
end

--- @brief
function ow.OverworldScene:set_stage(stage_id, show_title_card)
    meta.assert(stage_id, "String")
    self._input:activate()

    if not rt.GameState:get_stage_exists(stage_id) then
        rt.error("In ow.OverwoldScene: no stage with id `", stage_id, "`: does `assets/stages/", stage_id, ".lua` and an entry in `rt.Translation.stages` exist?")
    end

    if show_title_card == nil then show_title_card = true end
    self._show_title_card = show_title_card
    self._title_card:set_title(rt.GameState:get_stage_name(stage_id))

    rt.SceneManager:set_use_fixed_timestep(true)

    if self._stage_id ~= stage_id then
        self._stage_id = stage_id
        self._stage = ow.Stage(self, stage_id)
    else
        self._stage:reset()
    end

    self._stage:set_active_checkpoint(nil)
    self._player:move_to_stage(self._stage)

    self._player_is_focused = true
    self._n_frames = 0

    self._timer_started = false
    self._timer_stopped = false
    self._timer_paused = true
    self._timer = 0

    if self._show_title_card then
        self._fade_active = false
        self._fade:start(false, true)

        self._player:request_is_movement_disabled(self, true)
        self._fade:signal_connect("hidden", function(_)
            self._player:request_is_movement_disabled(self, nil)
            self:start_timer()
            return meta.DISCONNECT_SIGNAL
        end)

        self._title_card:fade_in()
        self._title_card_elapsed = 0

        self._stage:signal_connect("loading_done", function()
            self._queue_fade_out = true
            return meta.DISCONNECT_SIGNAL
        end)
    else
        self._fade_active = false
        self._title_card_elapsed = math.huge
        self:start_timer()
    end

    if rt.GameState:get_is_bloom_enabled() then
        local bloom = rt.SceneManager:get_bloom()
        bloom:set_bloom_strength(rt.settings.overworld_scene.bloom_blur_strength)

        self._stage:get_blood_splatter():set_bloom_factor(
            rt.settings.overworld_scene.bloom_composite_strength
        )
    else
        self._stage:get_blood_splatter():set_bloom_factor(1)
    end

    if self._pause_menu_active then
        self._pause_menu:present()
    end
end

--- @brief
function ow.OverworldScene:exit()
    self._input:deactivate()
    rt.SceneManager:set_is_cursor_visible(false)
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)
    if self._blur == nil
        or self._blur:get_width() ~= width
        or self._blur:get_height() ~= height
    then
        self._blur = rt.Blur(width, height)
    end

    local m = rt.settings.margin_unit
    do
        local max_h = -math.huge
        for indicator in values(self._control_indicator_type_to_control_indicator) do
            local control_w, control_h = indicator:measure()
            local down_m = ternary(indicator:get_has_frame(), m, 0.5 * m)
            indicator:reformat(
                x + 0.5 * width - 0.5 * control_w - m,
                y + height - control_h - down_m,
                control_w, control_h
            )
            max_h = math.max(max_h, control_h)
        end
        self._control_indicator_max_offset = 2 * max_h
        self._control_indicator_offset_motion:set_position(
            0, self._control_indicator_max_offset
        )
    end

    for widget in range(
        self._background,
        self._pause_menu,
        self._title_card
    ) do
        widget:reformat(0, 0, width, height)
    end

    local border_factor = rt.settings.overworld_scene.border_scroll_width
    local thickness = math.min(width * border_factor, height * border_factor)

    do
        local make_transparent = function(mesh, ...)
            local transparent = {}
            for i = 1, select("#", ...) do
                transparent[select(i, ...)] = true
            end

            for i = 1, 4 do
                if transparent[i] == true then
                    mesh:set_vertex_color(i, 0, 0, 0, 0)
                else
                    mesh:set_vertex_color(i, 1, 1, 1, 1)
                end
            end
        end

        self._camera_top_border = rt.MeshRectangle(0, 0, width, thickness)
        make_transparent(self._camera_top_border, 3, 4)

        self._camera_bottom_border = rt.MeshRectangle(0, height - thickness, width, thickness)
        make_transparent(self._camera_bottom_border, 1, 2)

        self._camera_right_border = rt.MeshRectangle(width - thickness, 0, thickness, height)
        make_transparent(self._camera_right_border, 1, 4)

        self._camera_left_border = rt.MeshRectangle(0, 0, thickness, height)
        make_transparent(self._camera_left_border, 2, 3)
    end
end

--- @brief
function ow.OverworldScene:get_timer()
    return self._timer
end

--- @brief
function ow.OverworldScene:get_frame_count()
    return self._n_frames
end

--- @brief
function ow.OverworldScene:start_timer()
    self._timer_started = true
    self._timer_stopped = false
    self._timer_paused = false
    self._timer = 0
    self._n_frames = 0
end

--- @brief
function ow.OverworldScene:pause_timer()
    self._timer_paused = true
end

--- @brief
function ow.OverworldScene:unpause_timer()
    self._timer_paused = false
end

--- @brief
function ow.OverworldScene:stop_timer()
    self._timer_stopped = true
end

function ow.OverworldScene:draw()
    if self._stage == nil then return end

    local bloom_enabled, bloom = rt.GameState:get_is_bloom_enabled() == true
    if bloom_enabled then
        bloom = rt.SceneManager:get_bloom()
        love.graphics.push()
        bloom:bind()
        love.graphics.clear(0, 0, 0, 0)
        self._camera:bind()
        if self._player_is_visible then
            self._player:draw_bloom()
        end
        self._stage:draw_bloom()
        self._camera:unbind()
        bloom:unbind()
        love.graphics.pop()
    end

    local function draw_bloom()
        bloom:composite(rt.settings.overworld_scene.bloom_composite_strength)
    end

    love.graphics.push("all")

    local blur_eps = 0.02
    local blur_value = self._blur_motion:get_value()

    love.graphics.origin()
    if blur_value <= blur_eps and not (self._show_title_card == true and (self._fade:get_is_active() or self._fade:get_is_visible())) then
        self._background:draw()

        if self._fade_to_black > 0 then
            local r, g, b, _ = rt.Palette.BLACK:unpack()
            love.graphics.setColor(r, g, b, self._fade_to_black)
            love.graphics.rectangle("fill", self._bounds:unpack())
        end

        self._camera:bind()
        self._stage:draw_below_player()

        if self._player_is_visible then
            self._player:draw_body()
            self._player:draw_core()
        end
        self._stage:draw_above_player()
        self._camera:unbind()

        self._camera:bind()
        self._stage:draw_above_bloom()
        self._camera:unbind()

    elseif blur_value > blur_eps then -- respawning
        if self._blur ~= nil then
            self._blur:set_blur_strength(blur_value * rt.settings.overworld_scene.max_blur_strength)
            self._blur:bind()
            love.graphics.clear(0, 0, 0, 0)

            self._background:draw()
            self._camera:bind()
            self._stage:draw_below_player()
            self._stage:draw_above_player()
            self._camera:unbind()

            self._stage:draw_above_bloom()

            self._blur:unbind()

            local t = 1 - math.mix(0, rt.settings.overworld_scene.max_blur_darkening, self._blur_motion:get_value())
            love.graphics.setColor(t, t, t, t)
            self._blur:draw()

            if self._player_is_visible then
                self._camera:bind()
                self._player:draw_body()
                self._player:draw_core()
                self._camera:unbind()
            end
        end
    else -- fading
        self._background:draw()
        self._camera:bind()
        self._stage:draw_below_player()
        self._stage:draw_above_player()
        self._camera:unbind()

        self._fade:draw()

        if self._player_is_visible then
            self._camera:bind()
            self._player:draw_body()
            self._player:draw_core()

            -- TODO
            self._camera:unbind()
        end

        self._title_card:draw()
    end

    love.graphics.pop()

    if self._pause_menu_active then
        self._pause_menu:draw()
    end

    self._control_indicator_particle_effect:draw()

    local opacity = self._control_indicator_opacity_motion:get_value()
    if opacity > 0 and self._pause_menu_active == false then
        local indicator = self._control_indicator_type_to_control_indicator[self._control_indicator_type]
        if indicator ~= nil then
            indicator:set_opacity(opacity)
            love.graphics.push()
            love.graphics.translate(self._control_indicator_offset_motion:get_position())
            indicator:draw()
            love.graphics.pop()
        end
    end

    if self._camera_override_active then
        love.graphics.push("all")
        love.graphics.setBlendMode("add", "premultiplied")

        local draw = function(v, border)
            v = v * rt.settings.overworld_scene.border_scroll_opacity
            love.graphics.setColor(v, v, v, v)
            border:draw()
        end

        draw(self._camera_top_border_t, self._camera_top_border)
        draw(self._camera_right_border_t, self._camera_right_border)
        draw(self._camera_bottom_border_t, self._camera_bottom_border)
        draw(self._camera_left_border_t, self._camera_left_border)

        love.graphics.pop()
    end

    if rt.GameState:get_draw_debug_information()
        and rt.SceneManager:get_screen_recorder():get_is_recording() == false
    then
        self:_draw_debug_information()
    end
end

--- @brief
function ow.OverworldScene:draw()
    local draw_below = function()
        love.graphics.push()
        love.graphics.origin()
        self._background:draw()
        love.graphics.pop()

        if self._fade_to_black > 0 then
            local r, g, b, _ = rt.Palette.BLACK:unpack()
            love.graphics.setColor(r, g, b, self._fade_to_black)
            love.graphics.rectangle("fill", self._bounds:unpack())
        end

        self._camera:bind()
        self._stage:draw_below_player()
        self._camera:unbind()
    end

    local draw_player = function()
        self._camera:bind()
        if self._player_is_visible then
            self._player:draw_body()
            self._player:draw_core()
        end
        self._camera:unbind()
    end

    local draw_above = function()
        self._camera:bind()
        self._stage:draw_above_player()
        self._camera:unbind()

        if rt.GameState:get_is_bloom_enabled() then
            rt.SceneManager:get_bloom():composite(
                rt.settings.overworld_scene.bloom_composite_strength
            )
        end
    end

    local draw_indicators = function()
        self._control_indicator_particle_effect:draw()
        local opacity = self._control_indicator_opacity_motion:get_value()
        if opacity > 0 and self._pause_menu_active == false then
            local indicator = self._control_indicator_type_to_control_indicator[self._control_indicator_type]
            if indicator ~= nil then
                indicator:set_opacity(opacity)
                love.graphics.push()
                love.graphics.translate(self._control_indicator_offset_motion:get_position())
                indicator:draw()
                love.graphics.pop()
            end
        end

        if self._camera_override_active then
            love.graphics.push("all")
            love.graphics.setBlendMode("add", "premultiplied")

            local draw = function(v, border)
                v = v * rt.settings.overworld_scene.border_scroll_opacity
                love.graphics.setColor(v, v, v, v)
                border:draw()
            end

            draw(self._camera_top_border_t, self._camera_top_border)
            draw(self._camera_right_border_t, self._camera_right_border)
            draw(self._camera_bottom_border_t, self._camera_bottom_border)
            draw(self._camera_left_border_t, self._camera_left_border)

            love.graphics.pop()
        end
    end

    -- update bloom
    if rt.GameState:get_is_bloom_enabled() then
        local bloom = rt.SceneManager:get_bloom()
        bloom:bind()
        love.graphics.clear(0, 0, 0, 0)
        self._camera:bind()
        if self._player_is_visible then
            self._player:draw_bloom()
        end
        self._stage:draw_bloom()
        self._camera:unbind()
        bloom:unbind()
    end

    local blur_value = self._blur_motion:get_value()
    local use_blur = blur_value > 0.01
    if use_blur then
        self._blur:set_blur_strength(blur_value * rt.settings.overworld_scene.max_blur_strength)
        self._blur:bind()
        love.graphics.clear(0, 0, 0, 0)
    end

    if self._fade_active or self._show_title_card then
        -- when fading, draw player above stage
        draw_below()
        draw_above()
        self._fade:draw()
        draw_player()
        self._title_card:draw()
    else
        draw_below()
        draw_player()
        draw_above()
    end

    if use_blur then
        self._blur:unbind()
        local t = 1 - math.mix(0, rt.settings.overworld_scene.max_blur_darkening, self._blur_motion:get_value())
        love.graphics.setColor(t, t, t, t)
        self._blur:draw()
    end

    draw_indicators()

    if self._pause_menu_active then
        self._pause_menu:draw()
    end

    if rt.GameState:get_draw_debug_information()
        and rt.SceneManager:get_screen_recorder():get_is_recording() == false
    then
        self:_draw_debug_information()
    end
end

--- @brief
function ow.OverworldScene:_update_screenshot(draw_player)
    if self._stage == nil
        or self._screenshot_needs_update == false
    then return end

    local width, height = self:get_bounds().width, self:get_bounds().height
    local format = ternary(rt.GameState:get_is_hdr_enabled(), rt.settings.hdr.texture_format, rt.settings.overworld_scene.screenshot_texture_format)
    if self._screenshot == nil
        or self._screenshot:get_width() ~= width
        or self._screenshot:get_height() ~= height
        or self._screenshot:get_format() ~= format
    then
        self._screenshot = rt.RenderTexture(
            width, height,
            rt.GameState:get_msaa_quality(),
            format
        )
    end

    love.graphics.push("all")
    love.graphics.reset()
    self._screenshot:bind()
    self:draw()
    self._screenshot:unbind()
    love.graphics.pop()
    self._screenshot_needs_update = false
end

--- @brief
function ow.OverworldScene:get_screenshot(draw_player, x, y, width, height)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if width == nil then width = self:get_bounds().width end
    if height == nil then height = self:get_bounds().height end

    self:_update_screenshot(draw_player, x, y, width, height)
    return self._screenshot
end

--- @brief
function ow.OverworldScene:_draw_debug_information()
    if self._hide_debug_information == true then return end

    local collected = {}
    for i = 1, self._stage:get_n_coins() do
        if self._stage:get_coin_is_collected(i) then
            table.insert(collected, "1")
        else
            table.insert(collected, "0")
        end
    end

    local translation = rt.Translation.result_screen_scene

    local collectibles = translation.coins .. " : " .. table.concat(collected)
    local time = translation.time .. " : " .. string.format_time(self:get_timer()) .. " ( " .. tostring(self:get_frame_count()) .. " " .. rt.Translation.overworld_scene.debug_information_frames .. " )"
    local flow = translation.flow .. " : " .. string.format_percentage(self._player:get_flow())

    if self._timer_paused == true or self._timer_started == false or self._timer_stopped then
        time = time .. " (" .. rt.Translation.overworld_scene.debug_information_time_paused .. ")"
    end

    local font = rt.settings.font.love_default

    love.graphics.setFont(font)
    local line_height = font:getHeight()
    love.graphics.setColor(1, 1, 1, 1 - self._fade:get_value())

    love.graphics.push()
    love.graphics.printf(table.concat({
        collectibles,
        flow,
        time
    }, " | "), 10, 5, math.huge)

    love.graphics.pop()

    local m = 2 * rt.settings.margin_unit
    local r = rt.settings.player_input_smoothing.radius
    self._player:get_input_smoothing():draw(r + m, love.graphics.getHeight() - (r + m), r)
end

--- @brief
function ow.OverworldScene:update(delta)
    -- wait for stage to finish
    if self._stage:get_is_initialized() ~= true then
        self._stage:update(delta)
        return
    end

    self._blur_motion:update(delta)

    if self._timer_started == true and self._timer_paused ~= true and self._timer_stopped ~= true then
        self._timer = self._timer + delta
        self._n_frames = self._n_frames + 1
    end

    if self._show_title_card then
        if self._queue_fade_out and self._title_card_elapsed >= rt.settings.overworld_scene.title_card_min_duration then
            self._input:activate()
            self._fade_active = true
            self._title_card:fade_out() -- fade out text
            self._queue_fade_out = nil
        end

        if self._fade_active then
            self._fade:update(delta)
        end

        self._title_card:update(delta)
        self._title_card_elapsed = self._title_card_elapsed + delta
    end

    -- update control indicator
    do
        -- if idle for too long in overworld, display scene control indicator
        -- only override if other indicator is not currently active
        local current_type = self._control_indicator_type
        if self._control_indicator_allow_override then
            if self._player:get_idle_elapsed() > rt.settings.overworld_scene.idle_threshold_duration then
                self:set_control_indicator_type(ternary(
                    self._player:get_is_bubble(),
                    ow.ControlIndicatorType.MOTION_BUBBLE,
                    ow.ControlIndicatorType.MOTION_NON_BUBBLE
                ), false)
            else
                self:set_control_indicator_type(ow.ControlIndicatorType.NONE, false)
            end
        end
    end

    if not self._fade_active then
        self._control_indicator_particle_effect:update(delta)
    end

    self._control_indicator_delay_elapsed = self._control_indicator_delay_elapsed + delta
    if math.equals(self._control_indicator_opacity_motion:get_target_value(), 1) and self._control_indicator_delay_elapsed > rt.settings.overworld_scene.control_indicator_delay then
        self._control_indicator_opacity_motion:update(delta)
    end

    self._control_indicator_offset_motion:update(delta)

    if self._pause_menu_active then
        self._pause_menu:update(delta)
        return
    end

    self._player:update(delta)
    self._camera:update(delta)
    self._stage:update(delta) -- order matters

    self._background:notify_camera_changed(self._camera)
    self._background:update(delta)

    self._screenshot_needs_update = true

    -- player canvas
    if self._player_is_visible and self._player_canvas_needs_update == true then
        love.graphics.push("all")
        love.graphics.reset()
        love.graphics.setColor(1, 1, 1, 1)
        local x, y = self._player:get_position()
        local w, h = self._player_canvas:get_size()

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._player_canvas_scale, self._player_canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)

        love.graphics.translate(-x + 0.5 * w, -y + 0.5 * h)
        self._player_canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        self._player:draw_body()
        self._player:draw_core()
        self._player_canvas:unbind()

        love.graphics.pop()
    end

    self:_update_camera(delta)
end

--- @brief
function ow.OverworldScene:screen_xy_to_world_xy(x, y)
    return self._camera:screen_xy_to_world_xy(x, y)
end

--- @brief
function ow.OverworldScene:world_xy_to_screen_xy(x, y)
    return self._camera:world_xy_to_screen_xy(x, y)
end

--- @brief
function ow.OverworldScene:get_camera()
    return self._camera
end

--- @brief
function ow.OverworldScene:get_player()
    return self._player
end

local _camera_mode_priority = {
    [1] = ow.CameraMode.FREEZE,
    [2] = ow.CameraMode.CUTSCENE,
    [3] = ow.CameraMode.STATIC,
    [4] = ow.CameraMode.BOUNDED,
    [5] = ow.CameraMode.UNBOUNDED
}

--- @brief
function ow.OverworldScene:get_camera_mode()
    for _, mode in ipairs(_camera_mode_priority) do
        if self._camera_modes[mode] > 0 then
            return mode
        end
    end

    return _camera_mode_priority[#_camera_mode_priority]
end

--- @brief
function ow.OverworldScene:reset()
    local before = self._stage_id

    if before ~= nil then
        rt.GameState:reinitialize_stage(before)
    end

    self._stage_id = nil
    self._stage = nil
    self._stage_mapping = {}

    ow.NormalMap:clear_cache()
    ow.Stage:clear_cache()
    ow.StageConfig:clear_cache()
    rt.Sprite._path_to_spritesheet = {}

    self:set_fade_to_black(0)
    self:set_blur(0)
    self:set_control_indicator_type(ow.ControlIndicatorType.NONE)
    self._camera:set_scale(1)

    self:unpause()
    self:enter(before, false)
end

--- @brief
function ow.OverworldScene:restart()
    self:unpause()
    self:set_stage(self._stage_id, false)
end

--- @brief
function ow.OverworldScene:respawn()
    self._stage:get_active_checkpoint():spawn()
    self._camera:set_position(self._player:get_position())
end

--- @brief
function ow.OverworldScene:get_current_stage()
    return self._stage
end

--- @brief
function ow.OverworldScene:pause()
    self._pause_menu_active = true
    self._pause_menu:present()
    self._player:request_is_disabled(self, true)
end

--- @brief
function ow.OverworldScene:unpause()
    if self._pause_menu_active ~= true then return end
    self._pause_menu_active = false
    self._pause_menu:close()
    rt.InputManager:flush()
    self._player:request_is_disabled(self, nil)
end

--- @brief
function ow.OverworldScene:get_player_canvas()
    self._player_canvas_needs_update = true
    return self._player_canvas, self._player_canvas_scale, self._player_canvas_scale
end

--- @brief
function ow.OverworldScene:show_result_screen()
    if self._stage == nil then return end

    local player_x, player_y = self._camera:world_xy_to_screen_xy(self._player:get_position())
    local stage_id = self._stage:get_id()

    local coins = {}
    for coin_i = 1, self._stage:get_n_coins() do
        coins[coin_i] = self._stage:get_coin_is_collected(coin_i)
    end

    self:_update_screenshot(false, -- do not draw player
        0, 0, self:get_bounds().width, self:get_bounds().height
    )

    rt.SceneManager:set_scene(
        ow.ResultScreenScene,
        player_x, player_y,
        self._screenshot,
        {
            stage_id = stage_id,
            coins = coins,
            time = self:get_timer(),
            flow = self._stage:get_flow_fraction(),
        }
    )
end

--- @brief
function ow.OverworldScene:set_control_indicator_type(type, emit_particles)
    if type == nil then type = ow.ControlIndicatorType.NONE end
    meta.assert_enum_value(type, ow.ControlIndicatorType)

    if type ~= self._control_indicator_type then
        self._control_indicator_offset_motion:set_position(
            0, self._control_indicator_max_offset
        )
    end

    if type == ow.ControlIndicatorType.NONE then
        self._control_indicator_opacity_motion:set_target_value(0)
        self._control_indicator_offset_motion:set_target_position(
            0, self._control_indicator_max_offset
        )
    else
        self._control_indicator_opacity_motion:set_target_value(1)
        self._control_indicator_offset_motion:set_target_position(
            0, 0
        )
    end

    if type ~= ow.ControlIndicatorType.NONE then
        self._control_indicator_type = type
        self._control_indicator_delay_elapsed = 0

        if emit_particles == true then
            local x, y, w, h = self._bounds:unpack()
            self._control_indicator_particle_effect:emit(
                x, y + h, x + w, y + h
            )
            self._camera:shake()
        end
    end

    self._control_indicator_allow_override = type == ow.ControlIndicatorType.NONE
        or type == ow.ControlIndicatorType.MOTION_NON_BUBBLE
        or type == ow.ControlIndicatorType.MOTION_BUBBLE
end

--- @brief
function ow.OverworldScene:get_control_indicator_type()
    return self._control_indicator_type
end

--- @brief
function ow.OverworldScene:get_control_indicator()
    return self._control_indicator_type_to_control_indicator[self._control_indicator_type]
end

--- @brief
function ow.OverworldScene:set_fade_to_black(t)
    self._fade_to_black = t
end

--- @brief
function ow.OverworldScene:get_control_indicator(type)
    return self._control_indicator_type_to_control_indicator[type]
end

--- @brief
function ow.OverworldScene:set_blur(t)
    self._blur_motion:set_value(t)
end

--- @brief
function ow.OverworldScene:push_camera_mode(mode)
    meta.assert_enum_value(mode, ow.CameraMode)
    self._camera_modes[mode] = self._camera_modes[mode] + 1
end

--- @brief
function ow.OverworldScene:pop_camera_mode(mode)
    meta.assert_enum_value(mode, ow.CameraMode)
    self._camera_modes[mode] = math.max(0, self._camera_modes[mode] - 1)
end

--- @brief
function ow.OverworldScene:clear_camera_mode()
    for mode in keys(self._camera_modes) do
        self._camera_modes[mode] = 0
    end
end

local _CAMERA_STATE_CUTSCENE = 1
local _CAMERA_STATE_FROZEN = 2
local _CAMERA_STATE_STATIC = 3
local _CAMERA_STATE_BOUNDED = 4
local _CAMERA_STATE_UNBOUNDED = 5
local _CAMERA_STATE_FOLLOW_PLAYER = 6
local _CAMERA_STATE_OVERRIDE = 7

--- @brief
function ow.OverworldScene:_update_camera(delta)
    local camera = self._camera
    local settings = rt.settings.overworld_scene
    local state_before = self._camera_state
    local override_before = self._camera_override_active

    -- override state
    if rt.InputManager:get_input_method() == rt.InputMethod.KEYBOARD then
        local mouse_down = rt.InputManager:get_mouse_is_down(rt.MouseButton.RIGHT)
        local key_down = false
        for key in keys(settings.position_override_keys) do
            if rt.InputManager:get_is_keyboard_key_down(key) == true then
                key_down = true
                break
            end
        end

        self._camera_override_active = mouse_down or key_down

        if self._camera_scale_override then
            local x, y = rt.InputManager:get_mouse_position()
            local bounds = self:get_bounds()
            local easing = rt.InterpolationFunctions.GAUSSIAN_HIGHPASS

            local border_factor = rt.settings.overworld_scene.border_scroll_width
            local border_width = math.min(bounds.width * border_factor, bounds.height * border_factor)

            local left_t = 1 - (x - bounds.x) / border_width
            local right_t = 1 - (bounds.x + bounds.width - x) / border_width
            local top_t = 1 - (y - bounds.y) / border_width
            local bottom_t = 1 - (bounds.y + bounds.height - y) / border_width

            left_t = easing(math.clamp(left_t, 0, 1))
            right_t = easing(math.clamp(right_t, 0, 1))
            top_t = easing(math.clamp(top_t, 0, 1))
            bottom_t = easing(math.clamp(bottom_t, 0, 1))

            self._camera_top_border_t = top_t
            self._camera_right_border_t = right_t
            self._camera_bottom_border_t = bottom_t
            self._camera_left_border_t = left_t
        else
            self._camera_top_border_t = 0
            self._camera_right_border_t = 0
            self._camera_bottom_border_t = 0
            self._camera_left_border_t = 0
        end
    else
        local triggers_pressed = rt.InputManager:get_left_trigger() > math.eps
            or rt.InputManager:get_right_trigger() > math.eps

        local right_joystick = math.magnitude(rt.InputManager:get_right_joystick()) > math.eps

        self._camera_override_active = right_joystick or triggers_pressed

        -- gamepad state to camera override
        local x, y = rt.InputManager:get_right_joystick()
        self._camera_left_border_t = math.abs(math.min(0, x))
        self._camera_right_border_t = math.max(0, x)
        self._camera_top_border_t = math.abs(math.min(0, y))
        self._camera_bottom_border_t = math.max(0, y)
    end

    self._camera:set_apply_bounds(not self._camera_override_active)

    -- on state change
    if self._camera_override_active ~= override_before then
        self._camera_position_override_x, self._camera_position_override_y = self._camera:get_position()

        if rt.InputManager:get_input_method() == rt.InputMethod.KEYBOARD then
            rt.SceneManager:set_is_cursor_visible(self._camera_override_active)

            if self._camera_override_active then
                love.mouse.setX(0.5 * love.graphics.getWidth())
                love.mouse.setY(0.5 * love.graphics.getHeight())
                local bounds = camera:get_world_bounds()
                camera:move_to(bounds.x + 0.5 * bounds.width, bounds.y + 0.5 * bounds.height)
            end
        else
            rt.SceneManager:set_is_cursor_visible(false)
        end

        if self._camera_override_active == false then
            self._camera_scale_override = 1
            self._camera_velocity_x = 0
            self._camera_velocity_y = 0
        end
    end

    if self._camera_override_active == true then
        self._camera_scale_override = math.clamp(
            self._camera_scale_override,
            settings.scale_override_min,
            settings.scale_override_max
        )
        camera:scale_to(self._camera_scale_override * self._camera:get_scale_delta())

        local max_velocity = rt.settings.overworld_scene.border_scroll_velocity
        self._camera_velocity_x = math.mix(0, -max_velocity, self._camera_left_border_t)
            + math.mix(0, max_velocity, self._camera_right_border_t)

        self._camera_velocity_y = math.mix(0, -max_velocity, self._camera_top_border_t)
            + math.mix(0, max_velocity, self._camera_bottom_border_t)

        self._camera_position_override_x = self._camera_position_override_x + self._camera_velocity_x * delta
        self._camera_position_override_y = self._camera_position_override_y + self._camera_velocity_y * delta

        camera:move_to(self._camera_position_override_x, self._camera_position_override_y)
        self._camera_state = _CAMERA_STATE_OVERRIDE
    else
        -- regular camera behavior
        local top = self._camera_modes[1]
        local px, py = self._player:get_position()

        local is_frozen = self._camera_modes[ow.CameraMode.FREEZE] > 0
        local has_cutscene = self._camera_modes[ow.CameraMode.CUTSCENE] > 0
        local has_bounded = self._camera_modes[ow.CameraMode.BOUNDED] > 0
        local has_unbounded = self._camera_modes[ow.CameraMode.UNBOUNDED] > 0
        local has_static = self._camera_modes[ow.CameraMode.STATIC] > 0

        if is_frozen then
            camera:set_is_enabled(false)
            self._camera_state = _CAMERA_STATE_FROZEN
        else
            camera:set_is_enabled(true)

            if has_cutscene then
                -- noop, controlled externally
                self._camera_state = _CAMERA_STATE_CUTSCENE
            elseif has_static then
                -- also controlled externally but lower priority than cutscene
                self._camera_state = _CAMERA_STATE_STATIC
            elseif has_bounded then
                -- scale and bounds controlled externaly
                camera:set_apply_bounds(true)
                camera:move_to(px, py)
                self._camera_state = _CAMERA_STATE_BOUNDED
            elseif has_unbounded then
                -- only scale controlled externally
                camera:set_apply_bounds(false)
                camera:move_to(px, py)
                camera:scale_to(1)
                self._camera_state = _CAMERA_STATE_UNBOUNDED
            else
                -- nothing controlled externally, follow player
                camera:set_apply_bounds(false)
                camera:scale_to(1)
                camera:move_to(px, py)
                self._camera_state = _CAMERA_STATE_FOLLOW_PLAYER
            end
        end
    end

    -- reapply bounds when switching states
    if self._camera_state ~= state_before
        and self._camera_state ~= _CAMERA_STATE_CUTSCENE
    then
        self._stage:apply_camera_bounds(self._player:get_position())
    end
end

--- @brief
function ow.OverworldScene:set_player_is_visible(b)
    self._player_is_visible = b
end
