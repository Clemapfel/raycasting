--- @class ow.OverlapTrigger
--- @types Polygon, Rectangle, Ellipse
--- @field signal String
--- @field target ow.ObjectWrapper
--- @field value any?
--- @signal activate (self, rt.Player) -> nil
ow.OverlapTrigger = meta.class("OverlapTrigger")
meta.add_signals(ow.OverlapTrigger, "activate")

--- @brief
function ow.OverlapTrigger:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC)
    self._target =  object:get_object("target", true)
    self._signal = object:get_string("signal", true)
    self._value = object:get("value", false)
    self._receiver = nil

    -- if player overlaps, activate
    self._body:set_is_sensor(true)
    self._body:set_collision_group(0x0)
    self._body:set_collides_with(0x0)

    -- add receive once stage is initialized
    stage:signal_connect("initialized", function(stage)
        self._receiver = stage:object_wrapper_to_instance(self._target)

        if self._receiver == nil then
            rt.error("In ow.OverlapTrigger: trigger `" .. object:get_id(),  "` targets object, but object `",  self._target,  "`is not present on the same layer")
        end

        if not self._receiver:signal_has_signal(self._signal) then
            rt.error("In ow.OverlapTrigger: trigger `",  object:get_id(),  "` is set to trigger signal `",  self._signal,  "` in object `",  meta.typeof(self._receiver),  "`, but it does not have that signal")
        end

        self._body:set_collides_with(rt.settings.player.bounce_collision_group)
        self._body:set_collision_group(rt.settings.player.bounce_collision_group)
        self._body:signal_connect("collision_start", function(self_body, other_body)
            if other_body:has_tag("player") then
                self._receiver:signal_try_emit(self._signal, self._value)
            end
        end)

        return meta.DISCONNECT_SIGNAL
    end)
end