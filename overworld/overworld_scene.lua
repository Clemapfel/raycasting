require "common.scene"
require "common.mesh"
require "common.background"
require "common.control_indicator"
require "overworld.stage"
require "common.camera"
require "common.player"
require "overworld.coin_effect"
require "overworld.results_screen"
require "physics.physics"
require "menu.pause_menu"
require "common.bloom"
require "common.fade"
require "overworld.stage_title_card"

do
    local bloom = 0.2
    rt.settings.overworld_scene = {
        camera_translation_velocity = 400, -- px / s,
        camera_scale_velocity = 0.05, -- % / s
        camera_rotate_velocity = 2 * math.pi / 10, -- rad / s
        camera_pan_width_factor = 0.15,
        camera_freeze_duration = 1,
        results_screen_fraction = 0.5,

        bloom_blur_strength = 1.2, -- > 0
        bloom_composite_strength = bloom, -- [0, 1]
        title_card_min_duration = 3, -- seconds

        idle_control_indicator_popup_threshold = 5
    }
end

--- @class
ow.OverworldScene = meta.class("OverworldScene", rt.Scene)

ow.CameraMode = meta.enum("CameraMode", {
    AUTO = "AUTO",
    MANUAL = "MANUAL"
})

local _bloom_shader = nil
local _skip_fade = true

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

        _stage_duration_start_time = math.huge,

        _camera_translation_velocity_x = 0,
        _camera_translation_velocity_y = 0,
        _camera_scale_velocity = 0,
        _camera_rotate_velocity = 0,
        _camera_position_offset_x = 0,
        _camera_position_offset_y = 0,
        _player_is_focused = true,

        _stage_mapping = {}, -- cf _notify_stage_transition

        _camera_pan_area_width = 0,
        _camera_pan_gradient_top = nil,
        _camera_pan_up_speed = 0,
        _camera_pan_gradient_right = nil,
        _camera_pan_right_speed = 0,
        _camera_pan_gradient_bottom = nil,
        _camera_pan_down_speed = 0,
        _camera_pan_gradient_left = nil,
        _camera_pan_left_speed = 0,

        _cursor_visible = false,
        _cursor_active = false,
        _camera_freeze_elapsed = 0, -- sic, freeze at initialization

        _visible_bodies = {}, -- Set<b2.Body>
        _background = rt.Background("grid"),

        _pause_menu = mn.PauseMenu(self),
        _pause_menu_active = false,

        _bloom = nil, -- rt.Blur
        _fade = rt.Fade(1),
        _fade_active = false,

        _title_card = ow.StageTitleCard("1 - 3: Not a Tutorial"),
        _title_card_active = false,
        _title_card_elapsed = 0,

        _player_canvas = nil
    })

    local translation = rt.Translation.overworld_scene
    self._non_bubble_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.LEFT_RIGHT, translation.control_indicator_move,
        rt.ControlIndicatorButton.JUMP, translation.control_indicator_jump,
        rt.ControlIndicatorButton.SPRINT, translation.control_indicator_sprint,
        rt.ControlIndicatorButton.DOWN, translation.control_indicator_down
    )
    self._non_bubble_control_indicator:set_has_frame(true)

    self._bubble_control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.ALL_DIRECTIONS, translation.control_indicator_bubble_move
    )
    self._bubble_control_indicator:set_has_frame(true)

    self._control_indicator_motion = rt.SmoothedMotion1D(0, 1) -- opacity
    self._control_indicator_visible = false

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.PAUSE then
            if not self._pause_menu_active then
                self:pause()
            end
        end
    end)

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        -- debug reload
        if which == "^" then
            self:reload()
            self:unpause()
        elseif which == "h" then
        elseif which == "j" then
            --self._bloom:set_bloom_strength(self._bloom:get_bloom_strength() - 1 / 10)
            --rt.settings.overworld_scene.bloom_composite_strength = rt.settings.overworld_scene.bloom_composite_strength - 0.01
        elseif which == "k" then
            --self._bloom:set_bloom_strength(self._bloom:get_bloom_strength() + 1 / 10)
            --rt.settings.overworld_scene.bloom_composite_strength =  rt.settings.overworld_scene.bloom_composite_strength + 0.01
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_handle_joystick(x, y, true)
        self._cursor_active = false
    end)

    self._input:signal_connect("right_joystick_moved", function(_, x, y)
        self:_handle_joystick(x, y, false)
        self._cursor_active = false
    end)

    self._input:signal_connect("left_trigger_moved", function(_, value)
        self:_handle_trigger(value, true)
        self._cursor_active = false
    end)

    self._input:signal_connect("right_trigger_moved", function(_, value)
        self:_handle_trigger(value, false)
        self._cursor_active = false
    end)

    -- raw inputs

    self._input:signal_connect("controller_button_pressed", function(_, which)
        if which == "leftstick" or which == "rightstick" and self._camera_mode ~= ow.CameraMode.MANUAL then
            self._camera:reset()
            self._camera:set_position(self._player:get_position())
        end
        self._cursor_active = false
    end)

    local _up_pressed = false
    local _right_pressed = false
    local _down_pressed = false
    local _left_pressed = false

    local function _update_velocity()
        local max_velocity = rt.settings.overworld_scene.camera_translation_velocity
        if _left_pressed == _right_pressed then
            self._camera_translation_velocity_x = 0
        elseif _left_pressed then
            self._camera_translation_velocity_x = -max_velocity
            self._player_is_focused = false
        elseif _right_pressed then
            self._camera_translation_velocity_x = max_velocity
            self._player_is_focused = false
        end

        if _up_pressed == _down_pressed then
            self._camera_translation_velocity_y = 0
        elseif _up_pressed then
            self._camera_translation_velocity_y = -max_velocity
            self._player_is_focused = false
        elseif _down_pressed then
            self._camera_translation_velocity_y = max_velocity
            self._player_is_focused = false
        end
    end

    function self:_set_cursor_visible(b)
        self._cursor_visible = b
        if b == false then
            self._camera_pan_up_speed = 0
            self._camera_pan_right_speed = 0
            self._camera_pan_down_speed = 0
            self._camera_pan_left_speed = 0
        end
    end

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        local max_velocity = rt.settings.overworld_scene.camera_translation_velocity
        if which == "up" then
            _up_pressed = true
        elseif which == "right" then
            _right_pressed = true
        elseif which == "down" then
            _down_pressed = true
        elseif which == "left" then
            _left_pressed = true
        end

        _update_velocity()
        self._cursor_active = false
        self._camera_pan_up_speed = 0
        self._camera_pan_right_speed = 0
        self._camera_pan_down_speed = 0
        self._camera_pan_left_speed = 0
    end)

    self._input:signal_connect("keyboard_key_released", function(_, which)
        if which == "up" then
            _up_pressed = false
        elseif which == "right" then
            _right_pressed = false
        elseif which == "down" then
            _down_pressed = false
        elseif which == "left" then
            _left_pressed = false
        end

        _update_velocity()
        self._cursor_active = false
    end)

    self._input:signal_connect("mouse_moved", function(_, x, y)
        self._cursor_active = true
        if self._input:get_input_method() == rt.InputMethod.KEYBOARD then
            local w = self._camera_pan_area_width
            self._camera_pan_up_speed = math.max((w - y) / w, 0)
            self._camera_pan_right_speed = math.max((x - (self._bounds.x + self._bounds.width - w)) / w, 0)
            self._camera_pan_down_speed = math.max((y - (self._bounds.y + self._bounds.height - w)) / w, 0)
            self._camera_pan_left_speed = math.max((w - x) / w, 0)
            self:_set_cursor_visible(true)
        end
    end)

    self._input:signal_connect("input_method_changed", function(_, which)
        if which ~= rt.InputMethod.KEYBOARD then
            self:_set_cursor_visible(false)
            self._cursor_active = false
            -- only hide, reveal could mess up out-of-window disable
        end
    end)

    self._input:signal_connect("mouse_entered_screen", function(_)
    end)

    self._input:signal_connect("mouse_left_screen", function(_)
        self:_set_cursor_visible(false)
    end)

    self._input:signal_connect("mouse_wheel_moved", function(_, dx, dy)
        if self._camera_mode ~= ow.CameraMode.MANUAL and love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            local current = self._camera:get_scale()
            current = current + dy * rt.settings.overworld_scene.camera_scale_velocity
            self._camera:set_scale(math.clamp(current, 1 / 3, 3))
        end
    end)

    self._background:realize()
    self._pause_menu:realize()
    self._title_card:realize()
    self._non_bubble_control_indicator:realize()
    self._bubble_control_indicator:realize()

    self._player_canvas_scale = 2
    local radius = rt.settings.player.radius * rt.settings.player.bubble_radius_factor * 2.5
    self._player_canvas_scale = rt.settings.player_body.canvas_scale
    self._player_canvas = rt.RenderTexture(2 * radius * self._player_canvas_scale, 2 * radius * self._player_canvas_scale)
    self._player_canvas_needs_update = true
