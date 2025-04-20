require "common.scene"
require "common.mesh"
require "common.background"
require "overworld.stage"
require "overworld.camera"
require "overworld.player"
require "overworld.coin_effect"
require "overworld.stage_hud"
require "physics.physics"

rt.settings.overworld.overworld_scene = {
    camera_translation_velocity = 400, -- px / s,
    camera_scale_velocity = 0.1, -- % / s
    camera_rotate_velocity = 2 * math.pi / 10, -- rad / s
    camera_pan_width_factor = 0.15
}

--- @class
ow.OverworldScene = meta.class("OverworldScene", rt.Scene)

ow.CameraMode = meta.enum("CameraMode", {
    AUTO = "AUTO",
    MANUAL = "MANUAL"
})

--- @brief
function ow.OverworldScene:instantiate()
    meta.install(self, {
        _camera = ow.Camera(),
        _current_stage_id = nil,
        _stage = nil,
        _player = nil,
        _input = rt.InputSubscriber(false),

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

        _background = rt.Background("grid"),

        _coin_effect = ow.CoinEffect(self),
        _player = ow.Player(self),
    })

    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        -- debug reload
        if which == "^" then
            self:reload()
            rt.SceneManager:unpause()
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
        local max_velocity = rt.settings.overworld.overworld_scene.camera_translation_velocity
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
        local max_velocity = rt.settings.overworld.overworld_scene.camera_translation_velocity
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
        if self._input:get_input_method() == rt.InputMethod.KEYBOARD and self._cursor_active then
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
        if self._camera_mode ~= ow.CameraMode.MANUAL then
            local current = self._camera:get_scale()
            current = current + dy * rt.settings.overworld.overworld_scene.camera_scale_velocity
            self._camera:set_scale(math.clamp(current, 1 / 3, 3))
        end
    end)

    self._background:realize()
end

local _cursor = nil

--- @brief
function ow.OverworldScene:enter(stage_id)
    self:set_stage(stage_id)

    love.mouse.setVisible(false)
    love.mouse.setGrabbed(false)
    love.mouse.setCursor(_cursor)
    self._input:activate()
end

--- @brief
function ow.OverworldScene:exit()
    love.mouse.setGrabbed(false)
    love.mouse.setCursor(nil)
    self._input:deactivate()
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)
    local factor = rt.settings.overworld.overworld_scene.camera_pan_width_factor
    local gradient_w = factor * math.min(width, height)
    local gradient_h = gradient_w
    local r, g, b, a = 1, 1, 1, 0.2
    self._camera_pan_area_width = gradient_w

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
    self._coin_effect:reformat(0, 0, width, height)
end

--- @brief
function ow.OverworldScene:set_stage(stage_id, entrance_i)
    if entrance_i == nil then entrance_i = 1 end

    if stage_id ~= self._stage_id then
        local next_entry = self:_get_stage_entry(stage_id)
        local spawn_x, spawn_y = next_entry.spawn_x, next_entry.spawn_y
        if self._stage_id ~= nil then -- leaving current room
            local current_entry = self:_get_stage_entry(self._stage_id)
            local exit = current_entry.exits[stage_id]
            if exit ~= nil then
                local entrance = exit[entrance_i]
                if entrance == nil then
                    rt.warning("In ow.OverworldScene.set_stage: stage `" .. stage_id .. "` has no entrance with id `" .. entrance_i .. "`")
                    debugger.break_here()
                    entrance = exit[1]
                else
                    spawn_x, spawn_y = entrance.x, entrance.y
                    entrance.object:set_is_disabled(true)
                end
            end
            -- else use default spawn
        end

        self._stage_id = stage_id
        self._stage = next_entry.stage

        self._player:move_to_stage(self._stage)
        self._camera:set_position(self._player:get_position())
        self._player_is_focused = true
    end

    return self._stage
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

