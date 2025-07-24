--- @class ow.BloodDrop
ow.BloodDrop = meta.class("BloodDrop")

meta.add_signal(ow.BloodDrop, "collision")

--- @brief
function ow.BloodDrop:instantiate(stage, x, y, radius, vx, vy, hue)
    if vx == nil then vx = 0 end
    if vy == nil then vy = 0 end
    if hue == nil then hue = rt.random.number(0, 1) end

    meta.assert(stage, ow.Stage, x, "Number", y, "Number", radius, "Number", vx, "Number", vy, "Number")

    self._body = b2.Body(stage:get_physics_world(), b2.BodyType.DYNAMIC, x, y, b2.Circle(0, 0, radius))
    self._body:set_is_sensor(true)
    self._body:set_mass(1)
    self._body:set_velocity(vx, vy)
    self._x, self._y, self._radius = x, y, radius
    self._hue = hue
    self._is_destroyed = false

    self._body:signal_connect("collision_start", function(self_body, other_body)
        if other_body:has_tag("hitbox") then
            local x, y = self_body:get_position()
            if stage:get_blood_splatter():add(x, y, self._radius, self._hue) then
                self._is_destroyed = true
                self._body:destroy()
                return meta.DISCONNECT_SIGNAL
            end
        end
    end)
end

--- @brief
function ow.BloodDrop:get_body()
    return self._body
end

--- @brief
function ow.BloodDrop:draw()
    if self._is_destroyed then return end
    rt.LCHA(0.8, 1, self._hue, 1):bind()
    self._body:draw()
end