end

local _blocked = 0

local _cursor = nil

--- @brief
function ow.OverworldScene:enter(stage_id, show_title_card)
    meta.assert(stage_id, "String")
    rt.SceneManager:set_use_fixed_timestep(true)
    self:set_stage(stage_id, show_title_card)

    if _skip_fade ~= true then
        self._input:deactivate()
        self._fade_active = false
        self._fade:start(false, true)
        self._title_card:fade_in()
        self._title_card_elapsed = 0

        self._player._input:deactivate()
        self._stage:signal_connect("done", function()
            self._queue_fade_out = true
            return meta.DISCONNECT_SIGNAL
        end)
    else
        self._input:activate()
        self._fade_active = false
        self._title_card_elapsed = math.huge
    end

    love.mouse.setVisible(false)
    love.mouse.setGrabbed(false)
    love.mouse.setCursor(_cursor)

    if self._pause_menu_active then
        self._pause_menu:present()
    end
end

--- @brief
function ow.OverworldScene:exit()
    love.mouse.setGrabbed(false)
    love.mouse.setCursor(nil)

    if self._pause_menu_active then
        self._pause_menu:close()
    end

    self._input:deactivate()
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)
    local factor = rt.settings.overworld_scene.camera_pan_width_factor
    local gradient_w = factor * math.min(width, height)
    local gradient_h = gradient_w
    local r, g, b, a = 1, 1, 1, 0.2
    self._camera_pan_area_width = gradient_w

    local m = rt.settings.margin_unit
    for indicator in range(self._non_bubble_control_indicator, self._bubble_control_indicator) do
        local control_w, control_h = indicator:measure()
        indicator:reformat(
            x + 0.5 * width - 0.5 * control_w - m,
            y + height - control_h - m,
            control_w, control_h
        )
    end

    if rt.GameState:get_is_bloom_enabled() then
        self._bloom = rt.Bloom(width, height)
        self._bloom:set_bloom_strength(rt.settings.overworld_scene.bloom_blur_strength)
        if self._stage ~= nil then
            self._stage:get_blood_splatter():set_bloom_factor(
                rt.settings.overworld_scene.bloom_composite_strength +
                rt.settings.overworld.normal_map.segment_light_intensity
            )
        end
    end

    self._pan_gradient_top = rt.Mesh({
        { x, y,                       0, 0, r, g, b, a },
        { x + width, y,               0, 0, r, g, b, a },
        { x + width, y + gradient_h,  0, 0, r, g, b, 0 },
        { x, y + gradient_h,          0, 0, r, g, b, 0 }
    })

    self._pan_gradient_bottom = rt.Mesh({
        { x, y + height - gradient_h,         0, 0, r, g, b, 0 },
        { x + width, y + height - gradient_h, 0, 0, r, g, b, 0 },
        { x + width, y + height,              0, 0, r, g, b, a },
        { x, y + height,                      0, 0, r, g, b, a }
    })

    self._pan_gradient_left = rt.Mesh({
        { x, y,                       0, 0, r, g, b, a },
        { x + gradient_w, y,          0, 0, r, g, b, 0 },
        { x + gradient_w, y + height, 0, 0, r, g, b, 0 },
        { x, y + height,              0, 0, r, g, b, a }
    })

    self._pan_gradient_right = rt.Mesh({
        { x + width - gradient_w, y,          0, 0, r, g, b, 0 },
        { x + width, y,                       0, 0, r, g, b, a },
        { x + width, y + height,              0, 0, r, g, b, a },
        { x + width - gradient_w, y + height, 0, 0, r, g, b, 0 }
    })

    self._background:reformat(0, 0, width, height)
    self._pause_menu:reformat(0, 0, width, height)
    self._title_card:reformat(0, 0, width, height)
