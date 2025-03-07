require "common.widget"

--- @class rt.Scene
--- @signal update (Scene) -> nil
rt.Scene = meta.abstract_class("Scene", rt.Widget)

--- @brief
function rt.Scene:instantiate()
    self._is_active = false
end

meta.add_signals(rt.Scene,
    "update"
)

--- @brief
function rt.Scene:enter(...)
    rt.error("In " .. meta.typeof(self) .. ".enter: abstract method called")
end

--- @brief
function rt.Scene:exit()
    -- noop
end

--- @brief
function rt.Scene:get_is_active()
    return self._is_active
end

--- @override
function rt.Scene:realize()
    -- noop
end

--- @override
function rt.Scene:size_allocate(x, y, width, height)
    rt.error("In " .. meta.typeof(self) .. ".size_allocate: abstract method called")
end

--- @override
function rt.Scene:draw()
    rt.error("In " .. meta.typeof(self) .. ".draw: abstract method called")
end

--- @override
function rt.Scene:update(delta)
    rt.error("In " .. meta.typeof(self) .. ".update: abstract method called")
end
