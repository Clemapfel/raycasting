require "common.scene"
require "common.mesh"
require "common.camera"
require "common.player"
require "common.bloom"
require "common.fade"
require "common.blur"
require "common.timer"
require "common.control_indicator"
require "overworld.control_indicator_type"
require "overworld.background"
require "overworld.stage_title_card"
require "overworld.time_attack_start_countdown"
require "overworld.reveal_particle_effect"
require "menu.pause_menu"
require "menu.message_dialog"

rt.settings.overworld_scene = {
    title_card_min_duration = 3, -- seconds

    idle_threshold_duration = 5,
    control_indicator_delay = 0.0,

    player_canvas_scale = 2, --rt.settings.player_body.texture_scale,
    player_canvas_size_radius_factor = rt.settings.player.bubble_radius_factor * 2.5,

    screenshot_texture_format = rt.RGBA8,

    max_blur_strength = 10, -- gaussian sigma
    max_blur_darkening = 0.82, -- fraction,

    title_card_hold_duration = 2, -- seconds

    position_override_keys = {
        [rt.KeyboardKey.LEFT_CONTROL] = true,
        [rt.KeyboardKey.RIGHT_CONTROL] = true
    },

    scale_override_velocity = 0.25, -- % per mousewheel dy
    scale_override_min = 1 / 8,
    scale_override_max = 8,

    border_scroll_width = 1 / 3, -- fraction
    border_scroll_velocity = 400, -- px / s
    border_scroll_opacity = 0.25,
}

--- @class ow.OverworldScene
ow.OverworldScene = meta.class("OverworldScene", rt.Scene)
meta.add_signal(ow.OverworldScene, "reset")

ow.CameraMode = {
    FREEZE = "FREEZE",      -- all movement disabled
    CUTSCENE = "CUTSCENE",  -- fully controlled externally
    STATIC = "STATIC",      -- hold position, but not frozen
    BOUNDED = "BOUNDED",    -- follow player, stay in camera bounds
    UNBOUNDED = "UNBOUNDED", -- follow player, camera bounds ignored
}
ow.CameraMode = meta.enum("OverworldCameraMode", ow.CameraMode)

ow.StageEntryMode = {
    INSTANT = "INSTANT",
    TITLE_CARD = "TITLE_CARD",
    TIME_ATTACK = "TIME_ATTACK"
}
ow.StageEntryMode = meta.enum("StageEntryMode", ow.StageEntryMode)

-- internal state
local _STATE_GAMEPLAY = "GAMEPLAY"
local _STATE_TITLE_CARD = "TITLE_CARD"
local _STATE_TIME_ATTACK_COUNTDOWN = "TIME_ATTACK_COUNTDOWN"
local _STATE_TIME_ATTACK = "TIME_ATTACK"
local _STATE_IDLE = "IDLE"

