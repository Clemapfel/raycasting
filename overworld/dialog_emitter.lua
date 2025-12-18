require "common.smoothed_motion_1d"
require "overworld.dialog_box"

--- @class ow.DialogEmitter
ow.DialogEmitter = meta.class("DialogEmitter", rt.Widget)
meta.add_signal(ow.DialogEmitter, "start", "end")

local _HIDDEN = 1
local _REVEALED = 0

--- @brief
function ow.DialogEmitter:instantiate(scene, id, target, should_lock, should_focus)
    self._scene = scene

    self._should_lock = should_lock
    if self._should_lock == nil then self._should_lock = true end

    self._should_focus = should_focus
    if self._should_focus == nil then self._should_focus = true end

    self._target = target -- may be nil
    if target ~= nil and target.get_position == nil then
        rt.critical("In ow.DialogEmitter: using `", meta.typeof(target), "` as cutscene target, but that types does not have a `get_position` function defined")
    end

    self._is_active = false
    self._should_reset = false

    self._dialog_box = ow.DialogBox(id)
    self._dialog_box_motion = rt.SmoothedMotion1D(_HIDDEN)
    self._dialog_box_motion_max_offset = 0
    self._dialog_box_y = 0
    self._dialog_box_height = 0

    self._dialog_box:signal_connect("advance", function(_, can_advance, can_exit)
        if can_advance == true and can_exit == true then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG_CAN_ADVANCE_CAN_EXIT)
        elseif can_advance == true and can_exit == false then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG_CAN_ADVANCE_CANNOT_EXIT)
        elseif can_advance == false and can_exit == true then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG_CANNOT_ADVANCE_CAN_EXIT)
        elseif can_advance == false and can_exit == false then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG_CANNOT_ADVANCE_CANNOT_EXIT)
        end
    end)

    self._dialog_box:signal_connect("done", function(_)
        self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
        self:close()
    end)

    self._input_delay = 0 -- n frames
    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if self._is_active and self._input_delay <= 0 then
            self._dialog_box:handle_button(which)
        end
    end)

    self._dialog_box:realize()
    self:reformat(self._scene:get_bounds():unpack())

    self._dialog_box:signal_connect("speaker_changed", function(dialog_box, new_speaker, state)
        local px, py = self._x, self._y
        if new_speaker == rt.Translation.player_name then
            px, py = self._scene:get_player():get_position()
        elseif self._target ~= nil then
            if self._target.get_position ~= nil then
                px, py = self._target:get_position()
            else
                px, py = self._target_wrapper:get_centroid()
            end
        else
            return
        end

        self._scene:get_camera():move_to(px, py)
    end)
    
    self._needs_reformat = false
    self._scene:signal_connect("resize", function(_, x, y, width, height)
        self:reformat(x, y, width, height)
    end)
end

--- @brief
function ow.DialogEmitter:present()
    self._is_active = true

    if self._needs_reformat == true then
        self:reformat(self._scene:get_bounds():unpack())
        self._needs_reformat = false
    end

    self:signal_emit("start")

    self._dialog_box:reset()
    self._dialog_box_motion:set_target_value(_REVEALED)

    if self._should_lock then
        self._scene:get_player():set_movement_disabled(true)
    end

    if self._should_focus then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        local camera = self._scene:get_camera()
        if self._target ~= nil then
            if self._target.get_position ~= nil then
                camera:move_to(self._target:get_position())
            end
        else
            camera:move_to(self._scene:get_player():get_position())
        end
    end

    self._dialog_box:signal_connect("done", function(_)
        self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
        self._dialog_box_motion:set_target_value(_HIDDEN)
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.DialogEmitter:close()
    self._is_active = false

    if self._should_lock then
        local n_delay = 5
        self._scene:signal_connect("update", function()
            n_delay = n_delay - 1
            if n_delay <= 0 then
                self._scene:get_player():set_movement_disabled(false)
                return meta.DISCONNECT_SIGNAL
            end
        end)
    end

    if self._should_focus then
        self._scene:set_camera_mode(ow.CameraMode.AUTO)
    end

    self._dialog_box_motion:set_target_value(_HIDDEN)
    self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
    self:signal_emit("end")

    self._should_reset = true
end

--- @brief
function ow.DialogEmitter:reset()
    local was_active = self._is_active
    self._is_active = false

    if was_active then self:close() end
    self._dialog_box_motion:set_value(_HIDDEN)
end

--- @brief
function ow.DialogEmitter:_get_is_fully_off_screen()
    local offset = self._dialog_box_motion:get_value() * self._dialog_box_motion_max_offset
    -- dialog box is fully off screen
    return self._dialog_box_y + offset > self:get_bounds().height
end

--- @brief
function ow.DialogEmitter:update(delta)
    if self._is_active
        and math.abs(self._dialog_box_motion:get_value() - _REVEALED) * self._dialog_box_motion_max_offset < 2
        -- and dialog box is less than 2 px away from its final position
    then
        self._dialog_box:update(delta)
    end

    if self._needs_reformat == true then
        self:_reformat_dialog_box(self._scene:get_bounds():unpack())
        self._needs_reformat = false
    end

    self._dialog_box_motion:update(delta)
    if self._should_reset and self:_get_is_fully_off_screen() then
        -- reset once fully of screen
        self:reset()
    end

    if self._input_delay > 1 then
        self._input_delay = self._input_delay - 1
    end
end

--- @brief
function ow.DialogEmitter:draw()
    if not self:_get_is_fully_off_screen() then
        love.graphics.push()
        love.graphics.origin()
        love.graphics.translate(0, self._dialog_box_motion:get_value() * self._dialog_box_motion_max_offset)
        self._dialog_box:draw()
        love.graphics.pop()
    end
end

--- @brief
function ow.DialogEmitter:get_is_active()
    return self._is_active
end

--- @brief
function ow.DialogEmitter:size_allocate(x, y, width, height)
    self:_reformat_dialog_box(x, y, width, height)
end

--- @brief
function ow.DialogEmitter:_reformat_dialog_box(x, y, w, h)
    local x_margin = 10 * rt.settings.margin_unit
    local y_margin = 3 * rt.settings.margin_unit
    y_margin = math.max(
        y_margin,
        select(2, self._scene:get_control_indicator(ow.ControlIndicatorType.DIALOG_CAN_ADVANCE_CAN_EXIT):measure())
    )

    local dialog_box_y = y + y_margin
    local dialog_box_h = h - 2 * y_margin
    self._dialog_box:reformat(
        x + x_margin,
        dialog_box_y,
        w - 2 * x_margin,
        dialog_box_h
    )

    self._dialog_box_motion_max_offset = (h - dialog_box_y) + 2 -- for _get_is_fully_off_screen
    self._dialog_box_y = dialog_box_y
    self._dialog_box_height = dialog_box_h
end

--- @brief
function ow.DialogEmitter:set_should_lock(b)
    self._should_lock = b
end

--- @brief
function ow.DialogEmitter:set_should_focus(b)
    self._should_focus = b
end
