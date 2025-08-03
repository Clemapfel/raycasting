require "common.actor"

--- @brief @class rt.Cutscene
rt.Cutscene = meta.class("Cutscene")

--- @brief
--- @param ... rt.Actor
function rt.Cutscene:instantiate(script_id, ...)
    self._dialog_handler = rt.DialogHandler()
end

--- @brief
local _speak = function(actor, dialog_node)

end

--- @brief
local _move_to = function(actor, new_x, new_y)

end

--- @brief
local _turn_to = function(actor, point_x, point_y)

end

--- @brief
local _barrier = function(...)

end

--- @brief
function rt.Cutscene:update(delta)

end

--- @brief
function rt.Cutscene:draw()

end