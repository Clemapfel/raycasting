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

do
    local _round = function(x) return x end
    local _error_prefix = function(self)
        return "In rt." .. meta.typeof(self) .. ".reformat: "
    end

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

        if math.is_nan(x) then rt.error(_error_prefix(self), "`x` is NaN") end
        if math.is_nan(y) then rt.error(_error_prefix(self), "`y` is NaN") end

        if math.is_nan(width) then
            rt.error(_error_prefix(self), "`width` is NaN")
        elseif math.is_inf(width) then
            rt.error(_error_prefix(self), "width cannot be infinite")
        elseif width < 0 then
            rt.error(_error_prefix(self), "`width` is negative")
        end

        if math.is_nan(height) then
            rt.error(_error_prefix(self), "`height` is NaN")
        elseif math.is_inf(height) then
            rt.error(_error_prefix(self), "height cannot be infinite")
        elseif height < 0 then
            rt.error(_error_prefix(self), "`height` is negative")
        end

        self._bounds.x = _round(x)
        self._bounds.y = _round(y)
        self._bounds.width = _round(width)
        self._bounds.height = _round(height)

        self:size_allocate(self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)
    end
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