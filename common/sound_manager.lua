require "common.filesystem"
require "common.music_manager_playback"
require "common.smoothed_motion_nd"

rt.settings.music_manager = {
    config_directory = "assets/sounds",
    cross_fade_speed = 2, -- fraction
}

--[[
config:
    id: String optional
    loop: Table<Pair<Number, Number>> in seconds, optional
]]--

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")

--- @brie
function rt.SoundManager:instantiate()
    self._id_to_entry = {}

    local _lua_pattern = "%.lua$"
    local function _is_sound_file(filename)
        local extension = string.match(filename, "%.([^%.]+)$") -- extract everything after . before end
        if extension then
            extension = string.lower(extension)
            return extension == "wav"
                or extension == "mp3"
                or extension == "ogg"
                or extension == "oga"
                or extension == "ogv"
                or extension == "abc"
                or extension == "mid"
                or extension == "pat"
                or extension == "flac"
        end
        return false
    end

    bd.apply(rt.settings.music_manager.config_directory, function(directory_path, directory_name)
        if not bd.is_directory(directory_path) then
            rt.warning("In rt.SoundManager: ignoring file at `" .. directory_path .. "`: not a directory")
        else
            -- locate .mp3 and .lua
            local mp3, lua
            bd.apply(directory_path, function(filename)
                if _is_sound_file(filename) then
                    mp3 = filename
                end

                if lua == nil and string.match(filename, _lua_pattern) ~= nil then
                    lua = filename
                end
            end)

            if mp3 == nil then
                rt.critical("In rt.SoundManager: directory at `" .. directory_path .. "` does not have a playable sound file")
            end

            local decoder = love.sound.newDecoder(mp3)
            local entry = {
                id = directory_name,
                decoder = decoder,
                loop = { 0, decoder:getDuration() }
            }

            if lua ~= nil then
                local config = bd.load(lua)
                local get = function(id, type)
                    local out = config[id]
                    if out ~= nil then
                        if not meta.typeof(id) == type then
                            rt.error("In rt.SoundManager: config at `" .. lua .. "` has entry `" .. id .. "` which is not of type `" .. type .. "`")
                        end
                    end

                    return out
                end

                local id = get("id", "String")
                if id ~= nil then
                    entry.id = id
                end

                local loop = get("loop", "Table")
                if loop ~= nil then
                    if #loop ~= 2 then
                        rt.error("In rt.SoundManager: config at `" .. lua .. "` has entry `loop`, but it is not a table with 2 numerical entries")
                    end

                    if loop[1] < 0 or loop[1] > decoder:getDuration() or loop[2] < 0 or loop[2] > decoder:getDuration() then
                        rt.error("In rt.SoundManager: config at `" .. lua .. "` has entry `loop`, its timestampes are outside `0, " .. decoder:getDuration() .. "`, the duration of the file at `" .. mp3 .. "`")
                    end

                    entry.loop = loop
                end
            end

            self._id_to_entry[entry.id] = entry
        end
    end)
end

--- @brief
function rt.SoundManager:update(delta)

end

--- @brief
function rt.SoundManager:_get_entry(id, scope)
    local entry = self._id_to_entry[id]
    if entry == nil then
        rt.critical("In rt.SoundManager." .. scope .. ": no music with id `" .. id .. "` available")
        return nil
    else
        return entry
    end
end

--- @brief crossfade to song immediately
function rt.SoundManager:play(id)
    local entry = self:_get_entry(id, "play")
    if entry == nil then return end
    if entry.source == nil then
        local duration = entry.decoder
        entry.source = love.audio.newSource(entry.decoder)
        entry.source:set_loop_bounds(table.unpack(entry.loop))
        entry.source:set_volume(0)
        entry.source:play()
    end
end

--- @brief
function rt.SoundManager:stop(id)

end

rt.SoundManager = rt.SoundManager() -- singleton instance