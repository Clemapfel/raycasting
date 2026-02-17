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

        player_canvas_scale = rt.settings.player_body.canvas_scale,
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
    BOUNDED = "BOUNDED",     -- follow player, stay in camera bounds
    UNBOUNDED = "UNBOUNDED", -- follow player, camera bounds ignored
})

local _bloom_shader = nil

ow.ControlIndicatorType = meta.enum("ControlIndicatorType", {
    MOTION_NON_BUBBLE = "MOTION_NON_BUBBLE",
    MOTION_BUBBLE = "MOTION_BUBBLE",
    INTERACT = "INTERACT",
    SLIDE = "SLIDE",
    DIALOG_CAN_ADVANCE_CAN_EXIT = "DIALOG_CAN_ADVANCE_CAN_EXIT",
    DIALOG_CAN_ADVANCE_CANNOT_EXIT = "DIALOG_CAN_ADVANCE_CANNOT_EXIT",
    DIALOG_CANNOT_ADVANCE_CAN_EXIT = "DIALOG_CANNOT_ADVANCE_CAN_EXIT",
    DIALOG_CANNOT_ADVANCE_CANNOT_EXIT = "DIALOG_CANNOT_ADVANCE_CANNOT_EXIT",
    AIR_DASH = "AIR_DASH",
    DOUBLE_JUMP = "DOUBLE_JUMP",
    NONE = "NONE"
})

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
        _input = rt.InputSubscriber(false),
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
        _blur_t = 0,
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
    local dialog_control_indicator = function(can_advance, can_exit)
        if can_advance == false and can_exit == false then return nil end

        local config = {}
        if can_advance then
            table.insert(config, rt.ControlIndicatorButton.CONFIRM)
            table.insert(config, translation.control_indicator_dialog_confirm)
        end

        if can_exit then
            table.insert(config, rt.ControlIndicatorButton.INTERACT)
            table.insert(config, translation.control_indicator_dialog_leave)
        end

        local out = rt.ControlIndicator(table.unpack(config))
        out:set_has_frame(false)
        return out
    end

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

        [ow.ControlIndicatorType.NONE] = nil,
        [ow.ControlIndicatorType.DIALOG_CAN_ADVANCE_CAN_EXIT] = dialog_control_indicator(true, true),
        [ow.ControlIndicatorType.DIALOG_CAN_ADVANCE_CANNOT_EXIT] = dialog_control_indicator(true, false),
        [ow.ControlIndicatorType.DIALOG_CANNOT_ADVANCE_CAN_EXIT] = dialog_control_indicator(false, true),
        [ow.ControlIndicatorType.DIALOG_CANNOT_ADVANCE_CANNOT_EXIT] = dialog_control_indicator(false, false),
    }

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
        if not self._pause_menu_active and which == rt.InputAction.PAUSE then
            self:pause()
        elseif self._pause_menu_active and which == rt.InputAction.BACK then
            self:unpause()
        end
    end)

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        -- debug reload
        if which == "^" then
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
        end
    end)

    self._input:signal_connect("mouse_wheel_moved", function(_, x, y)
        if self._camera_override_active then
            local settings = rt.settings.overworld_scene
            self._camera_scale_override = self._camera_scale_override + y * settings.scale_override_velocity
            -- clamped in _update_camera
        end
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

    if rt.SceneManager:get_is_bloom_enabled() then
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
    if self._screenshot == nil
        or self._screenshot:get_width() ~= width
        or self._screenshot:get_height() ~= height
    then
        if self._screenshot ~= nil then self._screenshot:free() end

        self._screenshot = rt.RenderTexture(
            width, height,
            0, -- msaa
            rt.settings.overworld_scene.screenshot_texture_format
        )
        self._screenshot_needs_update = true
    end

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

    local draw_bloom = function()
        if rt.GameState:get_is_bloom_enabled() == true then
            local bloom = rt.SceneManager:get_bloom()
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

            bloom:composite(rt.settings.overworld_scene.bloom_composite_strength)
        end
    end

    love.graphics.push("all")

    love.graphics.origin()
    if self._blur_t == 0 and not (self._show_title_card == true and (self._fade:get_is_active() or self._fade:get_is_visible())) then
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

        draw_bloom()

    elseif self._blur_t > 0 then -- respawning
        if self._blur ~= nil then
            self._blur:set_blur_strength(self._blur_t * rt.settings.overworld_scene.max_blur_strength)
            self._blur:bind()
            love.graphics.clear(0, 0, 0, 0)

            self._background:draw()
            self._camera:bind()
            self._stage:draw_below_player()
            self._stage:draw_above_player()
            self._camera:unbind()

            draw_bloom()

            self._blur:unbind()

            local t = 1 - math.mix(0, rt.settings.overworld_scene.max_blur_darkening, self._blur_t)
            love.graphics.setColor(t, t, t, 1)
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

        if rt.GameState:get_is_bloom_enabled() == true then
            local bloom = rt.SceneManager:get_bloom()
            love.graphics.push()
            bloom:bind()
            love.graphics.clear(0, 0, 0, 0)
            self._camera:bind()
            if self._player_is_visible then
                self._player:draw_bloom()
            end
            self._title_card:draw()
            self._camera:unbind()
            bloom:unbind()
            love.graphics.pop()

            bloom:composite(rt.settings.overworld_scene.bloom_composite_strength)
        end
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

    if rt.GameState:get_draw_debug_information() then
        self:_draw_debug_information()
    end
end

function ow.OverworldScene:_update_screenshot(draw_player)
    if self._stage == nil
        or self._screenshot == nil
        or self._screenshot_needs_update == false
    then return end

    love.graphics.push("all")
    love.graphics.reset()
    self._screenshot:bind()

    love.graphics.clear(0, 0, 0, 0)
    self._background:draw()

    if self._fade_to_black > 0 then
        local r, g, b, _ = rt.Palette.BLACK:unpack()
        love.graphics.setColor(r, g, b, self._fade_to_black)
        love.graphics.rectangle("fill", self._bounds:unpack())
    end

    self._camera:bind()
    self._stage:draw_below_player()
    if draw_player == true then
        self._player:draw_body()
        self._player:draw_core()
    end
    self._stage:draw_above_player()
    self._camera:unbind()

    if rt.GameState:get_is_bloom_enabled() == true then
        local bloom = rt.SceneManager:get_bloom()
        -- skip bloom, use bloom from last update
    end

    self._screenshot:unbind()

    love.graphics.pop()
    self._screenshot_needs_update = false
end

--- @brief
function ow.OverworldScene:get_screenshot(draw_player)
    self:_update_screenshot(draw_player)
    return self._screenshot
end

function ow.OverworldScene:_draw_debug_information()
    if self._hide_debug_information == true then return end

    local player = self._player
    local flow_percentage = player:get_flow()

    flow_percentage = tostring(math.round(flow_percentage * 100) / 100)

    local pressed, unpressed = "1", "0"
    local up = ternary(self._player._up_button_is_down, pressed, unpressed)
    local right = ternary(self._player._right_button_is_down, pressed, unpressed)
    local down = ternary(self._player._down_button_is_down, pressed, unpressed)
    local left = ternary(self._player._left_button_is_down, pressed, unpressed)
    local a = ternary(self._player._sprint_button_is_down, pressed, unpressed)
    local b = ternary(self._player._jump_button_is_down, pressed, unpressed)

    local sprint
    if rt.GameState:get_player_sprint_mode() == rt.PlayerSprintMode.MANUAL then
        sprint = self._player._sprint_button_is_down == true
    else
        sprint = self._player._sprint_toggled
    end
    sprint = ternary(sprint, pressed, unpressed)

    local time = "# cycles : " .. self:get_frame_count()

    if self._timer_paused == true or self._timer_started == false or self._timer_stopped then
        time = time .. " (paused)"
    end

    local to_concat = {
        up .. right .. down .. left .. " " .. a .. b,
        "sprint: " .. sprint,
        "flow : " .. flow_percentage .. "%",
        time
    }

    local font = rt.settings.font.love_default

    love.graphics.setFont(font)
    local line_height = font:getHeight()
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.push()
    love.graphics.translate(5, 5) -- top margins
    love.graphics.printf(table.concat(to_concat, " | "), 0, 0, math.huge)

    if self._stage ~= nil and rt.GameState:get_draw_speedrun_splits() then
        -- draw speedrun splits as two columns
        local splits = {}
        local currents_strings = {}
        local current_widths = {}
        local bests_strings = {}
        local best_widths = {}
        local delta_strings = {}
        local delta_widths = {}

        local current_max_width = -math.huge
        local best_max_width = -math.huge
        local delta_max_width = -math.huge

        local bests = rt.GameState:stage_get_splits_best_run(self._stage_id)
        local currents = self._stage:get_checkpoint_splits()

        local translation = rt.Translation.splits_viewer

        for i, split in ipairs(bests) do
            local current, best = currents[i], bests[i]
            local delta
            if current == nil or self._timer_started == false then
                current = translation.unknown
                delta = 0
            else
                delta = best - current
                current = string.format_time(current)
            end

            if best == 0 then
                best = translation.unknown
            else
                best = string.format_time(best)
            end

            if delta > 0 then
                delta = "-" .. string.format_time(math.abs(delta))
            elseif delta < 0 then
                delta = "+" .. string.format_time(math.abs(delta))
            else
                delta = translation.unknown
            end

            table.insert(currents_strings, current)
            table.insert(bests_strings, best)
            table.insert(delta_strings, delta)

            local current_width = font:getWidth(current)
            local best_width = font:getWidth(best)
            local delta_width = font:getWidth(delta)

            table.insert(current_widths, current_width)
            table.insert(best_widths, best_width)
            table.insert(delta_widths, delta_width)

            current_max_width = math.max(current_max_width, current_width)
            best_max_width = math.max(best_max_width, best_width)
            delta_max_width = math.max(delta_max_width, delta_width)
        end

        local current_header = translation.current_header
        local current_header_width = font:getWidth(current_header)

        local delta_header = translation.delta_header
        local delta_header_width = font:getWidth(delta_header)

        local best_header = translation.best_header
        local best_header_width = font:getWidth(best_header)

        current_max_width = math.max(current_max_width, current_header_width)
        best_max_width = math.max(best_max_width, best_header_width)
        delta_max_width = math.max(delta_max_width, delta_header_width)

        love.graphics.translate(0, 2 * line_height)
        local spacing = font:getWidth("\t")

        local start_x = spacing --0 + love.graphics.getWidth() - (current_max_width + spacing + best_max_width + spacing + delta_max_width + spacing)
        do
            local current_x = start_x
            love.graphics.printf(best_header, current_x + best_max_width - best_header_width, 0, math.huge)
            current_x = current_x + best_max_width + spacing

            love.graphics.printf(current_header, current_x + current_max_width - current_header_width, 0, math.huge)
            current_x = current_x + current_max_width + spacing

            love.graphics.printf(delta_header, current_x + delta_max_width - delta_header_width, 0, math.huge)
            current_x = current_x + delta_max_width + spacing
        end

        love.graphics.translate(0, line_height)

        for i = 1, #bests do
            local current, current_width = currents_strings[i], current_widths[i]
            local best, best_width = bests_strings[i], best_widths[i]
            local delta, delta_width = delta_strings[i], delta_widths[i]

            local current_x = start_x

            love.graphics.printf(best, current_x + best_max_width - best_width, 0, math.huge)
            current_x = current_x + best_max_width + spacing

            love.graphics.printf(current, current_x + current_max_width - current_width, 0, math.huge)
            current_x = current_x + current_max_width + spacing

            love.graphics.printf(delta, current_x + delta_max_width - delta_width, 0, math.huge)
            current_x = current_x + delta_max_width + spacing

            love.graphics.translate(0, line_height)
        end
    end

    love.graphics.pop()
end


--- @brief
function ow.OverworldScene:update(delta)
    -- wait for stage to finish
    if self._stage:get_is_initialized() ~= true then
        self._stage:update(delta)
        return
    end

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

--- @brief
function ow.OverworldScene:get_camera_mode()
    return self._camera_mode
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

    self:_update_screenshot(false) -- do not draw player
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
function ow.OverworldScene:get_pause_on_focus_lost()
    return false
end

--- @brief
function ow.OverworldScene:set_control_indicator_type(type, emit_particles)
    if type == nil then type = ow.ControlIndicatorType.NONE end
    meta.assert_enum_value(type, ow.ControlIndicatorType)

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
    self._blur_t = t
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

--- @brief
function ow.OverworldScene:_update_camera(delta)
    local camera = self._camera
    local settings = rt.settings.overworld_scene

    -- override state
    local before = self._camera_override_active
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
        local right_joystick_pressed = math.magnitude(rt.InputManager:get_right_joystick()) > math.eps

        self._camera_override_active = right_joystick_pressed or triggers_pressed

        -- gamepad state to camera override
        if triggers_pressed == false then
            local x, y = rt.InputManager:get_right_joystick()
            self._camera_left_border_t = math.abs(math.min(0, x))
            self._camera_right_border_t = math.max(0, x)
            self._camera_top_border_t = math.abs(math.min(0, y))
            self._camera_bottom_border_t = math.max(0, y)
        else
            local _, y = rt.InputManager:get_right_joystick()
            self._camera_scale_override = self._camera_scale_override + y * settings.scale_override_velocity
        end
    end

    if self._camera_override_active ~= before then
        self._camera_position_override_x, self._camera_position_override_y = self._camera:get_position()

        if rt.InputManager:get_input_method() == rt.InputMethod.KEYBOARD then
            rt.SceneManager:set_is_cursor_visible(self._camera_override_active)

            if self._camera_override_active then
                love.mouse.setX(0.5 * love.graphics.getWidth())
                love.mouse.setY(0.5 * love.graphics.getHeight())
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
        return
    end

    -- regular camera behavior
    local top = self._camera_modes[1]
    local px, py = self._player:get_position()

    local is_frozen = self._camera_modes[ow.CameraMode.FREEZE] > 0
    local has_cutscene = self._camera_modes[ow.CameraMode.CUTSCENE] > 0
    local has_bounded = self._camera_modes[ow.CameraMode.BOUNDED] > 0
    local has_unbounded = self._camera_modes[ow.CameraMode.UNBOUNDED] > 0

    if is_frozen then
        camera:set_is_enabled(false)
        return
    else
        camera:set_is_enabled(true)
    end

    if has_cutscene then
        -- noop, controlled externally
        return
    elseif has_bounded then
        -- scale and bounds controlled externaly
        camera:set_apply_bounds(true)
        camera:move_to(px, py)
    elseif has_unbounded then
        -- only scale controlled externally
        camera:set_apply_bounds(false)
        camera:move_to(px, py)
    else
        -- nothing controlled externally, follow player
        camera:set_apply_bounds(false)
        camera:scale_to(1)
        camera:move_to(px, py)
    end
end

--- @brief
function ow.OverworldScene:set_player_is_visible(b)
    self._player_is_visible = b
end