--- @brief
function ow.OverworldScene:instantiate(state)
    local settings = rt.settings.overworld_scene
    meta.install(self, {
        _state = _STATE_IDLE,

        _camera = rt.Camera(),
        _camera_modes = {}, -- cf _update_camera
        _player = state:get_player(),
        _stage = nil, -- rt.Stage
        _background = nil, -- ow.Background

        _pause_menu = mn.PauseMenu(self),
        _is_paused = false,

        _fade = rt.Fade(
            settings.fade_duration,
            "overworld/overworld_scene_fade.glsl"
        ),

        _title_card = ow.StageTitleCard(""),
        _title_card_hold_elapsed = 0,
        _queue_title_card_fade_out = false,

        _countdown = ow.TimeAttackStartCountdown(self),
        _countdown_x = 0,
        _countdown_y = 0,

        _player_is_visible = true,
        _player_canvas_scale = rt.settings.overworld_scene.player_canvas_scale,
        _player_canvas = rt.RenderTexture(
            2 * rt.settings.player.radius * settings.player_canvas_size_radius_factor * settings.player_canvas_scale, 
            2 * rt.settings.player.radius * settings.player_canvas_size_radius_factor * settings.player_canvas_scale,
            {
                msaa = 0,
                has_stencil = true
            }
        ),

        _player_canvas_needs_update = true,

        _screenshot = nil, -- rt.RenderTexture
        _screenshot_needs_update = true,
        _screenshot_active = false,

        _blur_motion = rt.SmoothedMotion1D(0),
        _blur = nil, -- rt.Blur

        _fade_to_black_motion = rt.SmoothedMotion1D(0),

        _control_indicator_type_to_control_indicator = {}, -- Table<ow.ControlIndicatorType, rt.ControlIndicator>
        _control_indicator_opacity_motion = rt.SmoothedMotion1D(0, 1),
        _control_indicator_offset_motion = rt.SmoothedMotion2D(0, 0, 1.5),
        _control_indicator_max_offset = 0,
        _control_indicator_type = ow.ControlIndicatorType.NONE,
        _control_indicator_particle_effect = ow.RevealParticleEffect(),

        _timer = rt.Timer(),
        _queue_timer_start = false,

        _time_attack_mode_active = false,
        _time_attack_mode_enter_dialog = mn.MessageDialog(
            rt.Translation.overworld_scene.enter_time_attack_dialog_message,
            rt.Translation.overworld_scene.enter_time_attack_dialog_submessage,
            mn.MessageDialogOption.ACCEPT, mn.MessageDialogOption.CANCEL
        ),

        _time_attack_mode_exit_dialog = mn.MessageDialog(
            rt.Translation.overworld_scene.exit_time_attack_dialog_message,
            rt.Translation.overworld_scene.exit_time_attack_dialog_submessage,
            mn.MessageDialogOption.ACCEPT, mn.MessageDialogOption.CANCEL
        ),

        _input = rt.InputSubscriber(-math.huge),

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
        _camera_right_border = nil, -- "
        _camera_bottom_border = nil,
        _camera_left_border = nil,
    })

    -- init mode priority counts
    for mode in values(meta.instances(ow.CameraMode)) do
        self._camera_modes[mode] = 0
    end
    
    -- init control indicators
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

    require "overworld.dialog_box"
    local dialog_button = rt.settings.overworld.dialog_box.advance_button
    self._control_indicator_type_to_control_indicator = {
        [ow.ControlIndicatorType.NONE] = create_indicator(),

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

        [ow.ControlIndicatorType.OMNIDIRECTIONAL_MOVEMENT] = create_indicator(
            rt.ControlIndicatorButton.ALL_DIRECTIONS, translation.control_indicator_omnidirectional_movement,
            rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump
        ),

        [ow.ControlIndicatorType.SLIDE_FREELY] = create_indicator(
            rt.ControlIndicatorButton.DOWN, translation.control_indicator_slide
        ),

        [ow.ControlIndicatorType.MID_AIR_HOLD_DOWN_TO_ACCELERATRE] = create_indicator(
            rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_move,
            rt.ControlIndicatorButton.DOWN, translation.control_indicator_hold_down
        ),

        [ow.ControlIndicatorType.ACCELERATOR_SURFACE_VERTICAL] = create_indicator(
            rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_accelerator_surface_hold
        ),

        [ow.ControlIndicatorType.ACCELERATOR_SURFACE_HORIZONTAL] = create_indicator(
            rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_accelerator_surface_hold
        ),

        [ow.ControlIndicatorType.ACCELERATOR_SURFACE_GENERAL] = create_indicator(
            rt.ControlIndicatorButton.ALL_DIRECTIONS, translation.control_indicator_accelerator_surface_hold
        ),

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

    for type in values(meta.instances(ow.ControlIndicatorType)) do
        if self._control_indicator_type_to_control_indicator[type] == nil
        then
            rt.error("In ow.OverworldScene:instantiate: no control indicator for type `", type, "` allocated")
        end
    end

    -- connect input
    self._input:deactivate()

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == rt.KeyboardKey.CIRCUMFLEX then
            local before_id = self._stage:get_id()

            if before_id ~= nil then
                rt.GameState:reinitialize_stage(before_id)
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
            self._camera:reset()

            rt.InputManager:flush()
            self:enter(before_id, ow.StageEntryMode.INSTANT, true) -- override
        elseif which == rt.KeyboardKey.I then
            self:_set_state(_STATE_TIME_ATTACK_COUNTDOWN)
        elseif which == rt.KeyboardKey.O then
            self:_set_state(_STATE_TITLE_CARD)
        end
    end)

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.PAUSE then
            if self._is_paused then
                self:unpause()
            else
                self:pause()
            end
        end

        if self._time_attack_mode_enter_dialog:get_is_active() then
            self._time_attack_mode_enter_dialog:handle_button(which)
        end

        if self._time_attack_mode_exit_dialog:get_is_active() then
            self._time_attack_mode_exit_dialog:handle_button(which)
        end
    end)

    -- camera controls
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

    -- dialogs
    self._time_attack_mode_enter_dialog:signal_connect("selection", function(dialog, option)
        if self._stage == nil then return end
        if option == mn.MessageDialogOption.ACCEPT then
            self:set_stage(self._stage:get_id(), ow.StageEntryMode.TIME_ATTACK)
        end

        dialog:close()
    end)

    self._time_attack_mode_exit_dialog:signal_connect("selection", function(dialog, option)
        if self._stage == nil then return end
        if option == mn.MessageDialogOption.ACCEPT then
            self:set_stage(self._stage:get_id(), ow.StageEntryMode.TITLE_CARD)
        end

        dialog:close()
    end)