end

--- @brief
function ow.OverworldScene:set_stage(stage_id, entrance_i)
    self._stage_id = stage_id
    self._stage = ow.Stage(self, stage_id)

    self._player:move_to_stage(self._stage)
    self._player_is_focused = true
    self._stage_duration_start_time = love.timer.getTime()

    return self._stage
end

--- @brief
function ow.OverworldScene:get_run_duration()
    -- round to nearest multiple of physics time step, frame-rate independent timing
    local current = love.timer.getTime()
    local min_step = self._stage:get_physics_world():get_timestep()
    local duration = (current - self._stage_duration_start_time)
    local rounded_duration = math.floor((duration / min_step) + 0.5) * min_step
    return duration, self._stage:get_physics_world():get_n_updates()
end

--- @brief
function ow.OverworldScene:set_camera_bounds(bounds)
    self._camera:set_bounds(bounds)
end

--- @brief
function ow.OverworldScene:_get_stage_entry(stage_id)
    local out = self._stage_mapping[stage_id]
    if out == nil then
        out = {
            stage = nil,
            spawn_x = nil,
            spawn_y = nil,
            exits = {} -- Table<StageID, { x : Number, y : Number, object : ow.StageTransition }>
        }
        self._stage_mapping[stage_id] = out

        local stage = ow.Stage(self, stage_id)
        out.stage = stage
    end
    return out
