require "common.widget"

--- @class rt.Scene
--- @signal update (Scene) -> nil
--- @signal resize (Scene, x, y, width, height) -> nil
rt.Scene = meta.abstract_class("Scene", rt.Widget)

meta.add_signals(rt.Scene,
    "update",
    "enter",
    "exit",
    "resize"
)

--- @brief
function rt.Scene:instantiate()
end

--- @brief
function rt.Scene:exit()
    -- noop
end

--- @brief
function rt.Scene:get_is_active()
    rt.SceneManager:get_scene_is_active(self)
end

--- @override
function rt.Scene:realize()
    -- noop
end

--- @brief
function rt.Scene:get_debug_information()
    return ""
end

--- @brief
function rt.Scene:get_allow_downscaling()
    return false
end