end

--- @brief
function ow.OverworldScene:enter(stage_id, entry_mode, should_reinitialize)
    if not self:get_is_active() or should_reinitialize then
        if entry_mode == nil then entry_mode = ow.StageEntryMode.INSTANT end
        meta.assert(stage_id, "String", entry_mode, ow.StageEntryMode)

        self:set_stage(stage_id, entry_mode)
    end

    self._input:activate()
    rt.SceneManager:set_use_fixed_timestep(true)
    rt.SceneManager:set_is_cursor_visible(true)

    local bloom = rt.SceneManager:get_bloom()
end

--- @brief
function ow.OverworldScene:exit()
    self._input:deactivate()

    if rt.GameState:get_is_dynamic_lighting_enabled() then
        local map = rt.SceneManager:get_light_map()
        if map ~= nil then
            map:reset()
        end
    end

    if rt.GameState:get_is_bloom_enabled() then
        local bloom = rt.SceneManager:get_bloom()
        if bloom ~= nil then
            bloom:reset()
        end
    end
end

--- @brief
function ow.OverworldScene:set_stage(stage_id, entry_mode)
    self._background = ow.Background(self, rt.GameState:stage_get_background_id(stage_id))

    if self:get_is_realized() then
        self._background:realize()
        self._background:reformat(self:get_bounds():unpack())
    end

    self._title_card:set_title(rt.GameState:get_stage_name(stage_id))

    if self._stage ~= nil and self._stage:get_id() == stage_id then
        self._stage:reset()
    else
        self._stage = ow.Stage(self, stage_id)
    end

    self._stage:set_active_checkpoint(nil) -- spawn
    self._player:move_to_stage(self._stage)

    self._timer:reset()

    if rt.GameState:get_is_dynamic_lighting_enabled() then
        rt.SceneManager:get_light_map():reset()
    end

    if rt.GameState:get_is_bloom_enabled() then
        rt.SceneManager:get_bloom():reset()
    end

    if entry_mode == ow.StageEntryMode.TITLE_CARD then
        self:_set_state(_STATE_TITLE_CARD)
    elseif entry_mode == ow.StageEntryMode.TIME_ATTACK then
        self:_set_state(_STATE_TIME_ATTACK_COUNTDOWN)
    elseif entry_mode == ow.StageEntryMode.INSTANT then
        if self._state == _STATE_TIME_ATTACK then
            self:_set_state(_STATE_TIME_ATTACK)
        else
            self:_set_state(_STATE_GAMEPLAY)
        end
    end
end

--- @brief
function ow.OverworldScene:realize()
    if self:already_realized() then return end

    for widget in range(
        self._background,
        self._countdown,
        self._pause_menu,
        self._title_card,
        self._time_attack_mode_enter_dialog,
        self._time_attack_mode_exit_dialog
    ) do
        widget:realize()
    end

    for indicator in values(self._control_indicator_type_to_control_indicator) do
        indicator:realize()
    end
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)
    if self._blur == nil
        or self._blur:get_width() ~= width
        or self._blur:get_height() ~= height
    then
        self._blur = rt.Blur(width, height, {
            msaa = rt.GameState:get_msaa(),
            has_stencil = true,
            has_depth = true
        })
    end

    local m = rt.SceneManager:get_margin_unit()
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
        self._countdown,
        self._pause_menu,
        self._title_card,
        self._time_attack_mode_enter_dialog,
        self._time_attack_mode_exit_dialog
    ) do
        widget:reformat(0, 0, width, height)
    end

    do
        local border_factor = rt.settings.overworld_scene.border_scroll_width
        local thickness = math.min(width * border_factor, height * border_factor)

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
function ow.OverworldScene:_set_state(next_state)
    local current_state = self._state

    local reset = function()
        self._stage:reset()
        self._stage:set_active_checkpoint(nil)
        self._player:move_to_stage(self._stage)
    end

    local clear = function()
        self._countdown:skip()
        self._fade:skip()
        self._title_card:skip()
        self._queue_title_card_fade_out = false
        self._timer:reset()
    end

    self._countdown:signal_disconnect_all()
    self._fade:signal_disconnect_all()
    self._title_card:signal_disconnect_all()

    if next_state == _STATE_TIME_ATTACK_COUNTDOWN then
        clear()
        self:set_blur(1)

        self._countdown_x, self._countdown_y = self._stage:get_spawn_location()

        self._fade:signal_connect("hidden", function(_)
            reset()
            self._countdown:start()
            self:set_blur(0)
            return meta.DISCONNECT_SIGNAL
        end)

        self._countdown:signal_connect("done", function(_)
            self:_set_state(_STATE_TIME_ATTACK)
            return meta.DISCONNECT_SIGNAL
        end)

        self._fade:start()

    elseif next_state == _STATE_TIME_ATTACK or next_state == _STATE_GAMEPLAY then
        self:set_blur(0)
        self._queue_timer_start = true

    elseif next_state == _STATE_TITLE_CARD then
        clear()
        reset()

        self._fade:start(false, true) -- skip to full black
        self._title_card:fade_in()
        self._title_card_hold_elapsed = -math.huge

        self._queue_title_card_fade_out = true
        -- fade_out called in update

        self._title_card:signal_connect("hidden", function(_)
            self._title_card_hold_elapsed = 0 -- start hold, cf. update
            self:_set_state(_STATE_GAMEPLAY)
            -- player can move during hold, moves as soon as stage is loaded
        end)
    end

    self._state = next_state
end

--- @brief
function ow.OverworldScene:update(delta)
    if self._stage == nil then return end

    if self._stage:get_is_initialized() ~= true then
        -- wait for stage loading to finish
        self._title_card:update(delta)
        self._fade:update(delta)
        self._stage:update(delta)
        return
    end

    -- title card
    self._title_card_hold_elapsed = self._title_card_hold_elapsed + delta
    if self._stage:get_is_initialized()
        and self._queue_title_card_fade_out == true
        and self._title_card_hold_elapsed >= rt.settings.overworld_scene.title_card_hold_duration
    then
        self._title_card:fade_out()
        self._queue_title_card_fade_out = false
        self._title_card_hold_elapsed = math.huge
    end

    -- if dialog active, pause everything
    if self._time_attack_mode_enter_dialog:get_is_active() then
        self._time_attack_mode_enter_dialog:update(delta)
        return
    elseif self._time_attack_mode_exit_dialog:get_is_active() then
        self._time_attack_mode_exit_dialog:update(delta)
        return
    end

    -- order matters

    if self._is_paused ~= true then
        self._player:update(delta)
        self._camera:update(delta)
        self._stage:update(delta)
        self._background:notify_camera_changed(self._camera)
        self._background:update(delta)

        self:_update_camera(delta)

        self._screenshot_needs_update = true
        self._player_canvas_needs_update = true
    end

    for x in range(
        self._pause_menu,
        self._blur_motion,
        self._fade,
        self._fade_to_black_motion,
        self._control_indicator_offset_motion,
        self._control_indicator_opacity_motion,
        self._title_card,
        self._countdown,
        self._control_indicator_particle_effect
    ) do
        x:update(delta)
    end

    if not (self._state == _STATE_GAMEPLAY or self._state == _STATE_TIME_ATTACK) then
        self._player:request_is_movement_disabled(self, true)
    else
        self._player:request_is_movement_disabled(self, nil)
    end

    if (self._state == _STATE_TIME_ATTACK_COUNTDOWN or self._state == _STATE_TITLE_CARD) then
        self._player:request_is_disabled(self, true)
        self._player:request_is_frozen(self, true)
    else
        self._player:request_is_disabled(self, nil)
        self._player:request_is_frozen(self, nil)
    end

    if self._queue_timer_start and self._player:get_is_movement_disabled() == false and self._player:get_is_frozen() == false then
        self._timer:start()
        self._queue_timer_start = false
    end

    -- update light map
    if self._stage ~= nil and (self._stage:get_should_draw_light() or self._stage:get_should_draw_darkness()) then
        rt.SceneManager:get_light_map():update(self._stage, delta)
    end
