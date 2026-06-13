require "common.widget"

--- @class rt.Scene
--- @signal update (Scene) -> nil
--- @signal resize (Scene, x, y, width, height) -> nil
rt.Scene = meta.abstract_class("Scene", rt.Widget, {
    --- (...) -> Nil
    enter = meta.Function,

    --- (x : Number, y : Number, w : Number, h : Number) -> Nil
    size_allocate = meta.Function,

    --- () -> Nil
    draw = meta.Function,

    --- (delta : Number) -> Nil
    update = meta.Function
})

meta.add_signals(rt.Scene,
    "update",
    "enter",
    "exit",
    "resize"
)

--- @brief
function rt.Scene:instantiate()
    self._is_active = false -- set by SceneManager
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

