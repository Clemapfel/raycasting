require "common.cutscene_actor"

--- @class rt.CutsceneHandler
rt.CutsceneHandler = meta.class("CutsceneHandler")

--- @class rt.CutsceneHandler.Future
rt.CutsceneHandler.Future = meta.class("CutsceneHandlerFuture")

--- @brief
function rt.CutsceneHandler:instantiate(script_id)
    self._name_to_actor = {} -- Table<String, rt.CutsceneActor>


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
function rt.CutsceneActor: