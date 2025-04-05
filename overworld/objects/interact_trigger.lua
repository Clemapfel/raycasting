--- @class ow.InteractTrigger
--- @field signal String
--- @field target ow.ObjectWrapper
--- @field value any?
ow.InteractTrigger = meta.class("InteractTrigger", rt.Drawable) -- TODO
meta.add_signals(ow.InteractTrigger, "activate")

--- @brief
function ow.InteractTrigger:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC),
        _target =  object:get_object("target", true),
        _signal = object:get_string("signal", true),
        _value = object:get("value", false),
        _receiver = nil
    })

    -- add receive once stage is initialized
    local signal_id
    signal_id = stage:signal_connect("initialized", function(stage)
        self._receiver = stage:get_object_instance(self._target)

        if self._receiver == nil then
            rt.error("In ow.InteractTrigger: trigger `" .. object:get_id() .. "` targets object, but object `" .. self._target .. "`is not present on the same layer")
        end

        if not self._receiver:signal_has_signal(self._signal) then
            rt.error("In ow.InteractTrigger: trigger `" .. object:get_id() .. "` is set to trigger signal `" .. self._signal .. "` in object `" .. meta.typeof(self._receiver) .. "`, but it does not have that signal")
        end

        stage:signal_disconnect("initialized", signal_id)
    end)

    -- if player overlaps, notify as interact target
    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function(self_body, other_body, x, y, nx, ny)
        if other_body:has_tag("player") or other_body:has_tag("agent") then
            other_body:get_user_data():add_interact_target(self)
        end
    end)

    self._body:signal_connect("collision_end", function(self_body, other_body, x, y, nx, ny)
        if other_body:has_tag("player") or other_body:has_tag("agent") then
            other_body:get_user_data():remove_interact_target(self)
        end
    end)

    -- if activated, emit receiver
    self:signal_connect("activate", function()
        self._receiver:signal_emit(self._signal, self._value)
    end)
end

--- @brief
function ow.InteractTrigger:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()
end