end

--- @brief
function ow.OverworldScene:draw()
    if self._stage == nil or self._stage:get_is_initialized() ~= true then
        return
    end

    local draw_below = function()
        love.graphics.push()
        love.graphics.origin()
        self._background:draw()
        love.graphics.pop()

        local r, g, b, _ = rt.Palette.BLACK:unpack()
        love.graphics.setColor(r, g, b, self._fade_to_black_motion:get_value())
        love.graphics.rectangle("fill", self._bounds:unpack())

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

        if rt.GameState:get_is_dynamic_lighting_enabled()
            and self._stage:get_should_draw_darkness()
        then
            rt.SceneManager:get_light_map():composite()
        end

        if rt.GameState:get_is_bloom_enabled() then
            rt.SceneManager:get_bloom():composite()
        end

        self._camera:bind()

        self._stage:draw_above_bloom()

        if self._countdown:get_is_active() then
            love.graphics.push()
            local _, _, w, h = self:get_bounds():unpack()
            love.graphics.translate(self._countdown_x - 0.5 * w, self._countdown_y - 0.5 * h)
            self._countdown:draw()
            love.graphics.pop()
        end

        self._camera:unbind()
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

        if self._state ~= _STATE_TITLE_CARD then
            self._stage:draw_bloom()
        end

        self._camera:unbind()

        if self._title_card:get_is_active() then
            self._title_card:draw_bloom()
        end

        if self._countdown:get_is_active() then
            self._countdown:draw_bloom()
        end

        bloom:unbind()
        bloom:flush()
    end

    local blur_value = self._blur_motion:get_value()
    local use_blur = blur_value > 0.01 and self._screenshot_active ~= true
    if use_blur then
        self._blur:set_blur_strength(blur_value * rt.settings.overworld_scene.max_blur_strength)
        self._blur:bind()
        love.graphics.clear(0, 0, 0, 0)
    end

    if self._title_card:get_is_active() then
        -- when fading, draw player above stage fade-in
        draw_below()
        draw_above()
        self._fade:draw()
        draw_player()

        self._title_card:draw()
    else
        draw_below()
        draw_player()
        draw_above()
        self._fade:draw()
        self._title_card:draw()
    end

    if use_blur then
        self._blur:unbind()
        local t = 1 - math.mix(0, rt.settings.overworld_scene.max_blur_darkening, self._blur_motion:get_value())
        love.graphics.setColor(t, t, t, t)
        self._blur:draw()
    end

    draw_indicators()

    if self._is_paused then
        self._pause_menu:draw()
    end

    if self._time_attack_mode_enter_dialog:get_is_active() then
        self._time_attack_mode_enter_dialog:draw()
    end

    if self._time_attack_mode_exit_dialog:get_is_active() then
        self._time_attack_mode_exit_dialog:draw()
    end
