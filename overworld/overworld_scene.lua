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
        _player = nil,
        _input = rt.InputSubscriber(),

        _camera_translation_velocity_x = 0,
        _camera_translation_velocity_y = 0,
        _camera_scale_velocity = 0,
        _camera_rotate_velocity = 0,
        _camera_position_offset_x = 0,
        _camera_position_offset_y = 0,
        _player_is_focused = true,

        _stage_mapping = {} -- cf _notify_stage_transition
    })

    self._player = ow.Player(self)

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
    self:set_stage(stage_id)
end

--- @brief
function ow.OverworldScene:exit()
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)

end

--- @brief
function ow.OverworldScene:set_stage(stage_id, entrance_i)
    if entrance_i == nil then entrance_i = 1 end

    if stage_id ~= self._stage_id then
        local next_entry = self:_get_stage_entry(stage_id)
        local spawn_x, spawn_y = next_entry.spawn_x, next_entry.spawn_y
        if self._stage_id ~= nil then -- leaving current room
            local current_entry = self:_get_stage_entry(self._stage_id)
            local exit_entry = current_entry.exits[stage_id][entrance_i]
            if exit_entry ~= nil then
                spawn_x, spawn_y = exit_entry.x, exit_entry.y
            end
        end

        self._stage_id = stage_id
        self._stage = next_entry.stage

        self._player:move_to_stage(self._stage, spawn_x, spawn_y)
        self._camera:set_bounds(self._stage:get_camera_bounds())
        self._camera:set_position(self._player:get_position())
        self._player_is_focused = true
    end
end

--- @brief
function ow.OverworldScene:_get_stage_entry(stage_id)
    local out = self._stage_mapping[stage_id]
    if out == nil then
        out = {
            stage = nil,
            spawn_x = nil,
            spawn_y = nil,
            exits = {}
        }
        self._stage_mapping[stage_id] = out

        local stage = ow.Stage(self, stage_id)
        local x, y = stage:get_player_spawn()
        out.stage = stage
        out.spawn_x, out.spawn_y = x, y
    end
    return out
end

--- @brief [internal] builds world map
function ow.OverworldScene:_notify_stage_transition(from_id, to_id, entrance_i, spawn_x, spawn_y)
    meta.assert(from_id, "String", to_id, "String", entrance_i, "Number", spawn_x, "Number", spawn_y, "Number")

    -- pre-load configs
    if ow.Stage._config_atlas[from_id] == nil then
        ow.Stage._config_atlas[from_id] = ow.StageConfig(from_id)
    end

    if ow.Stage._config_atlas[to_id] == nil then
        ow.Stage._config_atlas[to_id] = ow.StageConfig(to_id)
    end

    local from_entry = self:_get_stage_entry(from_id)
    local to_entry = self:_get_stage_entry(to_id)

    from_entry.exits[to_id] = {
        [entrance_i] = { x = spawn_x, y = spawn_y }
    }
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
            self._player:set_is_disabled(not on_screen)
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