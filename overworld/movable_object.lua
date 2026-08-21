--- @class ow.MovableObject
ow.MovableObject = meta.abstract_class("MovableObject")

-- check if object has self._body, then forward if possible, otherwise hard throw (type error)
local _forward_or_throw = function(self, scope, ...)
    if self._body ~= nil and meta.isa(self._body, b2.Body) then
        assert(self._body:get_type() ~= b2.BodyType.STATIC, "In ow." .. meta.typeof(self) .. "." .. scope .. ": self._body is `STATIC`, it cannot be moved")
        return self._body[scope](self._body, ...)
    else
        rt.error("In ", meta.typeof(self), "." .. scope .. ": for object `", self:get_id(), "`: abstract method called")
    end
end

--- @brief
function ow.MovableObject:set_position(x, y)
    _forward_or_throw(self, "set_position", x, y)
end

--- @brief
function ow.MovableObject:get_position()
    return _forward_or_throw(self, "get_position")
end

--- @brief
function ow.MovableObject:set_velocity(vx, vy)
    _forward_or_throw(self, "set_velocity", vx, vy)
end

--- @brief
function ow.MovableObject:get_velocity()
    return _forward_or_throw(self, "get_velocity")
end

--- @brief get whether an object is currently in bounds of the camera view
--- @return Boolean
function ow.MovableObject:get_is_visible()
    if self._body == nil
        or not meta.isa(self._body, b2.Body)
        or self._stage == nil
        or not meta.isa(self._stage, ow.Stage)
    then
        rt.error("In ", meta.typeof(self), ".get_is_visible: abstract function called")
    else
        return self._stage:get_is_body_visible(self._body)
    end
end