--- @brief
function ow.OverworldScene:draw()
    self._background:draw()

    self._camera:bind()

    self._stage:draw_below_player()

    self._camera:unbind()
    self._coin_effect:draw()
    self._camera:bind()

    self._player:draw()
    self._stage:draw_above_player()

    self._camera:unbind()

    if self._cursor_visible and self._cursor_active and not self._player_is_focused then -- cursor in window
        love.graphics.setColor(1, 1, 1, self._camera_pan_up_speed)
        love.graphics.draw(self._pan_gradient_top._native)

        love.graphics.setColor(1, 1, 1, self._camera_pan_right_speed)
        love.graphics.draw(self._pan_gradient_right._native)

        love.graphics.setColor(1, 1, 1, self._camera_pan_down_speed)
        love.graphics.draw(self._pan_gradient_bottom._native)

        love.graphics.setColor(1, 1, 1, self._camera_pan_left_speed)
        love.graphics.draw(self._pan_gradient_left._native)
    end

    if self._cursor_visible and self._cursor_active then
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
end

--- @brief
function ow.OverworldScene:update(delta)

    self._background:update(delta)
    self._camera:update(delta)
    self._stage:update(delta)
    self._coin_effect:update(delta)
    self._player:update(delta)

    self._background:_notify_camera_changed(self._camera)

    -- mouse-based scrolling
    if self._cursor_visible == true then
        local max_velocity = rt.settings.overworld.overworld_scene.camera_translation_velocity
        self._camera_translation_velocity_x = (-1 * self._camera_pan_left_speed + 1 * self._camera_pan_right_speed) * max_velocity
        self._camera_translation_velocity_y = (-1 * self._camera_pan_up_speed + 1 * self._camera_pan_down_speed) * max_velocity

        if math.magnitude(self._camera_translation_velocity_x, self._camera_translation_velocity_y) > 0 then
            self._player_is_focused = false
        end
    end

    if self._player_is_focused == false and math.magnitude(self._player:get_velocity()) > 0 then
        self._player_is_focused = true
    end

    if self._player_is_focused and self._camera_mode ~= ow.CameraMode.MANUAL then
        local x, y = self._player:get_position()
        self._camera:move_to(x + self._camera_position_offset_x, y + self._camera_position_offset_y)
        if self._camera:get_bounds():contains(x, y) == false then
            --self._camera:set_apply_bounds(false)
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
    else
        if self._cursor_visible and self._camera_mode ~= ow.CameraMode.MANUAL then
            local cx, cy = self._camera:get_position()
            cx = cx + self._camera_translation_velocity_x * delta
            cy = cy + self._camera_translation_velocity_y * delta
            self._camera:set_position(cx, cy)
        end
    end

    local max_velocity = rt.settings.overworld.overworld_scene.camera_scale_velocity
    if love.keyboard.isDown("m") then
        self._camera_scale_velocity = 1 * max_velocity * 5
    elseif love.keyboard.isDown("n") then
        self._camera_scale_velocity = -1 * max_velocity * 5
    else
        if self._input:get_input_method() == rt.InputMethod.KEYBOARD then
            self._camera_scale_velocity = 0
        end
    end

    if self._camera_mode ~= ow.CameraMode.MANUAL then
        self._camera:set_scale(self._camera:get_scale() + self._camera_scale_velocity * delta)
    end
    --self._player:set_facing_angle(self._camera:get_rotation())
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
    local max_velocity = rt.settings.overworld.overworld_scene.camera_scale_velocity
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
    local before = self._stage_id
    self._stage_id = nil
    self._stage_mapping = {}
    self._stage = nil
    ow.Stage._config_atlas = {}
    ow.StageConfig._tileset_atlas = {}
    rt.Sprite._path_to_spritesheet = {}

    self._player = ow.Player(self)
    self:set_stage(before)
end

--- @brief
function ow.OverworldScene:respawn()
    self._stage:get_active_checkpoint():spawn()
    self._stage:reset_coins()
end

--- @brief
function ow.OverworldScene:get_current_stage()
    return self._stage
end