--- @class rt.AnimationResult
rt.AnimationResult = meta.enum("AnimationResult", {
    CONTINUE = false,
    DISCONTINUE = true
})

--- @class rt.AnimationState
rt.AnimationState = meta.enum("AnimationState", {
    IDLE = 1,       -- not yet started
    STARTED = 2,    -- running
    FINISHED = 3    -- done running
})

--- @class rt.QueuableAnimation
--- @signal start (self) -> nil
--- @signal finish (self) -> nil
rt.Animation = meta.abstract_class("Animation", function()
    self._state = rt.AnimationState.IDLE
end)

meta.add_signals(rt.Animation,
    "start", -- before start invocation
    "finish" -- after finish invocation
)

--- @brief
function rt.Animation:start()
    -- noop
end

--- @brief
function rt.Animation:finish()
    -- noop
end

--- @brief
function rt.Animation:update(delta)
    return rt.AnimationResult.DISCONTINUE
end

--- @brief
function rt.Animation:draw()
    -- noop
end

--- @brief
function rt.Animation:get_state()
    return self._state
end

-- ###

--- @class rt.AnimationQueue
rt.AnimationQueue = meta.class("AnimationQueue", function()
    meta.install(self, {
        _nodes = {},
        _n_nodes = 0,
        _start_should_trigger = true
    })
end)

meta.add_signals(rt.AnimationQueue,
    "emptied"
)

--- @brief [internal]
function rt.AnimationQueue:_new_node(...)
    local n_args = select("#", ...)
    if n_args == 0 then return nil end
    for i = 1, n_args do
        meta.assert_isa(select(i, ...), rt.Animation)
    end
    return {
        was_started = false,
        animations = {...}
    }
end

--- @brief
function rt.AnimationQueue:push(animation, ...)
    if self._n_nodes == 0 then self._start_should_trigger = true end
    table.insert(self._nodes, self:_new_node(animation, ...))
    self._n_nodes = self._n_nodes + 1
end

--- @brief
function rt.AnimationQueue:append(...)
    if self._n_nodes == 0 then
        self:push(...)
    else
        local was_only_node = self._n_nodes == 1
        local last_node = self._nodes[self._n_nodes]
        local n_args = select("#", ...)
        for i = 1, n_args do
            table.insert(last_node.animations, select(i, ...))
        end

        if last_node.was_started then
            self:update(0) -- invoke signal callbacks the same frame it is queue, if the queue is already active
        end
    end
end

do
    local _finish_animation = function(animation)
        animation._state = rt.AnimationState.FINISHED
        animation:finish()
        animation:signal_emit("finish")
        rt.savepoint_maybe()
    end

    local _start_animation = function(animation)
        animation._state = rt.AnimationState.STARTED
        animation:signal_emit("start")
        animation:start()
        rt.savepoint_maybe()
    end

    --- @brief
    function rt.AnimationQueue:update(delta)
        if self._n_nodes == 0 then return end

        local first = self._nodes[1]
        local is_done = true
        for animation in values(first.animations) do
            if animation._state == rt.AnimationState.IDLE then
                _start_animation(animation)
                local res = animation:update(0)
                if res == rt.AnimationResult.CONTINUE then
                    is_done = false
                else
                    if res ~= rt.AnimationResult.DISCONTINUE then
                        rt.error("In rt.AnimationQueue.update: animation `" .. meta.typeof(animation) .. "`s update function does not return an rt.AnimationResult")
                        return
                    end

                    -- 1-frame callbacks
                    _finish_animation(animation)
                end
            elseif animation._state == rt.AnimationState.STARTED then
                local res = animation:update(delta)
                if res == rt.AnimationResult.DISCONTINUE then
                    _finish_animation(animation)
                else
                    is_done = false
                end
            else
                -- noop
            end
        end

        if is_done and self._n_nodes > 0 then
            table.remove(self._nodes, 1)
            self._n_nodes = self._n_nodes - 1
            if self._n_nodes > 0 then
                return self:update(0) -- cycle to trigger more 1-frame callbacks of the next nodes on the same frame
            else
                self:signal_emit("emptied")
            end
        end
    end

    --- @brief
    function rt.AnimationQueue:skip()
        local first = self._nodes[1]
        if first == nil then return end

        for animation in values(first.animations) do
            if animation._state == rt.AnimationState.IDLE then
                _start_animation(animation)
                animation:update(0)
            elseif animation._state == rt.AnimationState.STARTED then
                animation:update(0)
            end

            _finish_animation(animation)
        end

        table.remove(self._nodes, 1)
        self._n_nodes = self._n_nodes - 1
        if self._n_nodes <= 0 then self:signal_emit("emptied") end
    end

    --- @brief
    function rt.AnimationQueue:clear()
        while self._n_nodes > 0 do
            self:skip()
        end
    end
end

--- @brief
function rt.AnimationQueue:draw()
    if self._n_nodes == 0 then return end
    for node in values(self._nodes) do
        for animation in values(node.animations) do
            if animation._state > rt.AnimationState.IDLE then
                -- also renders finished animations after they area done, is this intended behavior?
                animation:draw()
            end
        end
    end
end
