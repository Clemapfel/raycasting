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
function rt.Cutscene:_notify_future_added(future)
    local id = self._current_future_id
    self._future_id_to_future[id] = future
    self._current_future_id = self._current_future_id + 1
end

--- @brief
function rt.Cutscene:_init_environment(env)
    if env == nil then env = {} end

    local cutscene = self
    local yield = coroutine.yield
    local throw = function(scope, arg_i, expected, got)
        rt.error("In rt.Cutscene.", scope, ": for argument #1: expected argument of type `", meta.get_typename(expected), "`, got `", meta.typeof(got), "`")
    end

    --- @brief wait for a set of futures to finish
    env.await = function(future)
        if not meta.isa(future, rt.CutsceneFuture) then
            throw("await", 1, rt.CutsceneFuture, future)
        end

        while not future:get_is_done() do
            yield()
        end

        return future:get_result()
    end

    --- @brief wait for all futures to finish
    env.barrier = function(...)
        meta.assert(select(1, ...), mt.Nil)
        for _, future in pairs(self._future_id_to_future) do
            while not future:get_is_done() do
                yield()
            end
        end
    end

    --- @brief
    env.sleep = function(duration, ...)
        meta.assert(duration, mt.Number, select(1, ...), mt.Nil)
        local elapsed = 0
        return rt.CutsceneFuture(
            cutscene,
            -- on update
            function(delta)
                elapsed = elapsed + delta
                if elapsed > duration then
                    return rt.CutsceneFutureResult.EXIT
                else
                    return rt.CutsceneFutureResult.CONTINUE
                end
            end
        )
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
