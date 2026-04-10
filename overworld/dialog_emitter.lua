require "common.smoothed_motion_1d"
require "overworld.dialog_box"

--- @class ow.DialogEmitter
ow.DialogEmitter = meta.class("DialogEmitter", rt.Widget)
meta.add_signal(ow.DialogEmitter, "start", "end")

local _HIDDEN = 1
local _REVEALED = 0

--- @brief
function ow.DialogEmitter:instantiate(scene, id, target)
    self._scene = scene

    self._target = target -- may be nil
    if target ~= nil and target.get_position == nil then
        rt.critical("In ow.DialogEmitter: using `", meta.typeof(target), "` as cutscene target, but that types does not have a `get_position` function defined")
    end

    self._is_active = false

    self._dialog_box = ow.DialogBox(id)
    self._dialog_box_motion = rt.SmoothedMotion1D(_HIDDEN)
    self._dialog_box_motion_max_offset = 0
    self._dialog_box_y = 0
    self._dialog_box_height = 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if self._is_active and self:_get_motion_is_done() then
            self._dialog_box:handle_button_pressed(which)
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if self._is_active and self:_get_motion_is_done() then
            self._dialog_box:handle_button_released(which)
        end
    end)

    self._dialog_box:signal_connect("control_state_changed", function(_, state)
        if state == ow.DialogBoxControlState.ADVANCE then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG_ADVANCE)
        elseif state == ow.DialogBoxControlState.EXIT then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG_EXIT)
        elseif state == ow.DialogBoxControlState.IDLE then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
        end
    end)

    self._dialog_box:signal_connect("speaker_changed", function(dialog_box, new_speaker, state)
        local camera = self._scene:get_camera()
        if new_speaker == rt.Translation.player_name then
            camera:move_to(self._scene:get_player():get_position())
        elseif self._target ~= nil and meta.is_function(self._target.get_position) then
            camera:move_to(self._target:get_position())
        end
    end)

    self._dialog_box:realize()
    self:reformat(self._scene:get_bounds():unpack())

    self._scene:signal_connect("resize", function(_, x, y, width, height)
        self:reformat(x, y, width, height)
    end)
end

--- @brief
function ow.DialogEmitter:_get_motion_is_done()
    return math.abs(self._dialog_box_motion:get_value() - self._dialog_box_motion:get_target_value()) < 1
end

--- @brief
function ow.DialogEmitter:present()
    if self._is_active == true then return end

    self._is_active = true
    self._dialog_box_motion:set_target_value(_REVEALED)
    self._scene:get_player():request_is_movement_disabled(self, true)

    self._dialog_box:reset()
    self._queue_dialog_box_start = true
    self._scene:push_camera_mode(ow.CameraMode.CUTSCENE)
end

--- @brief
function ow.DialogEmitter:close()
    self._is_active = false
    self._dialog_box_motion:set_target_value(_HIDDEN)
    self._scene:get_player():request_is_movement_disabled(self, false)
    self._scene:pop_camera_mode(ow.CameraMode.CUTSCENE)
end

--- @brief
function ow.DialogEmitter:reset()
    if self._is_active then self._dialog_box:signal_emit("done") end
    self._dialog_box:reset()
end

--- @brief
function ow.DialogEmitter:update(delta)
    self._dialog_box_motion:update(delta)

    if self:_get_motion_is_done() and self._queue_dialog_box_start == true then
        self._dialog_box:signal_connect("done", function(_)
            self:close()
            return meta.DISCONNECT_SIGNAL
        end)
        self._dialog_box:start()
        self._queue_dialog_box_start = nil
    end

    self._dialog_box:update(delta)
end

--- @brief
function ow.DialogEmitter:draw()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(0, self._dialog_box_motion:get_value() * self._dialog_box_motion_max_offset)
    self._dialog_box:draw()
    love.graphics.pop()
end

--- @brief
function ow.DialogEmitter:get_is_active()
    return self._is_active
end

--- @brief
function ow.DialogEmitter:size_allocate(x, y, width, height)
    local x_margin = 10 * rt.settings.margin_unit
    local y_margin = select(2, self._scene:get_control_indicator(ow.ControlIndicatorType.DIALOG_SELECT_OPTION):measure())
    y_margin = y_margin - rt.settings.margin_unit

    local dialog_box_y = y + y_margin
    local dialog_box_h = height - 2 * y_margin
    self._dialog_box:reformat(
        x + x_margin,
        dialog_box_y,
        width - 2 * x_margin,
        dialog_box_h
    )

    self._dialog_box_motion_max_offset = (height - dialog_box_y) + 2 -- for _get_is_fully_off_screen
    self._dialog_box_y = dialog_box_y
    self._dialog_box_height = dialog_box_h
end

