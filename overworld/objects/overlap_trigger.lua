--- @class ow.OverlapTrigger
--- @field signal String
--- @field target ow.ObjectWrapper
--- @field value any?
ow.OverlapTrigger = meta.class("OverlapTrigger", rt.Drawable) -- TODO

--- @brief
function ow.OverlapTrigger:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC),
        _target =  object:get_object("target", true),
        _signal = object:get_string("signal", true),
        _value = object:get("value", false),
        _receiver = nil
    })

    local signal_id
    signal_id = stage:signal_connect("initialized", function(stage)
        self._receiver = stage:get_object_instance(self._target)
        if not self._receiver:signal_has_signal(self._signal) then
            rt.error("In ow.OverlapTrigger: trigger `" .. object:get_id() .. "` is set to trigger signal `" .. self._signal .. "` in object `" .. meta.typeof(self._receiver) .. "`, but it does not have that signal")
        end
        stage:signal_disconnect("initialized", signal_id)
    end)

    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function(self_body, other_body, x, y, nx, ny)
        assert(self._receiver ~= nil)
        if other_body:has_tag("player") or other_body:has_tag("agent") then
            self._receiver:signal_emit(self._signal, self._value)
        end
    end)
end

--- @brief
function ow.OverlapTrigger:draw()
    self._body:draw()
end