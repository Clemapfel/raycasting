require "common.routine"
require "common.cutscene_actor"
require "common.cutscene_future"

--- @class rt.Cutscene
rt.Cutscene = meta.class("Cutscene")

local set_fenv = debug.setfenv
local set_upvalue = debug.setupvalue

--- @brief
function rt.Cutscene:instantiate(script_or_script_id)
    self._future_id_to_future = {}
    self._current_future_id = 0

    if meta.is_function(script_or_script_id) then
        local f = script_or_script_id
        set_fenv(f, self:_init_environment())
        self._coroutine = coroutine.create(f)
        self:update(0) -- start coroutine with error handling
    else
        rt.error("TODO")
    end
end

--- @brief
function rt.Cutscene:_init_environment(env)
    if env == nil then env = {} end

    --- @brief wait for a set of futures to finish
    env.await = function(...)

    end

    --- @brief wait for all futures to finish
    env.barrier = function(...)

    end

    --- @brief wait until
    env.condition = function(...)

    end

    --- @brief
    env.sleep = function(duration, ...)

    end

    --- @brief
    env.log = function(...)
        rt.log("In rt.Cutscene: ", ...)
    end

    --- @brief
    env.warning = function(...)
        rt.warning("In rt.Cutscene: ", ...)
    end

    --- @brief
    env.error = function(...)
        rt.critical("In rt.Cutscene: ", ...)
    end

    return env
end

--- @brief
function rt.Cutscene:add_actor(actor)
    meta.assert(actor, rt.CutsceneActor)
    rt.CutsceneActor._validate_schema(actor)

    local name = actor:get_name()
    if self._name_to_actor[name] ~= nil and self._name_to_actor[name] ~= actor then
        rt.warning("In rt.Cutscene: trying to add actor `", name, "`, but a different actor with that same name is already present")
    end

    self._name_to_actor[name] = actor
end

--- @brief
function rt.Cutscene:update(delta)
    meta.assert(delta, mt.Number)

    if coroutine.status(self._coroutine) ~= "dead" then
        local args = { coroutine.resume(self._coroutine) }
        if args[1] == false then
            rt.error("In rt.Cutscene.update: error in coroutine: ", args[2])
        else
            -- noop
        end
    end

    local to_remove = {}
    for id, future in pairs(self._future_id_to_future) do
        future:update(delta)
        if future:get_is_done() then
            table.insert(to_remove, id)
        end
    end

    for id in values(to_remove) do
        self._future_id_to_future[id] = nil
    end
end
