require "common.cutscene_actor"
require "common.cutscene_future"

--- @class rt.CutsceneHandler
rt.CutsceneHandler = meta.class("CutsceneHandler")

--- @brief
function rt.CutsceneHandler:instantiate(script_id)
end

--- @brief
function rt.CutsceneHandler:add_actor(actor)
    meta.assert(actor, rt.CutsceneActor)
    rt.CutsceneActor._validate_schema(actor)

    local name = actor:get_name()
    if self._name_to_actor[name] ~= nil and self._name_to_actor[name] ~= actor then
        rt.warning("In rt.CutsceneHandler: trying to add actor `", name, "`, but a different actor with that same name is already present")
    end

    self._name_to_actor[name] = actor
end

--- @brief
