require "common.thread"
require "common.channel"

--- @class rt.FileIO
rt.FileIO = meta.class("FileIO")

--- @class rt.FileIOFuture
rt.FileIOFuture = meta.class("Future")

--- @brief
function rt.FileIOFuture:instantiate(id)
    self._id = id
    self.is_done = false
    self.content = nil
    self.error = nil
end

--- @brief
function rt.FileIOFuture:get_is_done()
    return self.is_done == true
end

--- @brief
function rt.FileIOFuture:get_content()
    return self.content
end

--- @brief
function rt.FileIOFuture:get_error()
    return self.error
end


local MessageType = {
    WRITE = 0,
    WRITE_RESPONSE = 1,
    READ = 2,
    READ_RESPONSE = 3,
    ERROR = 4,
    SHUTDOWN = 5,
    SHUTDOWN_RESPONSE = 6
}

--- @brief
function rt.FileIO:instantiate(n_workers)
    self._workers = {}
    self._n_workers = n_workers or 1
    self._n_shutdown = 0
    
    self._current_future_id = 0
    self._future_id_to_future = meta.make_weak({})

    self._main_to_worker = rt.Channel()
    for i = 1, self._n_workers do
        local worker = {
            thread = rt.Thread("common/file_io_worker.lua"),
            worker_to_main = rt.Channel(),
            main_to_worker = self._main_to_worker
        }

        worker.thread:signal_connect("shutdown", function()
            self:shutdown()
        end)

        if not rt.ThreadManager:get_is_shutdown_active() then
            worker.thread:start(
                worker.main_to_worker:get_native(),
                worker.worker_to_main:get_native(),
                MessageType
            )
        else
            self._n_shutdown = self._n_shutdown + 1
        end

        table.insert(self._workers, worker)
    end
end

--- @brief
function rt.FileIO:_new_future()
    local id = self._current_future_id
    self._current_future_id = self._current_future_id + 1

    local future = rt.FileIOFuture(id)
    self._future_id_to_future[id] = future
    return future, id
end

--- @brief
function rt.FileIO:_finalize_future(id, success, content, error_maybe)
    local future = self._future_id_to_future[id]
    if future ~= nil then
        future.is_done = true
        future.content = content
        future.error = error_maybe
    end
end

--- @brief
function rt.FileIO:write(path, content, allow_overwrite, allow_create_directory)
    if allow_overwrite == nil then allow_overwrite = false end
    if allow_create_directory == nil then allow_create_directory = true end

    if self:get_is_shutdown() then
        rt.error("In rt.FileIO: trying to write to `", path, "`, but file writer thread was already shut down")
        return nil
    end
    meta.assert(path, "String", content, "String")

    local future, id = self:_new_future()
    self._main_to_worker:push({
        type = MessageType.WRITE,
        id = id,
        path = path,
        content = content,
        allow_overwrite = allow_overwrite,
        allow_create_directory = allow_create_directory
    })

    return future
end

--- @brief
function rt.FileIO:read(path)
    if self:get_is_shutdown() then
        rt.error("In rt.FileIO: trying to read `", path, "`, but file writer thread was already shut down")
        return nil
    end
    meta.assert(path, "String")

    local future, id = self:_new_future()
    self._main_to_worker:push({
        type = MessageType.READ,
        id = id,
        path = path
    })

    return future
end

--- @brief
function rt.FileIO:get_is_shutdown()
    return self._n_shutdown >= self._n_workers
end

--- @brief
function rt.FileIO:shutdown()
    if self:get_is_shutdown() then return end

    for i = 1, self._n_workers do
        self._main_to_worker:push({ type = MessageType.SHUTDOWN })
    end
end

--- @brief
function rt.FileIO:update(delta)
    for worker in values(self._workers) do
        while worker.thread:get_is_running() and worker.worker_to_main:get_n_messages() > 0 do
            local message = worker.worker_to_main:pop()

            if message.type == MessageType.WRITE_RESPONSE then
                if message.success ~= true then
                    rt.critical("In rt.FileIO: unable to write to `", message.path, "`: ", message.error)
                end

                self:_finalize_future(
                    message.id,
                    message.success,
                    nil, -- content
                    message.error
                )

            elseif message.type == MessageType.READ_RESPONSE then
                if message.success ~= true then
                    rt.critical("In rt.FileIO: unable to read file at `", message.path, "`: ", message.error)
                end
                self:_finalize_future(
                    message.id,
                    message.success,
                    message.content,
                    message.error
                )

            elseif message.type == MessageType.SHUTDOWN_RESPONSE then
                self._n_shutdown = self._n_shutdown + 1
            elseif message.type == MessageType.ERROR then
                rt.critical("In rt.FileIO: error in thread: ", message.error)
            else
                rt.error("In rt.FileIO.update: unhandled message type `", message.type, "`")
            end
        end
    end
end