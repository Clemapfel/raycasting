--- @class rt.ThreadHandler
rt.ThreadHandler = meta.class("ThreadHandler")

--- @brief
function rt.ThreadHandler:instantiate()

end

--- @brief
function rt.ThreadHandler:notify_thread_added(thread)
    meta.assert(thread, rt.Thread)
    -- TODO
end

rt.ThreadHandler = rt.ThreadHandler() -- singleton instance