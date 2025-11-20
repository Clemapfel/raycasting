require "common.common"
require "love.math"

local main_to_worker, worker_to_main, MessageType = ...

local save_dir = "saves"
local appdata_dir = string.gsub(love.filesystem.getSaveDirectory(), "\\", "/")

-- convert _000...001234 to 1234
local save_id_to_index = function(filename)
    rt.assert(type(filename) == "string")
    return string.match(filename, "^_0*(%d+)$")
end

-- convert 1234 to _00...0001234
local index_to_save_id = function(id)
    rt.assert(type(id) == "number")
    local str = id
    return "_" .. string.rep("0", math.max(16 - utf8.len(str), 0)) .. id
end

-- "encrypt" hash
local encrypt_hash = function(hash)
    local to_concat = {}
    for i = 1, #hash do
        table.insert(to_concat, 1, string.at(hash, i))
    end
    return table.concat(to_concat)
end
local decrypt_hash = encrypt_hash

-- check if sha256 is valid
local is_valid_hash = function(hash)
    return string.match(hash, "^[a-fA-F0-9]*$") ~= nil and #hash == 64
end

-- convert string to sha256
local hash_string = function(str)
    return love.data.encode("string", "hex", love.data.hash("string", "sha256", str))
end

-- convert string to base64
local base64_encode = function(str)
    return love.data.encode("string", "base64", str)
end

-- convert base64 to string
local base64_decode = function(str)
    return love.data.decode("string", "base64", str)
end

-- save promote error, thread should be incapable of crashing
local push_error = function(reason)
    worker_to_main:push({
        type = MessageType.ERROR,
        reason = "Unable to create or load save: " .. reason
    })
end

local safe_call = pcall

