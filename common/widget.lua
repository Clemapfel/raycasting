require "common.log"
require "common.aabb"
require "common.drawable"
require "common.selection_state"

--- @class rt.Widget
rt.Widget = meta.class("Widget", rt.Drawable)

--- @return rt.Widget
function rt.Widget:instantiate()
    self._is_realized = false
    self._bounds = rt.AABB(0, 0, 1, 1)
    self._selection_state = nil
end

--- @brief
function rt.Widget:realize()
    self._is_realized = true
end

--- @brief
function rt.Widget:size_allocate(x, y, width, height)
    meta.assert(x, mt.Number, y, mt.Number, width, mt.Number, height, mt.Number)
    rt.error("In ", meta.typeof(self), ".size_allocate: abstract method called")
end

--- @brief
function rt.Widget:draw()
    -- noop
end

--- @brief
function rt.Widget:update(delta)
    -- noop
end

--- @brief
function rt.Widget:draw_bounds()
    love.graphics.rectangle("line", self._bounds:unpack())
end

local _round = function(x) return x end

--- @brief
function rt.Widget:reformat(x, y, width, height)
    if meta.isa(x, rt.AABB) then
        meta.assert(x, rt.AABB, y, mt.Nil, width, mt.Nil, height, mt.Nil)
        x, y, width, height = x:unpack()
    else
        local current_x, current_y, current_w, current_h = self._bounds:unpack()
        if x == nil then x = current_x end
        if y == nil then y = current_y end
        if width == nil then width = current_w end
        if height == nil then height = current_h end

        meta.assert(x, mt.Number, y, mt.Number, width, mt.Number, height, mt.Number)
    end

    if width == math.huge then width = self._bounds.width end
    if height == math.huge then height = self._bounds.height end

    self._bounds.x = _round(x)
    self._bounds.y = _round(y)
    self._bounds.width = _round(width)
    self._bounds.height = _round(height)

    rt.assert(self._bounds.width >= 0, "in rt.Widget.reformat: width is `", width, "`, but it cannot be negative")
    rt.assert(self._bounds.height >= 0, "in rt.Widget.reformat: height is `", height, "`, but it cannot be negative")

    self:size_allocate(self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)
end

--- @brief
function rt.Widget:already_realized()
    local before = self._is_realized
    self._is_realized = true
    return before
end

--- @brief
function rt.Widget:get_is_realized()
    return self._is_realized
end

--- @brief
function rt.Widget:measure()
    return self._bounds.width, self._bounds.height
end

--- @brief
function rt.Widget:get_position()
    return self._bounds.x, self._bounds.y
end

--- @brief
function rt.Widget:get_bounds()
    return self._bounds
end

--- @brief
function rt.Widget:get_selection_state()
    if self._selection_state == nil then
        return rt.SelectionState.INACTIVE
    else
        return self._selection_state
    end
end

--- @brief
function rt.Widget:set_selection_state(state)
    meta.assert(state, rt.SelectionState)
    self._selection_state = state
end