end

--- @brief [internal] builds world map
function ow.OverworldScene:_notify_stage_transition_added(
    object,
    from_stage_id, from_entrance_i,
    to_stage_id, to_entrance_i
)
    meta.assert(object, ow.StageTransition,
        from_stage_id, "String",
        from_entrance_i, "Number",
        to_stage_id, "String",
        to_entrance_i, "Number"
    )

    -- pre-load configs now
    if ow.Stage._config_atlas[from_stage_id] == nil then
        ow.Stage._config_atlas[from_stage_id] = ow.StageConfig(from_stage_id)
    end

    if ow.Stage._config_atlas[to_stage_id] == nil then
        ow.Stage._config_atlas[to_stage_id] = ow.StageConfig(to_stage_id)
    end

    local to_entry = self:_get_stage_entry(to_stage_id)
    local x, y = object:get_spawn_position()

    local exits = to_entry.exits[from_stage_id]
    if exits == nil then
        exits = {}
        to_entry.exits[from_stage_id] = exits
    end

    exits[from_entrance_i] = {
        x = x,
        y = y,
        object = object
    }
end

local _white_r, _white_g, _white_b = rt.color_unpack(rt.Palette.WHITE)
local _black_r, _black_g, _black_b = rt.color_unpack(rt.Palette.BLACK)