end

--- @brief
function ow.OverworldScene:get_debug_information()
    if self._hide_debug_information == true or self._stage == nil then return "" end

    local collected = {}
    for i = 1, self._stage:get_n_coins() do
        if self._stage:get_coin_is_collected(i) then
            table.insert(collected, "1")
        else
            table.insert(collected, "0")
        end
    end

    local translation = rt.Translation.result_screen_scene

    local collectibles = translation.coins .. " : "
    if rt.GameState:get_stage_n_coins(self._stage:get_id()) == 0 then
        collectibles = collectibles .. rt.Translation.overworld_scene.debug_information_no_coins
    else
        collectibles = collectibles .. table.concat(collected)
    end

    local time = translation.time .. " : " .. string.format_time(self:get_timer())
    local flow = translation.flow .. " : " .. string.format_percentage(self._player:get_flow())

    local font = rt.settings.font.love_default

    love.graphics.setFont(font)
    local line_height = font:getHeight()
    love.graphics.setColor(1, 1, 1, 1 - self._fade:get_value())

    return table.concat({
        collectibles,
        flow,
        time
    }, " | ")

    --[[
    local m = 2 * rt.SceneManager:get_margin_unit()
    local r = rt.settings.player_input_smoothing.radius
    self._player:get_input_smoothing():draw(r + m, love.graphics.getHeight() - (r + m), r)
    ]]
end

--- @brief
function ow.OverworldScene:show_result_screen()
    if self._stage == nil then return end

    local player_x, player_y = self._camera:world_xy_to_screen_xy(self._player:get_position())
    local player_vx, player_vy = self._player:get_velocity()
    local stage_id = self._stage:get_id()

    local coins = {}
    for coin_i = 1, self._stage:get_n_coins() do
        coins[coin_i] = self._stage:get_coin_is_collected(coin_i)
    end

    self:_update_screenshot(false) -- do not draw player

    require "overworld.result_screen_scene"
    rt.SceneManager:set_scene(
        ow.ResultScreenScene,
        player_x, player_y,
        player_vx, player_vy,
        self._screenshot,
        {
            stage_id = stage_id,
            coins = coins,
            time = self:get_timer(),
            flow = self._stage:get_flow_fraction()
        }
    )
end

--- @brief
function ow.OverworldScene:get_timer()
    return self._timer:get_elapsed()
end

--- @brief
function ow.OverworldScene:stop_timer()
    self._timer:stop()
end

--- @brief
function ow.OverworldScene:set_player_is_visible(b)
    self._player_is_visible = b
end

--- @brief
function ow.OverworldScene:get_player_is_visible()
    return self._player_is_visible
end

--- @brief
function ow.OverworldScene:_update_screenshot(draw_player)
    if self._stage == nil
        or self._screenshot_needs_update == false then
        return
    end

    self._screenshot_active = true

    local width, height = self:get_bounds().width, self:get_bounds().height
    local format = ternary(rt.GameState:get_is_hdr_enabled(), rt.settings.hdr.texture_format, rt.settings.overworld_scene.screenshot_texture_format)
    if self._screenshot == nil
        or self._screenshot:get_width() ~= width
        or self._screenshot:get_height() ~= height
        or self._screenshot:get_format() ~= format
    then
        self._screenshot = rt.RenderTexture(width, height, {
            msaa = rt.GameState:get_msaa(),
            format = format,
            has_depth = true,
            has_stencil = true,
        })
    end

    local before = self._player_is_visible

    self._player_is_visible = draw_player
    love.graphics.push("all")
    love.graphics.reset()

    self._screenshot:bind()

    love.graphics.clear(0, 0, 0, 0)
    self:draw()
    self._screenshot:unbind()
    love.graphics.pop()
    self._screenshot_needs_update = false

    self._screenshot_active = false
    self._player_is_visible = before
end

--- @brief
function ow.OverworldScene:get_screenshot(draw_player)
    self:_update_screenshot(draw_player)
    return self._screenshot
end

