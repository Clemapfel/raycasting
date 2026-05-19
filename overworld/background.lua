require "common.filesystem"

local _id_to_class = {}
bd.apply("overworld/backgrounds", function(_, id)
    id = string.replace(id, ".lua", "")
    local path = "overworld.backgrounds." .. id
    local class = require(path)
    if not meta.typeof(class) == "Type" then
        rt.error("In ow.Background: when trying to include `", path, "`. File does not return a class objects")
    end
    _id_to_class[id] = class
end)

--- @class ow.Background
ow.Background = meta.class("OverworldBackground", rt.Widget)

function ow.Background:instantiate(scene, id, ...)
    if _id_to_class[id] == nil then
        rt.error("In ow.Background: no background with id `", id, "`")
    end

    self._id = id
    self._instance = _id_to_class[id](scene, ...)
end

--- @brief
function ow.Background:get_id()
    return self._id
end

--- @brief
function ow.Background:realize()
    self._instance:realize()
end

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._instance:size_allocate(x, y, width, height)
end

--- @brief
function ow.Background:update(delta)
    self._instance:update(delta)
end

--- @brief
function ow.Background:draw()
    self._instance:draw()
end

--- @brief
function ow.Background:draw_bloom()
    self._instance:draw_bloom()
end

--- @brief
function ow.Background:notify_camera_changed(camera)
    self._instance:notify_camera_changed(camera)
end