function ow.OverworldScene:draw()
    if self._stage == nil then return end

    if self._bloom == nil and rt.GameState:get_is_bloom_enabled() then
        local _, _, width, height = self:get_bounds():unpack()
        self._bloom = rt.Bloom(width, height,
            rt.settings.overworld_scene.bloom_msaa,
            rt.settings.overworld_scene.bloom_texture_format
        )
        self._bloom:set_bloom_strength(rt.settings.overworld_scene.bloom_blur_strength)
        if self._stage ~= nil then
            self._stage:get_blood_splatter():set_bloom_factor(
                rt.settings.overworld_scene.bloom_composite_strength +
                rt.settings.overworld.normal_map.segment_light_intensity
            )
        end
    end

    love.graphics.push()
    love.graphics.origin()
    love.graphics.clear(1, 0, 1, 1)
    if not _skip_fade == true and self._fade:get_is_active() or self._fade:get_is_visible() then
        self._background:draw()

        self._camera:bind()
        self._stage:draw_below_player()
        self._stage:draw_above_player()
        self._camera:unbind()

        self._fade:draw()

        self._camera:bind()
        self._player:draw_body()
        self._player:draw_core()
        self._camera:unbind()

        self._title_card:draw()

        if rt.GameState:get_is_bloom_enabled() == true then
            love.graphics.push()
            self._bloom:bind()
            love.graphics.clear(0, 0, 0, 0)
            self._camera:bind()
            self._player:draw_bloom()
            self._title_card:draw()
            self._camera:unbind()
            self._bloom:unbind()
            love.graphics.pop()

            self._bloom:composite(rt.settings.overworld_scene.bloom_composite_strength)
        end
    else -- not fading
        self._background:draw()

        self._camera:bind()
        self._stage:draw_below_player()
        self._player:draw_body()
        self._player:draw_core()
        self._stage:draw_above_player()
        self._camera:unbind()

        if rt.GameState:get_is_bloom_enabled() == true then
            love.graphics.push()
            self._bloom:bind()
            love.graphics.clear(0, 0, 0, 0)
            self._camera:bind()
            self._player:draw_bloom()
            self._stage:draw_bloom()
            self._camera:unbind()
            self._bloom:unbind()
            love.graphics.pop()

            self._bloom:composite(rt.settings.overworld_scene.bloom_composite_strength)
        end
    end

    if _skip_fade ~= true then
        self._title_card:draw()
    end

    love.graphics.pop()

    if not self._pause_menu_active and self._cursor_visible and self._cursor_active then
        love.graphics.setColor(1, 1, 1, self._camera_pan_up_speed)
        love.graphics.draw(self._pan_gradient_top._native)

        love.graphics.setColor(1, 1, 1, self._camera_pan_right_speed)
        love.graphics.draw(self._pan_gradient_right._native)

        love.graphics.setColor(1, 1, 1, self._camera_pan_down_speed)
        love.graphics.draw(self._pan_gradient_bottom._native)

        love.graphics.setColor(1, 1, 1, self._camera_pan_left_speed)
        love.graphics.draw(self._pan_gradient_left._native)

        local x, y = love.mouse.getPosition()
        local scale = love.window.getDPIScale()
        love.graphics.setLineStyle("smooth")

        love.graphics.setColor(_white_r, _white_g, _white_b, 0.7)
        love.graphics.circle("fill", x, y, 6 * scale)

        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(_white_r, _white_g, _white_b, 1)
        love.graphics.circle("line", x, y, 6 * scale - 1)

        love.graphics.setLineWidth(1)
        love.graphics.setColor(_black_r, _black_g, _black_b, 1)
        love.graphics.circle("line", x, y, 6 * scale)
    end

    if self._pause_menu_active then
        self._pause_menu:draw()
    end

    local opacity = self._control_indicator_motion:get_value()
    if opacity > 0 then
        if self._player:get_is_bubble() then
            self._bubble_control_indicator:set_opacity(opacity)
            self._bubble_control_indicator:draw()
        else
            self._non_bubble_control_indicator:set_opacity(opacity)
            self._non_bubble_control_indicator:draw()
        end
    end

    if rt.GameState:get_draw_debug_information() then
        self:_draw_debug_information()
    end