while true do
    ::next_message::

    -- { type::MessageType, state::Table }
    local message = main_to_worker:demand()

    -- create save
    if message.type == MessageType.CREATE_SAVE then
        -- verify save dir exists every message
        if love.filesystem.getInfo(save_dir) == nil then
            local success = love.filesystem.createDirectory(save_dir)
            if not success then
                push_error("unable to create directory at `" .. appdata_dir .. "/" .. save_dir .. "`")
                goto next_message
            end
        end

        local content, sha256, file_id

        do -- serialize data
            if type(message.state) ~= "table" then
                push_error("message.data is not a table")
            end

            local success, content_or_error = safe_call(serialize, message.state)
            if not success then
                push_error("failed to serialize message.data")
                goto next_message
            else
                content = content_or_error
            end
        end

        if not string.match(content, "^return") then
            content = "return " .. content
        end

        do -- verify load integrity
            local chunk, error_maybe = _G.loadstring(content)
            if chunk == nil then
                push_error("serialized data is not valid lua code: " .. error_maybe)
                goto next_message
            end
        end

        do -- hash serialization
            local success, hash_or_error = safe_call(hash_string, content)
            if not success then
                push_error("failed to hash save content")
                goto next_message
            else
                sha256 = hash_or_error
            end
        end

        do -- get newest file to generate file id
            local max_i = 0
            for file in values(love.filesystem.getDirectoryItems(save_dir)) do
                local success, i_or_error = safe_call(save_id_to_index, file)
                if not success then
                    push_error("failed to converted file `" .. file .. "` to save id")
                    goto next_message
                end

                if success and i_or_error ~= nil then -- nil if foreign file is matched
                    max_i = math.max(max_i, i_or_error)
                end
            end

            local success, id_or_error = safe_call(index_to_save_id, max_i + 1)
            if not success then
                push_error("failed to convert new index to file id")
                goto next_message
            else
                file_id = id_or_error
            end
        end

        do -- "encrypt" hash
            local success, hash_or_error = safe_call(encrypt_hash, sha256)
            if not success then
                push_error("failed to encrypt save file hash")
                goto next_message
            else
                sha256 = hash_or_error
            end
        end

        do -- encode lua table
            local success, encoded_or_error = safe_call(base64_encode, content)
            if not success then
                push_error("failed to base64 encode: " .. encoded_or_error)
                goto next_message
            else
                content = encoded_or_error
            end
        end

        do -- package string and write
            content = sha256 .. content -- first 64 chars are hash, followed by lua code
            local path = save_dir .. "/" .. file_id
            if not (love.filesystem.getInfo(save_dir .. "/" .. file_id) == nil) then
                push_error("file id generation failed, file `" .. file_id .. "` already exists")
                goto next_message
            end

            local success, error_maybe = love.filesystem.write(path, content)
            if not success then
                push_error("failed to write file to `" .. path .. "`: " .. error_maybe)
                goto next_message
            else
                worker_to_main:push({
                    type = MessageType.CREATE_SAVE_SUCCESS,
                    path = appdata_dir .. "/" .. path
                })
            end
        end
    elseif message.type == MessageType.LOAD_SAVE then
        local to_load_id, to_load_content, to_load_hash

        -- list save files in order
        local i_to_file_id = {}
        for file in values(love.filesystem.getDirectoryItems(save_dir)) do
            local success, i_or_error = safe_call(save_id_to_index, file)
            if not success then
                push_error("failed to converted file `" .. file .. "` to save id")
                goto next_message
            end

            if success and i_or_error ~= nil then -- nil if foreign file is matched
                table.insert(i_to_file_id, { i = i_or_error, file_id = file })
            end
        end

        table.sort(i_to_file_id, function(a, b)
            return a.i > b.i
        end)
        
        -- try save files in order until one is not corrupted, or we run out
        local current_i = 1
        local max_i = table.sizeof(i_to_file_id)
        local error_postfix = ". Trying next most recent save file..."
        while current_i <= max_i do

            to_load_id = i_to_file_id[current_i].file_id
            if to_load_id == nil then
                push_error("save directory `" .. appdata_dir .. "/" .. save_dir .. "` does not contain any files")
                goto next_message -- fatal
            end

            local current_path, current_hash, content, encoded_content, true_hash

            do -- load file
                local content, size_or_error = love.filesystem.read(save_dir .. "/" .. to_load_id)
                if content == nil then
                    push_error("failed to load save at `" .. appdata_dir .. "/" .. save_dir .. "/" .. to_load_id .. "`: " .. size_or_error .. error_postfix)
                    goto next_file
                else
                    to_load_content = content
                end
            end
            
            -- load hash
            current_path = save_dir .. "/" .. to_load_id
            current_hash = utf8.sub(to_load_content, 1, 64)
            encoded_content = utf8.sub(to_load_content, 65, #to_load_content)

            -- unencode
            do
                local success, content_or_error = safe_call(base64_decode, encoded_content)
                if success == false then
                    push_error("failed to load save at `" .. appdata_dir .. "/" .. save_dir .. "/" .. to_load_id .. "`: " .. content_or_error .. error_postfix)
                    goto next_file
                else
                    content = content_or_error
                end
            end

            -- check if hash is corruped
            if not is_valid_hash(current_hash) then
                push_error("hash `" .. current_hash .."` of file at `" .. current_path .. "` is corrupted, failed could not be loaded" .. error_postfix)
                goto next_file
            end

            do -- decrypt hash
                local success, hash_or_error = safe_call(decrypt_hash, current_hash)
                if not success then
                    push_error("failed to decrypt save file hash" .. error_postfix)
                    goto next_file
                else
                    current_hash = hash_or_error
                end
            end

            -- hash rest of file
            do
                local success, content_hash_or_error = safe_call(hash_string, content)
                if not success then
                    push_error("failed to hash content when loading file at `" .. current_path .. "`" .. error_postfix)
                    goto next_file
                else
                    true_hash = content_hash_or_error
                end
            end

            -- check if hashes match
            if current_hash ~= true_hash then
                push_error("hash of file at `" .. current_path .. "` does not match it's contents, it may have been edited or otherwise corrupted" .. error_postfix)
                goto next_file
            end

            -- check if rest of file is valid lua
            do
                local chunk, error_maybe = _G.loadstring(content)
                if chunk == nil then
                    push_error("content of file at `" .. current_path .. "` was corrupted, it could not be loaded" .. error_postfix)
                    goto next_file
                end

                local success, error_state = safe_call(chunk)
                if not success then
                    push_error("error when loading file at `" .. appdata_dir .. "/" .. current_path .. "`: " .. error_state .. error_postfix)
                    goto next_file
                else
                    worker_to_main:push({
                        type = MessageType.LOAD_SAVE_SUCCESS,
                        path = appdata_dir .. "/" .. current_path,
                        state = error_state
                    })
                    break
                end
            end
            
            ::next_file::
            current_i = current_i + 1
        end

        if current_i > max_i then
            -- no viable file
            push_error("no uncorrupted save file in `" .. appdata_dir .. "/" .. save_dir)
            goto next_message -- fatal
        end
    elseif message.type == MessageType.SHUTDOWN then
        return
    else
        -- unhandled message
        worker_to_main:push({
            type = MessageType.ERROR,
            reason = "In game_state_save_worker: message type `" .. tostring(message.type) .. "` unhandled"
        })
    end
end
