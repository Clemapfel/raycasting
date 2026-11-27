--- @class ow.MovableObject
ow.MovableObject = meta.abstract_class("MovableObject")

--- @class ow.SolidMovableObject
ow.SolidMovableObject = meta.abstract_class("SolidMovableObject", ow.MovableObject)

-- check if object has self._body, then forward if possible, otherwise hard throw (type error)
local _forward_or_throw = function(self, scope, ...)
    if self._body ~= nil and meta.isa(self._body, b2.Body) then
        rt.assert(self._body:get_type() ~= b2.BodyType.STATIC, "In ow.", meta.typeof(self), ".", scope, ": self._body is `STATIC`, it cannot be moved")
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


--- @brief
function ow.SolidMovableObject:get_contour()
    if DEBUG then
        if not meta.isa(self._body, b2.Body) then
            rt.error("In ow.MovableObject: object `", meta.typeof(self), "` does not have self._body")
        end

        if not meta.isa(self._contour, rt.Polyline) then
            rt.error("In ow.MovableObject: object `", meta.typeof(self), "` does not have self._contour")
        end
    end

    if self._solid_movable_object_contour == nil then
        local data = {}
        local cx, cy = self._body:get_position()
        for i = 1, self._contour:get_n_vertices() do
            local x, y = self._contour:get_vertex(i)
            table.insert(data, x - cx)
            table.insert(data, y - cy)
        end

        self._solid_movable_object_contour = data
    end

    local x, y = self._body:get_position()

    -- cache
    if self._solid_movable_object_final_contour ~= nil
        and self._solid_movable_object_final_x == x
        and self._solid_movable_object_final_y == y
    then
        return self._solid_movable_object_final_contour
    end

    local normalized = self._solid_movable_object_contour
    local out = {}
    for i = 1, #normalized, 2 do
        out[i + 0] = normalized[i + 0] + x
        out[i + 1] = normalized[i + 1] + y
    end

    self._solid_movable_object_final_contour = rt.Polyline(out)
    self._solid_movable_object_final_x = x
    self._solid_movable_object_final_y = y

    return self._solid_movable_object_final_contour
end