end

function ow.OverworldScene:_draw_debug_information()
    local player = self._player
    local flow_percentage = player:get_flow()
    local flow_velocity = player:get_flow_velocity()

    local velocity_fraction

    if player:get_is_bubble() then
        local bubble_target = rt.settings.player.bubble_target_velocity
        local current = math.magnitude(player:get_velocity())
        velocity_fraction = current / bubble_target
    else
        local x_velocity = select(1, player:get_velocity())
        if player:get_is_grounded() then
            velocity_fraction = x_velocity / rt.settings.player.ground_target_velocity_x
        else
            velocity_fraction = x_velocity / rt.settings.player.air_target_velocity_x
        end
    end

    flow_percentage = tostring(math.round(flow_percentage * 100) / 100)
    flow_velocity = ternary(flow_velocity >= 0, "+", "-")
    velocity_fraction = tostring(math.round(velocity_fraction * 10) / 10 * 100)

    while #velocity_fraction < 3 do
        velocity_fraction = "0" .. velocity_fraction
    end

    local pressed, unpressed = "1", "0"
    local up = ternary(self._player._up_button_is_down, pressed, unpressed)
    local right = ternary(self._player._right_button_is_down, pressed, unpressed)
    local down = ternary(self._player._down_button_is_down, pressed, unpressed)
    local left = ternary(self._player._left_button_is_down, pressed, unpressed)
    local a = ternary(self._player._sprint_button_is_down, pressed, unpressed)
    local b = ternary(self._player._jump_button_is_down, pressed, unpressed)

    local duration, n_steps = self:get_run_duration()
    local time = string.format_time(duration) .. " (" .. n_steps .. " frames)"

    local to_concat = {
        up .. right .. down .. left .. " " .. a .. b,
        "flow : " .. flow_percentage .. "% (" .. flow_velocity .. ")",
        time,
        --"speed : " .. velocity_fraction .. "%",
    }

    love.graphics.setFont(rt.settings.font.love_default)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(table.concat(to_concat, " | "), 5, 5, math.huge)
end


local _last_x, _last_y

