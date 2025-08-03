--- @class rt.Actor
rt.Actor = meta.abstract_class("Actor")

local _throw = function(scope)
    rt.error("In rt.Actor." .. scope .. ": abstract method called")
end

--- @brief
function rt.Actor:set_velocity(vx, vy)
    _throw("set_velocity")
end

--- @brief
function rt.Actor:get_velocity()
    _throw("get_velocity")
    return 0, 0
end

--- @brief
function rt.Actor:set_position(x, y)
    _throw("set_position")
end

--- @brief
function rt.Actor:get_position()
    _throw("get_position")
    return 0, 0
end

--- @brief
function rt.Actor:get_id()
    _throw("get_id")
    return ""
end

--- @brief
function rt.Actor:get_name()
    _throw("get_name")
    return ""
end


