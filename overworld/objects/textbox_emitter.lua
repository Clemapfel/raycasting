require "overworld.dialog_box"

rt.settings.overworld.text_box_emitter = {
    interact_delay_duration = 10 / 60,
    post_done_delay_duration = 1,
}

--- @class ow.TextboxEmitter
--- @signal activate (self, rt.Player) -> nil
ow.TextBoxEmitter = meta.class("TextboxEmitter", rt.Drawable)
meta.add_signals(ow.TextBoxEmitter, "activate")

--- @brief
function ow.TextBoxEmitter:instantiate(object, stage, scene)
    meta.install(self, {
        _object = object,
        _is_active = false,
        _dialog_box = ow.DialogBox(object:get_string("id", true)),
        _input = rt.InputSubscriber(),
        _interact_delay_elapsed = math.huge, -- pause right after interacting
        _post_done_delay_elapsed = math.huge,  -- pause after textbox is done
    })

    self:signal_connect("activate", function(self)
        if not self._is_active and self._post_done_delay_elapsed > rt.settings.overworld.text_box_emitter.post_done_delay_duration then
            self._is_active = true
            self._dialog_box:realize()
            self._dialog_box:reformat(0, 0, love.graphics.getDimensions())
            self._interact_delay_elapsed = 0

            local player = scene:get_player()
            player:request_is_disabled(self, true)

            self._dialog_box:signal_connect("done", function()
                player:request_is_disabled(self, false)
                self._dialog_box:reset()
                self._is_active = false
                self._post_done_delay_elapsed = 0
            end)
        end
    end)

    self._input:signal_connect("pressed", function(_, which)
        if self._is_active and self._interact_delay_elapsed > rt.settings.overworld.text_box_emitter.interact_delay_duration then
            self._dialog_box:handle_button(which)
        end
    end)

    self._input:signal_connect("left_joystick_moved", function(_, x, y)
        if self._is_active and self._interact_delay_elapsed > rt.settings.overworld.text_box_emitter.interact_delay_duration then
            if y < 0 then
                self._dialog_box:handle_button(rt.InputAction.UP)
            elseif y > 0 then
                self._dialog_box:handle_button(rt.InputAction.DOWN)
            end
        end
    end)
end

--- @brief
function ow.TextBoxEmitter:update(delta)
    if self._is_active then
        self._interact_delay_elapsed = self._interact_delay_elapsed + delta
        self._dialog_box:update(delta)
    else
        self._post_done_delay_elapsed = self._post_done_delay_elapsed + delta
    end
end

--- @brief
function ow.TextBoxEmitter:draw()
    if self._is_active then
        love.graphics.push()
        love.graphics.origin()
        self._dialog_box:draw()
        love.graphics.pop()
    end
end