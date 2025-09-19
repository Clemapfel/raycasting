require "common.filesystem"

rt.settings.music_manager = {
    config_directory = "assets/music",
}

--[[
config:
    id: String optional
    loop: Table<Pair<Number, Number>> in seconds, optional
]]--

--- @class rt.MusicManager
rt.MusicManager = meta.class("MusicManager")

local _a = true
local _b = false

--- @brie
function rt.MusicManager:instantiate()
    self._id_to_config = {}

    self._active_source_a = nil -- love.QueableSource
    self._active_source_b = nil
    self._active_source_a_or_b = _a

    self._sources = {} -- QueableSourceBuffer

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
            rt.warning("In rt.MusicManager: ignoring file at `" .. directory_path .. "`: not a directory")
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
                rt.critical("In rt.MusicManager: directory at `" .. directory_path .. "` does not have a playable sound file")
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
                            rt.error("In rt.MusicManager: config at `" .. lua .. "` has entry `" .. id .. "` which is not of type `" .. type .. "`")
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
                        rt.error("In rt.MusicManager: config at `" .. lua .. "` has entry `loop`, but it is not a table with 2 numerical entries")
                    end

                    if loop[1] < 0 or loop[1] > decoder:getDuration() or loop[2] < 0 or loop[2] > decoder:getDuration() then
                        rt.error("In rt.MusicManager: config at `" .. lua .. "` has entry `loop`, its timestampes are outside `0, " .. decoder:getDuration() .. "`, the duration of the file at `" .. mp3 .. "`")
                    end

                    entry.loop = loop
                end
            end

            self._id_to_config[entry.id] = entry
        end
    end)
end

--- @brief
function rt.MusicManager:update(delta)

end

--- @brief
function rt.MusicManager:_get_entry(id, scope)
    local entry = self._id_to_config[id]
    if entry == nil then
        rt.critical("In rt.MusicManager." .. scope .. ": no music with id `" .. id .. "` available")
        return nil
    else
        return entry
    end
end

--- @brief crossfade to song immediately
function rt.MusicManager:play(id)
    local entry = self:_get_entry(id, "play")
    if entry == nil then return end

    local sample_rate = entry.decoder:getSampleRate()
    local bit_depth = entry.decoder:getBitDepth()
    local channel_count = entry.decoder:getChannelCount()

    -- use cached source if available
    local sample_rate_entry = self._sources[sample_rate]
    if sample_rate_entry == nil then
        sample_rate_entry = {}
        self._sources[sample_rate] = sample_rate_entry
    end

    local bit_depth_entry = sample_rate_entry[bit_depth]
    if bit_depth_entry == nil then
        bit_depth_entry = meta.make_weak({})
        sample_rate_entry[bit_depth] = bit_depth_entry
    end

    local source = bit_depth_entry[channel_count]
    if source == nil then
        source = love.audio.newQueableSource(
            sample_rate,
            bit_depth,
            channel_count
        )
        bit_depth_entry[channel_count] = source
    end

    if self._active_source_a_or_b == _a then

    end


end

--- @brief
function rt.MusicManager:pause()

end

rt.MusicManager = rt.MusicManager() -- singleton instance