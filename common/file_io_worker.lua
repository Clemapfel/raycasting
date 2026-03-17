local main_to_worker, worker_to_main, MessageType = ...

require "include"
require "common.common"
require "common.filesystem"

local function read_file(path)
    path = bd.normalize_path(path)
    if not bd.exists(path) then
        error(string.paste("file at `", path, "` does not exist"))
    end
    if bd.is_directory(path) then
        error(string.paste("path `", path, "` is a directory, not a file"))
    end
    return bd.read_file(path)
end

local function write_file(path, content, allow_overwrite, allow_create_directory)
    path = bd.normalize_path(path)

    local directory = bd.get_directory_prefix(path)
    if directory ~= nil and directory ~= "" and not bd.exists(directory) then
        if allow_create_directory then
            bd.create_directory(directory)
        else
            error(string.paste("directory `", directory, "` does not exist and creation was disallowed"))
        end
    end

    bd.create_file(path, content, allow_overwrite)
end

--[[
message formats:

WRITE: main -> worker
    type    : MessageType
    id      : Integer
    path    : String
    content : String
    allow_overwrite  : Boolean
    allow_create_directory : Boolean

WRITE_RESPONSE: worker -> main
    type    : MessageType
    id      : Integer
    path    : String
    success : Boolean
    error   : String?

READ: main -> worker
    type    : MessageType
    id      : Integer
    path    : String

READ_RESPONSE: worker -> main
    type    : MessageType
    id      : Integer
    path    : String
    content : String
    success : Boolean
    error   : String?

ERROR: worker -> main
    type    : MessageType
    message : String

SHUTDOWN: main -> worker
    type    : MessageType

SHUTDOWN_RESPONSE: worker -> main
    type    : MessageType
    success : Boolean
    error   : String?
]]


local function main()
    local shutdown_active = false
    while true do
        if shutdown_active and main_to_worker:getCount() == 0 then break end

        local message = main_to_worker:demand()
        if message.type == MessageType.WRITE then
            local success, error_maybe = pcall(
                write_file,
                message.path,
                message.content,
                message.allow_overwrite,
                message.allow_create_directory
            )

            worker_to_main:push({
                type = MessageType.WRITE_RESPONSE,
                id = message.id,
                path = message.path,
                success = success,
                error = error_maybe
            })
        elseif message.type == MessageType.READ then
            local success, error_or_content = pcall(read_file, message.path)
            worker_to_main:push({
                type = MessageType.READ_RESPONSE,
                id = message.id,
                path = message.path,
                content = success and error_or_content or "",
                success = success,
                error = not success and error_or_content or nil
            })
        elseif message.type == MessageType.SHUTDOWN then
            shutdown_active = true
        end
    end
end

local success, error_maybe = pcall(main)
worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_maybe
})