--- @brief
function ow.OverworldScene:update(delta)
    if _skip_fade ~= true then
        if self._queue_fade_out and self._title_card_elapsed >= rt.settings.overworld_scene.title_card_min_duration then
            self._input:activate()
            self._player._input:activate()
            self._fade_active = true
            self._title_card:fade_out()
            self._queue_fade_out = nil
        end

        if self._fade_active then
            self._fade:update(delta)
        end

        self._title_card:update(delta)
        self._title_card_elapsed = self._title_card_elapsed + delta
    end

    local idle = self._player:get_idle_duration() > rt.settings.overworld_scene.idle_control_indicator_popup_threshold
    if self._control_indicator_visible == true and idle == false then
        self._control_indicator_visible = false
        self._control_indicator_motion:set_target_value(0)
    elseif self._control_indicator_visible == false and idle == true then
        self._control_indicator_visible = true
        self._control_indicator_motion:set_target_value(1)
    end

    self._control_indicator_motion:update(delta)

    if self._pause_menu_active then
        self._pause_menu:update(delta)
        return
    end

    _blocked = _blocked - 1
    if _blocked >= 0 then return end
    if self._stage == nil then return end

    local x, y = self._camera:world_xy_to_screen_xy(self._player:get_physics_body():get_predicted_position())
    self._player:update(delta)
    self._camera:update(delta)
    self._stage:update(delta)
    self._background:update_player_position(x, y, self._player:get_flow())
    self._background:_notify_camera_changed(self._camera)
    self._background:update(delta)

    -- player canvas
    do
        love.graphics.push()
        love.graphics.origin()
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

    -- mouse-based scrolling
    if self._cursor_visible == true then
        local max_velocity = rt.settings.overworld_scene.camera_translation_velocity
        self._camera_translation_velocity_x = (-1 * self._camera_pan_left_speed + 1 * self._camera_pan_right_speed) * max_velocity
        self._camera_translation_velocity_y = (-1 * self._camera_pan_up_speed + 1 * self._camera_pan_down_speed) * max_velocity

        if math.magnitude(self._camera_translation_velocity_x, self._camera_translation_velocity_y) > 0 then
            self._player_is_focused = false
            self._camera_freeze_elapsed = self._camera_freeze_elapsed + delta
        end
    end

    -- measure actual player velocity, if moving, disable manual camera
    local px, py = self._player:get_predicted_position()
    if _last_x == nil then
        _last_x, _last_y = px, py
    end

    local player_velocity = math.magnitude(px - _last_x, py - _last_y)
    if player_velocity > 1 then
        self._player_is_focused = true
        self._camera_freeze_elapsed = 0
    end
    _last_x, _last_y = px, py

    if self._player_is_focused and self._camera_mode ~= ow.CameraMode.MANUAL then
        local x, y = self._player:get_position()
        self._camera:move_to(x + self._camera_position_offset_x, y + self._camera_position_offset_y)
        if self._camera:get_bounds():contains(x, y) == false then
            self._camera:set_apply_bounds(false) -- unhook from bounds if player leaves them
        else
            self._camera:set_apply_bounds(true)
        end

        if self._camera:get_apply_bounds() then
            -- freeze player until camera catches up
            local pos_x, pos_y = self._player:get_position()
            local top_left_x, top_left_y = self._camera:screen_xy_to_world_xy(0, 0)
            local bottom_right_x, bottom_right_y = self._camera:screen_xy_to_world_xy(love.graphics.getWidth(), love.graphics.getHeight())

            local buffer = -1 * self._player:get_radius() * 2 -- to prevent softlock at edge of screen
            top_left_x = top_left_x + buffer
            top_left_y = top_left_y + buffer
            bottom_right_x = bottom_right_x - buffer
            bottom_right_y = bottom_right_y - buffer

            local on_screen = x > top_left_x and x < bottom_right_x and y > top_left_y and y < bottom_right_y
        end
    elseif self._camera_freeze_elapsed > rt.settings.overworld_scene.camera_freeze_duration and love.window.hasMouseFocus() then
        local cx, cy = self._camera:get_position()
        cx = cx + self._camera_translation_velocity_x * delta
        cy = cy + self._camera_translation_velocity_y * delta
        self._camera:set_position(cx, cy)
    end

    local max_velocity = rt.settings.overworld_scene.camera_scale_velocity
    if love.keyboard.isDown("m") then
        self._camera_scale_velocity = 1 * max_velocity * 5
    elseif love.keyboard.isDown("n") then
        self._camera_scale_velocity = -1 * max_velocity * 5
    else
        if self._input:get_input_method() == rt.InputMethod.KEYBOARD then
            self._camera_scale_velocity = 0
        end
    end

    do
        local top_left_x, top_left_y = self._camera:screen_xy_to_world_xy(0, 0)
        local bottom_left_x, bottom_left_y = self._camera:screen_xy_to_world_xy(love.graphics.getDimensions())
        local visible = {}
        local light_sources = {}
        self._stage:get_physics_world():get_native():queryShapesInArea(top_left_x, top_left_y, bottom_left_x, bottom_left_y, function(shape)
            local body = shape:getBody():getUserData()
            visible[body] = true

            if body ~= nil and body:has_tag("light_source") then
                table.insert(light_sources, body)
            end
            return true
        end)
        self._visible_bodies = visible
        self._light_sources = light_sources
    end
