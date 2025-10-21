--- @class ow.OverlapTrigger
--- @types Polygon, Rectangle, Ellipse
--- @field signal String
--- @field target ow.ObjectWrapper
--- @field value any?
--- @signal activate (self, rt.Player) -> nil
ow.OverlapTrigger = meta.class("OverlapTrigger", rt.Drawable) -- TODO
meta.add_signals(ow.OverlapTrigger, "activate")

--- @brief
function ow.OverlapTrigger:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC),
        _target =  object:get_object("target", true),
        _signal = object:get_string("signal", true),
        _value = object:get("value", false),
        _receiver = nil
    })

    -- add receive once stage is initialized
    stage:signal_connect("initialized", function(stage)
        self._receiver = stage:object_wrapper_to_instance(self._target)

        if self._receiver == nil then
            rt.error("In ow.OverlapTrigger: trigger `" .. object:get_id(),  "` targets object, but object `",  self._target,  "`is not present on the same layer")
        end

        if not self._receiver:signal_has_signal(self._signal) then
            rt.error("In ow.OverlapTrigger: trigger `",  object:get_id(),  "` is set to trigger signal `",  self._signal,  "` in object `",  meta.typeof(self._receiver),  "`, but it does not have that signal")
        end

        return meta.DISCONNECT_SIGNAL
    end)

    -- if player overlaps, activate
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)
    self._body:signal_connect("collision_start", function(self_body, other_body, x, y, nx, ny)
        self:signal_emit("activate")
    end)

    -- if activated, emit receiver
    self:signal_connect("activate", function()
        self._receiver:signal_try_emit(self._signal, self._value)
    end)
end

--- @brief
function ow.OverlapTrigger:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()
end