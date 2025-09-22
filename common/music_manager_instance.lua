require "common.filesystem"
require "common.music_manager_playback"
require "common.smoothed_motion_nd"
require "common.smoothed_motion_1d"

rt.settings.music_manager = {
    config_directory = "assets/music",
    cross_fade_speed = 2, -- fraction
    pause_speed = 3, -- fraction
    volume_eps = 0.01
}

--[[
config:
    id: String optional
    loop: Table<Pair<Number, Number>> in seconds, optional
]]--

--- @class rt.MusicManagerInstance
rt.MusicManagerInstance = meta.class("MusicManagerInstance")

local _STATE_PLAYING = 1
local _STATE_PAUSED = 2
local _STATE_STOPPED = 0

--- @brie
function rt.MusicManagerInstance:instantiate()
    self._id_to_entry = {}
    self._state = _STATE_STOPPED
    self._active_id = nil

    self._volume = 1
    self._mixer = rt.SmoothedMotionND(rt.settings.music_manager.cross_fade_speed)
    -- n-dimension interpolate between n sources, ids keep track of active sources, integrates to 1

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
            rt.warning("In rt.MusicManagerInstance: ignoring file at `" .. directory_path .. "`: not a directory")
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
                rt.critical("In rt.MusicManagerInstance: directory at `" .. directory_path .. "` does not have a playable sound file")
            end

            local decoder = love.sound.newDecoder(mp3)
            local entry = {
                id = directory_name,
                filename = mp3,
                config_filename = lua,
                decoder = decoder,
                loop = { 0, decoder:getDuration() }
            }

            if lua ~= nil then
                local config = bd.load(lua)
                local get = function(id, type)
                    local out = config[id]
                    if out ~= nil then
                        if not meta.typeof(id) == type then
                            rt.error("In rt.MusicManagerInstance: config at `" .. lua .. "` has entry `" .. id .. "` which is not of type `" .. type .. "`")
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
                        rt.error("In rt.MusicManagerInstance: config at `" .. lua .. "` has entry `loop`, but it is not a table with 2 numerical entries")
                    end

                    if loop[1] < 0 or loop[1] > decoder:getDuration() or loop[2] < 0 or loop[2] > decoder:getDuration() then
                        rt.error("In rt.MusicManagerInstance: config at `" .. lua .. "` has entry `loop`, its timestampes are outside `0, " .. decoder:getDuration() .. "`, the duration of the file at `" .. mp3 .. "`")
                    end

                    entry.loop = loop
                end
            end

            self._id_to_entry[entry.id] = entry
        end
    end)
end

--- @brief
function rt.MusicManagerInstance:update(delta)
    self._mixer:update(delta)

    local done = {}
    for id in values(self._mixer:get_ids()) do
        local entry = self._id_to_entry[id]
        entry.source:update(delta)

        local volume = self._mixer:get_dimension(id)
        entry.source:set_volume(volume * self._volume)
        if volume < rt.settings.music_manager.volume_eps then
            table.insert(done, entry)
        else
            entry.source:play()
        end
    end

    for entry in values(done) do
        if self._state == _STATE_STOPPED then
            entry.source:stop()
            self._mixer:remove_dimension(entry.id)
        else
            entry.source:pause()
        end
    end
end

--- @brief
function rt.MusicManagerInstance:_get_entry(id, scope)
    local entry = self._id_to_entry[id]
    if entry == nil then
        rt.critical("In rt.MusicManagerInstance." .. scope .. ": no music with id `" .. id .. "` available")
        return nil
    else
        return entry
    end
end

--- @brief crossfade to song immediately
function rt.MusicManagerInstance:play(id, restart)
    if restart == nil then restart = false end
    local entry = self:_get_entry(id, "play")
    if entry == nil then return end

    if self._mixer:get_target_dimension() == entry.id then
        if restart == true then
            entry.source:stop()
        end
        entry.source:play()
        return
    end

    if entry.source == nil then
        entry.source = rt.MusicManagerPlayback(entry.decoder)
        entry.source:set_loop_bounds(table.unpack(entry.loop))
        entry.source:set_volume(0)
    elseif restart then
        entry.source:stop()
    end

    entry.source:play()

    self._state = _STATE_PAUSED
    self._active_id = entry.id
    self._mixer:set_target_dimension(entry.id)
end

--- @brief
function rt.MusicManagerInstance:pause()
    self._state = _STATE_PAUSED
    self._mixer:stop()
end

--- @brief
function rt.MusicManagerInstance:unpause()
    self._state = _STATE_PLAYING
    if self._active_id ~= nil then
        self._mixer:set_target_dimension(self._active_id)
    end
end

--- @brief
function rt.MusicManagerInstance:stop()
    self._state = _STATE_STOPPED
    self._mixer:stop()
end

--- @brief
function rt.MusicManagerInstance:get_is_paused()
    return self._state == _STATE_PAUSED or self._state == _STATE_STOPPED
end

--- @brief
function rt.MusicManagerInstance:set_volume(volume)
    self._volume = volume
end
