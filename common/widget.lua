require "common.log"
require "common.aabb"
require "common.drawable"
require "common.selection_state"

--- @class rt.Widget
rt.Widget = meta.class("Widget", rt.Drawable)

--- @return rt.Widget
function rt.Widget:instantiate()
    meta.install(self, {
        _is_realized = false,
        _bounds = rt.AABB(0, 0, 1, 1),
        _selection_state = nil
    })
end

--- @brief
function rt.Widget:realize()
    log.error("In Widget.realize: abstract method called")
end

--- @brief
function rt.Widget:size_allocate(x, y, width, height)
    log.error("In Widget.size_allocate: abstract method called")
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
function rt.Widget:reformat(x, y, width, height)
    self._bounds.x = x or self._bounds.x
    self._bounds.y = y or self._bounds.y
    self._bounds.width = width or self._bounds.width
    self._bounds.height = height or self._bounds.height
    self:size_allocate(x, y, width, height)
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
    assert(meta.is_enum_value(state, rt.SelectionState), "In `" .. meta.typeof(self) .. "`.set_selection_state: for argument #1: expected `SelectionState`, got `" .. meta.typeof(state) .. "`")
    self._selection_state = state
end