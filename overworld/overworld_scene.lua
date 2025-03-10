require "common.scene"

require "overworld.stage"
require "overworld.camera"
require "physics.physics"

rt.settings.overworld.overworld_scene = {
    camera_translation_velocity = 600, -- px / s,
    camera_scale_velocity = 0.75, -- % / s
    camera_rotate_velocity = 2 * math.pi / 10 -- rad / s
}

--- @class
ow.OverworldScene = meta.class("OverworldScene", rt.Scene)

--- @brief
function ow.OverworldScene:instantiate()
    meta.install(self, {
        _camera = ow.Camera(),
        _current_stage_id = nil,
        _stage = nil,
        _player = ow.Player(),
        _input = rt.InputSubscriber(),

        _camera_translation_velocity_x = 0,
        _camera_translation_velocity_y = 0,
        _camera_scale_velocity = 0,
        _camera_rotate_velocity = 0,
        _camera_position_offset_x = 0,
        _camera_position_offset_y = 0,
        _player_is_focused = true
    })

    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button(which, true)
    end)

    self._input:signal_connect("released", function(_, which)
        self:_handle_button(which, false)
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        self:_handle_joystick(x, y, true)
    end)

    self._input:signal_connect("right_joystick_moved", function(_, x, y)
        self:_handle_joystick(x, y, false)
    end)

    self._input:signal_connect("left_trigger_moved", function(_, value)
        self:_handle_trigger(value, true)
    end)

    self._input:signal_connect("right_trigger_moved", function(_, value)
        self:_handle_trigger(value, false)
    end)

    -- raw inputs

    self._input:signal_connect("controller_button_pressed", function(_, which)
        if which == "leftstick" or which == "rightstick" then
            self._camera:reset()
            self._camera:set_position(self._player:get_position())
        end
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
    end)
end

--- @brief
function ow.OverworldScene:enter(stage_id)
    if stage_id ~= self._stage_id then
        self._current_stage_id = stage_id
        self._stage = ow.Stage(stage_id)
        self._player:move_to_stage(self._stage)
        self._camera:set_bounds(self._stage:get_camera_bounds())
        self._player_is_focused = true
    end
end

--- @brief
function ow.OverworldScene:exit()
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)

end

--- @brief
function ow.OverworldScene:draw()
    love.graphics.setColor(rt.color_unpack(rt.Palette.BLACK))
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.setColor(1, 1, 1, 1)

    self._camera:bind()
    self._stage:draw()
    self._player:draw()
    self._camera:unbind()
end

--- @brief
function ow.OverworldScene:update(delta)
    self._camera:update(delta)
    self._stage:update(delta)
    self._player:update(delta)

    if self._player_is_focused == false and math.magnitude(self._player:get_velocity()) > 0 then
        self._player_is_focused = true
    end

    if self._player_is_focused then
        local x, y = self._player:get_position()
        self._camera:move_to(x + self._camera_position_offset_x, y + self._camera_position_offset_y)
        if self._camera:get_bounds():contains(x, y) == false then
            self._camera:set_apply_bounds(false)
        else
            self._camera:set_apply_bounds(true)
        end
    else
        local cx, cy = self._camera:get_position()
        cx = cx + self._camera_translation_velocity_x * delta
        cy = cy + self._camera_translation_velocity_y * delta
        self._camera:set_position(cx, cy)
    end

    self._camera:set_scale(self._camera:get_scale() + self._camera_scale_velocity * delta)
    self._camera:set_rotation(self._camera:get_rotation() + self._camera_rotate_velocity * delta)
    self._player:set_facing_angle(self._camera:get_rotation())
end

local _l_pressed = false
local _r_pressed = false

--- @brief
function ow.OverworldScene:_handle_button(which, pressed_or_released)
    do
        if which == rt.InputButton.L then
            _l_pressed = pressed_or_released
        elseif which == rt.InputButton.R then
            _r_pressed = pressed_or_released
        end

        if _l_pressed == _r_pressed then -- both or neither
            self._camera_rotate_velocity = 0
        else

            local max_velocity = rt.settings.overworld.overworld_scene.camera_rotate_velocity
            if _l_pressed then
                self._camera_rotate_velocity = self._camera_rotate_velocity - 1 * max_velocity
            elseif _r_pressed then
                self._camera_rotate_velocity = self._camera_rotate_velocity + 1 * max_velocity
            end
        end
    end
end

--- @brief
function ow.OverworldScene:_handle_joystick(x, y, left_or_right)
    if left_or_right == false then
        if math.magnitude(self._player:get_velocity()) == 0 then
            -- when standing still, allow scrolling
            if math.magnitude(x, y) > 0 then
                local max_velocity = rt.settings.overworld.overworld_scene.camera_translation_velocity
                self._camera_translation_velocity_x = x * max_velocity
                self._camera_translation_velocity_y = y * max_velocity
            else
                self._camera_translation_velocity_x = 0
                self._camera_translation_velocity_y = 0
            end
            self._player_is_focused = false
            self._camera_position_offset_x = 0
            self._camera_position_offset_y = 0
        else
            -- when moving, allow look-ahead but keep player on screen
            local radius = 0.5 * math.min(love.graphics.getWidth(), love.graphics.getHeight())
            self._camera_position_offset_x = x * radius
            self._camera_position_offset_y = y * radius
        end
    end
end

--- @brief
function ow.OverworldScene:_handle_trigger(value, left_or_right)
    local max_velocity = rt.settings.overworld.overworld_scene.camera_scale_velocity
    if left_or_right == false then
        self._camera_scale_velocity = value * max_velocity
    else
        self._camera_scale_velocity = -value * max_velocity
    end
end