end

--- @brief
function ow.OverworldScene:_handle_joystick(x, y, left_or_right)
    if left_or_right == false then
        -- when moving, allow look-ahead but keep player on screen
        local radius = 0.15 * math.min(love.graphics.getWidth(), love.graphics.getHeight())
        self._camera_position_offset_x = x * radius
        self._camera_position_offset_y = y * radius
    end
end

--- @brief
function ow.OverworldScene:_handle_trigger(value, left_or_right)
    local max_velocity = rt.settings.overworld_scene.camera_scale_velocity
    if left_or_right == false then
        self._camera_scale_velocity = value * max_velocity * 5
    else
        self._camera_scale_velocity = -value * max_velocity * 5
    end
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
function ow.OverworldScene:set_camera_mode(mode)
    self._camera_mode = mode
end

--- @brief
function ow.OverworldScene:reload()
    if self._stage ~= nil then self._stage:destroy() end
    local before = self._stage_id
    self._stage_id = nil
    self._stage = nil
    self._stage_mapping = {}

    ow.Stage._config_atlas = {}
    ow.StageConfig._tileset_atlas = {}
    rt.Sprite._path_to_spritesheet = {}

    self._player:move_to_stage(nil)
    self:set_stage(before)
end

--- @brief
function ow.OverworldScene:respawn()
    self._stage:get_active_checkpoint():spawn()
    self._stage:reset_coins()
    self._camera:set_position(self._player:get_position())
end

--- @brief
function ow.OverworldScene:get_current_stage()
    return self._stage
end

--- @brief
function ow.OverworldScene:get_is_body_visible(body)
    return self._visible_bodies[body] == true
end

--- @brief
function ow.OverworldScene:get_point_light_sources()
    local positions = {}
    local colors = {}
    for body in values(self._light_sources) do
        local cx, cy = body:get_center_of_mass()
        table.insert(positions, { cx, cy })

        local class = body:get_user_data()
        if class ~= nil and class.get_color then
            local color = class:get_color()
            if not meta.isa(color, rt.RGBA) then
                rt.error("In ow.OverworldScene: object `" .. meta.typeof(class) .. "` has a get_color function that does not return an object of type `rt.RGBA`")
            end
            table.insert(colors, { class:get_color():unpack() })
        end
    end

    return positions, colors
end

--- @brief
function ow.OverworldScene:get_segment_light_sources()
    if self._stage == nil then return {} end
    local segments, colors = self._stage:get_blood_splatter():get_visible_segments(self._camera:get_world_bounds())

    for body in keys(self._visible_bodies) do
        if body:has_tag("segment_light_source") then
            local instance = body:get_user_data()
            assert(instance ~= nil, "In ow.OverworldScene:get_segment_light_sources: body has `segment_light_source` tag but userdata instance is not set")
            assert(instance.get_segment_light_sources, "In ow.OverworldScene:get_segment_light_sources: body has `segment_light_source` tag, but instance `" .. meta.typeof(instance) .. "` does not have `get_segment_light_sources` defined")
            local current_segments, current_colors = instance:get_segment_light_sources()

            for segment in values(current_segments) do
                table.insert(segments, segment)
            end

            for color in values(current_colors) do
                table.insert(colors, color)
            end
        end
    end

    return segments, colors
end

--- @brief
function ow.OverworldScene:get_is_cursor_visible()
    return (self._cursor_visible and self._cursor_active)
end

--- @brief
function ow.OverworldScene:pause()
    self._player:disable()
    self._pause_menu:present()
    self._pause_menu_active = true
end

--- @brief
function ow.OverworldScene:unpause()
    self._pause_menu_active = false
    self._pause_menu:close()
    self._player:enable()
end

--- @brief
function ow.OverworldScene:get_player_canvas()
    return self._player_canvas, self._player_canvas_scale, self._player_canvas_scale
end
