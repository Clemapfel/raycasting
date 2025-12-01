require "overworld.dialog_box"
require "common.label"
require "common.translation"
require "common.smoothed_motion_1d"
require "common.filesystem"

--- @class ow.DialogEmitter
ow.DialogEmitter = meta.class("DialogEmitter")
meta.add_signal(ow.DialogEmitter, "start", "end")

--- @brief
function ow.DialogEmitter:instantiate(scene, id, target, should_lock)
    self._scene = scene

    self._should_lock = should_lock
    self._dialog_id = id

    if self._should_lock == nil then self._should_lock = true end

    self._target = target
    self._is_active = false

    local x_radius, y_radius = rt.settings.overworld.dialog_emitter.dialog_interact_sensor_radius, nil

    self._dialog_box = ow.DialogBox(self._dialog_id)
    self._dialog_box_active = false

    self._input = rt.InputSubscriber()
    self._interact_allowed = false
    self._input_delay = 0

    self._input:signal_connect("pressed", function(_, which)
        if self._dialog_box_active and self._input_delay <= 0 then
            self._dialog_box:handle_button(which)
        end
    end)

    -- show scene control indicator, delayed automatically
    self._resize_handler = nil

    -- portraits
    self._dialog_box:realize()
    self._dialog_box:signal_connect("speaker_changed", function(_, new_speaker)
        local px, py = self._x, self._y
        if new_speaker == rt.Translation.player_name then
            px, py = self._scene:get_player():get_position()
        elseif new_speaker == rt.Translation.npc_name then
            if self._target.get_position ~= nil then
                px, py = self._target:get_position()
            else
                px, py = self._target_wrapper:get_centroid()
            end
        end

        self._scene:get_camera():move_to(px, py)
    end)
end

--- @brief
function ow.DialogEmitter:_start_dialog()
    self:signal_emit("start")
    self:_reformat_dialog_box()
    self._dialog_box_active = true
    self._dialog_box:reset()

    if self._should_lock then
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        self._scene:get_player():set_movement_disabled(true)

        local camera = self._scene:get_camera()
        if self._target ~= nil then
            if self._target.get_position ~= nil then
                camera:move_to(self._target:get_position())
            else
                camera:move_to(self._target_wrapper:get_centroid())
            end
        else
            camera:move_to(self._scene:get_player():get_position())
        end
    end

    self._scene:set_control_indicator_type(ow.ControlIndicatorType.DIALOG)

    self._resize_handler = self._scene:signal_connect("resize", function(_, x, y, width, height)
        self:_reformat_dialog_box()
    end)

    self._dialog_box:signal_connect("done", function(_)
        self:_end_dialog()
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.DialogEmitter:_end_dialog()
    if self._dialog_box_active == true then
        self._dialog_box_active = false

        if self._should_lock then
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
        end
    end

    if self._should_lock then
        self._scene:get_player():set_movement_disabled(false)
    end

    if self._resize_handler ~= nil then
        self._scene:signal_disconnect("resize", self._resize_handler)
    end

    self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
    self:signal_emit("end")
end

--- @brief
function ow.DialogEmitter:_reformat_dialog_box()
    local bounds = self._scene:get_bounds()
    if self._bounds == nil or not bounds:equals(self._bounds) then
        self._bounds = bounds
        local x, y, w, h = self._bounds:unpack()
        local x_margin = 10 * rt.settings.margin_unit
        local y_margin = 3 * rt.settings.margin_unit
        y_margin = math.max(
            y_margin,
            select(2, self._scene._dialog_control_indicator:measure())
        )
        -- very ugly, but exposing a function in scene would be even more ugly

        self._dialog_box:reformat(
            x + x_margin,
            y + y_margin,
            w - 2 * x_margin,
            h - 2 * y_margin
        )
    end
end

--- @brief
function ow.DialogEmitter:update(delta)
    if self._dialog_box_active then
        self._dialog_box:update(delta)
    end

    self._input_delay = self._input_delay - 1
end

--- @brief
function ow.DialogEmitter:get_render_priority()
    return math.huge -- always on top
end

--- @brief
function ow.DialogEmitter:draw()
    if self._dialog_box_active then
        love.graphics.push()
        love.graphics.origin()
        self._dialog_box:draw()
        love.graphics.pop()
    end
end

--- @brief
function ow.DialogEmitter:reset()
    self._dialog_box_active = false
    self._dialog_box:reset()
end

--- @brief
function ow.DialogEmitter:set_target(target)
    self._target = target
end

--- @brief
function ow.DialogEmitter:get_is_active()
    return self._dialog_box_active
end

--- @brief
function ow.DialogEmitter:present()
    if self._dialog_box_active == false then
        self._input_delay = 3 -- ignore input of next 3 frames
        self:_start_dialog()
    end
end

--- @brief
function ow.DialogEmitter:close()
    self._dialog_box:close()
end