--- @brief
function ow.OverworldScene:_update_player_canvas()
    if self._stage == nil or self._player_canvas_needs_update ~= true then return end

    love.graphics.push("all")
    love.graphics.reset()

    local x, y = self._player:get_position()
    local w, h = self._player_canvas:get_size()

    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(self._player_canvas_scale, self._player_canvas_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)

    love.graphics.translate(-x + 0.5 * w, -y + 0.5 * h)

    self._player_canvas:bind()
    love.graphics.clear(0, 0, 0, 0)

    if self._player_is_visible then
        self._player:draw_body()
        self._player:draw_core()
    end

    self._player_canvas:unbind()

    love.graphics.pop()
end

--- @brief
function ow.OverworldScene:get_player_canvas()
    if self._player_canvas_needs_update then
        self:_update_player_canvas()
    end

    return self._player_canvas, self._player_canvas_scale, self._player_canvas_scale
end

--- @brief
function ow.OverworldScene:get_camera()
    return self._camera
end

do
    local _camera_mode_priority = {
        [1] = ow.CameraMode.FREEZE,
        [2] = ow.CameraMode.CUTSCENE,
        [3] = ow.CameraMode.STATIC,
        [4] = ow.CameraMode.BOUNDED,
        [5] = ow.CameraMode.UNBOUNDED
    }

    --- @brief
    function ow.OverworldScene:push_camera_mode(mode)
        meta.assert(mode, ow.CameraMode)
        self._camera_modes[mode] = self._camera_modes[mode] + 1
    end

    --- @brief
    function ow.OverworldScene:pop_camera_mode(mode)
        meta.assert(mode, ow.CameraMode)
        self._camera_modes[mode] = math.max(0, self._camera_modes[mode] - 1)
    end

    --- @brief
    function ow.OverworldScene:clear_camera_mode()
        for mode in keys(self._camera_modes) do
            self._camera_modes[mode] = 0
        end
    end

    --- @brief
    function ow.OverworldScene:get_camera_mode()
        for _, mode in ipairs(_camera_mode_priority) do
            if self._camera_modes[mode] > 0 then
                return mode
            end
        end

        return _camera_mode_priority[#_camera_mode_priority]
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

        rt.SceneManager:set_is_cursor_visible(self._camera_override_active)

        -- on state change
        if self._camera_override_active ~= override_before then
            self._camera_position_override_x, self._camera_position_override_y = self._camera:get_position()

            if rt.InputManager:get_input_method() == rt.InputMethod.KEYBOARD then
                if self._camera_override_active then
                    love.mouse.setX(0.5 * love.graphics.getWidth())
                    love.mouse.setY(0.5 * love.graphics.getHeight())
                    local bounds = camera:get_world_bounds()
                    camera:move_to(bounds.x + 0.5 * bounds.width, bounds.y + 0.5 * bounds.height)
                end
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
                    camera:scale_to(1)
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
end

--- @brief
function ow.OverworldScene:get_player()
    return self._player
end

--- @brief
function ow.OverworldScene:get_control_indicator_type()
    return self._control_indicator_type
end

--- @brief
function ow.OverworldScene:set_control_indicator_type(type)
    meta.assert(type, ow.ControlIndicatorType)
    self._control_indicator_type = type
end

--- @brief
function ow.OverworldScene:get_control_indicator()
    return self._control_indicator_type_to_control_indicator[self._control_indicator_type]
end

--- @brief
function ow.OverworldScene:set_fade_to_black(t)
    self._fade_to_black_motion:set_value(t) -- sic, no interpolation
end

--- @brief
function ow.OverworldScene:set_blur(t)
    self._blur_motion:set_value(t)
end

--- @brief
function ow.OverworldScene:pause()
    if self._is_paused ~= true then
        self._is_paused = true
        self._pause_menu:present()
    end
end

--- @brief
function ow.OverworldScene:unpause()
    if self._is_paused ~= false then
        self._is_paused = false
        self._pause_menu:close()
        rt.InputManager:flush()
    end
end

--- @brief
function ow.OverworldScene:get_is_time_attack_mode_active()
    return self._state == _STATE_TIME_ATTACK_COUNTDOWN
        or self._state == _STATE_TIME_ATTACK
end