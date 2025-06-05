require "common.common"
require "love.filesystem"
require "love.math"

local main_to_worker, worker_to_main, MessageType = ...

local appdata_dir = love.filesystem.getAppdataDirectory()
local save_dir = "/saves"
local watchdog_path = save_dir .. "/watchdog"
local save_filename_pattern = "^_(%d+)$"

local index_to_id = function(x)
    local out = tostring(x)
    while #out < 16 do
        out = "0" .. out
    end
    return "_" .. out
end


while true do
    local message = main_to_worker:demand()

    -- { type, state }
    if message.type == MessageType.CREATE_SAVE then

        -- if directory does not exist, try to create it
        if love.filesystem.getInfo(save_dir) == nil then
            do
                local success = love.filesystem.createDirectory(save_dir)
                if not success then
                    worker_to_main:push({
                        type = MessageType.ERROR,
                        reason = "In game_state_save_worker: unable to create directory at `" ..  appdata_dir .. save_dir .. "`"
                    })
                end
            end
        end

        -- read or create watchdog
        if love.filesystem.getInfo(watchdog_path) == nil then
            local n_saves = 0
            local save_id_to_sha_hash = {}
            for filename in values(love.filesystem.getDirectoryItems(save_dir)) do
                local id = string.match(filename, save_filename_pattern)
                if id ~= nil then
                    local save_file_path = save_dir .. "/" .. filename
                    local save_file, error_maybe = love.filesystem.openFile(save_file_path, "r")
                    if error_maybe ~= nil then
                        worker_to_main:push({
                            type = MessageType.ERROR,
                            reason = "In game_state_save_worker: unable to open save file at  `" ..  appdata_dir .. save_file_path .. "`: " .. error_maybe
                        })
                    else
                        local content = save_file:read()
                        local hash = string.sha256(content)
                        save_id_to_sha_hash[id] = hash
                        n_saves = n_saves + 1
                        save_file:close()
                    end
                end
            end

            local watchdog, error_maybe = love.filesystem.openFile(watchdog_path, "w")
            if error_maybe ~= nil then
                worker_to_main:push({
                    type = MessageType.ERROR,
                    reason = "In game_state_save_worker: unable to open watchdog at `" .. appdata_dir .. watchdog_path .. "`: " .. error_maybe
                })
                goto error_occurred
            end

            -- initialize watchdog from already existing saves
            watchdog:write(tostring(n_saves) .. "\n") -- line 1: number of saves in directory
            for id, has in pairs(save_id_to_sha_hash) do
                watchdog:write(tostring(id) .. " = " .. save_id_to_sha_hash) -- line 1+n: save id to sha256
            end

            watchdog:close()
        end

        -- access watchdog
        local watchdog, error_maybe = love.filesystem.openFile(watchdog_path, "r")
        if error_maybe ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                reason = "In game_state_save_worker: unable to open watchdog at `" .. appdata_dir .. watchdog_path .. "`: " .. error_maybe
            })
            goto error_occurred
        end

        -- get current index
        local index = string.match(watchdog:read(), "^(%d+)\n")
        if index == nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                reason = "In game_state_save_worker: unable to open watchdog at `" .. appdata_dir .. watchdog_path .. ": first line is corrupted"
            })
            goto error_occurred
        end

        index = index + 1
        local new_id = index_to_id(index)
        local new_content = serialize(message.state)
        local new_hash = string.sha256(new_content)

        -- write new save_file
        local save_file, error_maybe = love.filesystem.openFile(save_dir .. "/" .. new_id, "w")
        if error_maybe ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                reason = "In game_state_save_worker: unable to open save file at `" .. appdata_dir .. "/" .. new_id .. "` for writing: " .. error_maybe
            })
            goto error_occurred
        end

        save_file:write(new_content)
        save_file:close()

        -- replace first line with new save file count
        local _, error_maybe = watchdog:open("r")
        if error_maybe ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                reason = "In game_state_save_worker: unable to open watchdog at `" .. appdata_dir .. watchdog_path .. "` for writing: " .. error_maybe
            })
            goto error_occurred
        end

        local watchdog_content = {} -- lines
        for line in watchdog:lines() do
            table.insert(watchdog_content)
        end

        watchdog_content[1] = tostring(index) .. "\n"
        table.insert(watchdog_content, tostring(new_id) .. " = " .. new_hash .. "\n")

        -- append new sha hash
        local _, error_maybe = watchdog:open("w")
        if error_maybe ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                reason = "In game_state_save_worker: unable to open watchdog at `" .. appdata_dir .. watchdog_path .. "` for appending: " .. error_maybe
            })
            goto error_occurred
        end

        for lines in values(watchdog_content) do
            watchdog:write(lines)
        end
        watchdog:close()

        worker_to_main:push({
            type = MessageType.SUCCESS,
            path = save_dir .. "/" .. new_id
        })

        ::error_occurred::
    end
end