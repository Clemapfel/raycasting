require "common.player"
require "common.input_manager"
require "common.path"
require "common.version"
require "common.byte_data"

require "overworld.player_recorder_body"

rt.settings.overworld.player_recorder = {
    delta_time_step_factor = 0.5,
    correction_threshold = 1 / 3 * rt.settings.player.radius, -- pixels

    path_directory = "assets/paths",
    path_directory_alias = "paths",
    signature = "THIS_IS_VIRUS_ENJOY_BEING_PWNED",
    fps = 120
}

--- @class ow.PlayerRecorder
ow.PlayerRecorder = meta.class("PlayerRecorder")

local _STATE_IDLE = "idle"
local _STATE_RECORDING = "recording"
local _STATE_PLAYBACK = "playback"

--- @brief
function ow.PlayerRecorder:instantiate(stage, scene, x, y, is_collidable)
    if is_collidable == nil then is_collidable = false end
    meta.assert(stage, ow.Stage, scene, ow.OverworldScene, x, mt.Number, y, mt.Number, is_collidable, mt.Boolean)

    self._stage = stage
    self._scene = scene
    self._player = scene:get_player()

    -- recording
    self._last_x, self._last_y = nil, nil
    self._nodes = {} -- recorded player path
    self._path_duration = 0
    self._path_time_step = 1 / rt.settings.overworld.player_recorder.fps

    -- playback
    self._path_elapsed = 0

    self._state = _STATE_IDLE

    self._body = ow.PlayerRecorderBody(self._scene, self._stage)
    self._body:initialize(
        x, y,
        b2.BodyType.KINEMATIC,
        is_collidable
    )
    self._body:get_physics_body():set_is_enabled(false)
end

--- @brief
function ow.PlayerRecorder:_snapshot(step)
    local px, py = self._player:get_physics_body():get_position()

    if self._player:get_is_disabled() then
        px, py = self._last_x or px, self._last_y or py
    end

    table.insert(self._nodes, {
        x = px,
        y = py,
        is_bubble = self._player:get_is_bubble()
    })
    self._path_duration = self._path_duration + step

    self._last_x = px
    self._last_y = py
end

--- @brief
function ow.PlayerRecorder:record()
    if self._state == _STATE_RECORDING then return end
    self._state = _STATE_RECORDING

    self._last_x, self._last_y = self._player:get_physics_body():get_position()

    self._path_duration = 0
    self._nodes = {}
    self._recording_elapsed = 0
    self._path = nil
    self._body:get_physics_body():set_is_enabled(false)
end

local generate_signature = function()
    local out = string.reverse(
        string.sha256(rt.settings.overworld.player_recorder.signature)
    )

    local hex_chars = "0123456789abcdef"
    out = out:gsub(".", function(c, i) end)

    local chars = {}
    for i = 1, #out do
        local c = out:sub(i, i)
        local pos = hex_chars:find(c, 1, true)
        local new_pos = ((pos - 1 + i) % 16) + 1
        chars[i] = hex_chars:sub(new_pos, new_pos)
    end

    return table.concat(chars)
end

--- @brief
function ow.PlayerRecorder:play()
    self._state = _STATE_PLAYBACK

    local data = {}
    for _, node in ipairs(self._nodes) do
        table.insert(data, node.x)
        table.insert(data, node.y)
    end

    if self._path == nil then
        self._path = rt.Path(data)
    else
        self._path:create_from(data)
    end

    self._path_elapsed = 0
    self._body:initialize(self._path:at(0))
    self._body:get_physics_body():set_is_enabled(true)
end

--- @brief
function ow.PlayerRecorder:update(delta)
    local step = self._path_time_step * rt.settings.overworld.player_recorder.delta_time_step_factor

    if self._state == _STATE_IDLE then return end
    -- noop
    if self._state == _STATE_RECORDING then
        local n_steps = 0

        self._recording_elapsed = self._recording_elapsed + delta
        while self._recording_elapsed > step do
            self:_snapshot(step)
            self._recording_elapsed = self._recording_elapsed - step

            n_steps = n_steps + 1
            if n_steps > 16 then break end -- for safety
        end
    elseif self._state == _STATE_PLAYBACK then
        local t = self._path_elapsed / self._path_duration
        if t == 0 or t >= 1 then
            self._path_elapsed = 0
            self._body:set_position(self._path:at(0))
        end

        local t_next = math.clamp((self._path_elapsed + delta) / self._path_duration, 0, 1)
        local x1, y1 = self._path:at(t)
        local x2, y2 = self._path:at(t_next)
        self._body:set_velocity(
            (x2 - x1) / delta,
            (y2 - y1) / delta
        )

        -- find closest two bubble samples, interpolate based on elapsed time
        local n = #self._nodes
        if n > 0 then
            -- Convert elapsed time to sample index (floating point)
            local sample_f = self._path_elapsed / step
            local i0 = math.floor(sample_f) + 1
            local i1 = i0 + 1

            i0 = math.clamp(i0, 1, n)
            i1 = math.clamp(i1, 1, n)

            -- Calculate interpolation factor based on position between samples
            local alpha = sample_f - (i0 - 1)
            alpha = math.clamp(alpha, 0, 1)

            local b0 = self._nodes[i0].is_bubble
            local b1 = self._nodes[i1].is_bubble

            local is_bubble
            if b0 == b1 then
                is_bubble = b0
            else
                is_bubble = ternary(alpha >= 0.5, b1, b0)
            end

            self._body:set_is_bubble(is_bubble)
        end

        self._body:update(delta)
        self._path_elapsed = self._path_elapsed + delta

        -- manually set position to prevent numerical drift from velocity
        if math.distance(x1, y1, self._body:get_physics_body():get_position()) > rt.settings.overworld.player_recorder.correction_threshold then
            self._body:set_position(x1, y1)
        end
    end
end

--- @brief
function ow.PlayerRecorder:draw()
    if self._state == _STATE_PLAYBACK then
        love.graphics.setColor(1, 1, 1, 1)
        self._body:draw()
    end

    if self._path ~= nil then
        love.graphics.line(self._path:get_points())
    end
end

--- @brief
function ow.PlayerRecorder:get_physics_body()
    return self._body:get_physics_body()
end

do -- mount paths folder
    require "common.filesystem"
    local source_prefix = bd.normalize_path(love.filesystem.getSource())
    bd.mount_path(
        bd.join_path(source_prefix, rt.settings.overworld.player_recorder.path_directory),
        rt.settings.overworld.player_recorder.path_directory_alias
    )
end

do
    local n_digits_after_decimal = 2
    local float_to_int32 = function(t)
        local result = math.floor(t * 10 ^ n_digits_after_decimal)
        if result < -1 * (2 ^ 32) or result > 2 ^ 31 -1 then
            rt.error("In PlayerRecorder: unable to represent coordinate `", t, "` as an int32")
        end
        return result
    end

    local int32_to_float = function(t)
        return t / 10 ^ n_digits_after_decimal
    end

    -- data formats
    local header_format, node_format = {}, {}

    local FLOAT64 = rt.ByteDataFormat.FLOAT64
    local FLOAT32 = rt.ByteDataFormat.FLOAT32
    local INT32 = rt.ByteDataFormat.INT32
    local UINT32 = rt.ByteDataFormat.UINT32
    local INT16 = rt.ByteDataFormat.INT16
    local UINT16 = rt.ByteDataFormat.UINT16
    local INT8 = rt.ByteDataFormat.INT8
    local UINT8 = rt.ByteDataFormat.UINT8
    local STRING = "STRING"

    local functions = rt.ByteData._format_to_getter_setter
    local formats = rt.ByteDataFormat

    local type_to_setter = {
        [FLOAT64] = functions[formats.FLOAT64].set,
        [FLOAT32] = functions[formats.FLOAT32].set,
        [INT32] = functions[formats.INT32].set,
        [UINT32] = functions[formats.UINT32].set,
        [INT16] = functions[formats.INT16].set,
        [UINT16] = functions[formats.UINT16].set,
        [INT8] = functions[formats.INT8].set,
        [UINT8] = functions[formats.UINT8].set,
        [STRING] = "setString"
    }

    local type_to_getter = {
        [FLOAT64] = functions[formats.FLOAT64].get,
        [FLOAT32] = functions[formats.FLOAT32].get,
        [INT32] = functions[formats.INT32].get,
        [UINT32] = functions[formats.UINT32].get,
        [INT16] = functions[formats.INT16].get,
        [UINT16] = functions[formats.UINT16].get,
        [INT8] = functions[formats.INT8].get,
        [UINT8] = functions[formats.UINT8].get,
        [STRING] = "getString"
    }

    local add = function(format, id, type, n_bytes)
        if format.size == nil then format.size = 0 end
        format[id] = {
            offset = format.size,
            id = id,
            type = type,
            setter = type_to_setter[type],
            getter = type_to_getter[type],
            length = n_bytes or 0 -- Store exact byte length for strings
        }

        n_bytes = n_bytes or rt.ByteData.format_to_n_bytes(type)
        format.size = format.size + n_bytes
    end

    local GAME_VERSION_MAJOR = "GAME_VERSION_MAJOR"
    local GAME_VERSION_MINOR = "GAME_VERSION_MINOR"
    local FPS = "FPS"
    local DURATION = "DURATION"
    local TIME = "TIME"
    local N_NODES = "N_NODES"
    local LEVEL_SHA256 = "LEVEL_SHA256"
    local LEVEL_ID = "LEVEL_NAME"
    local SIGNATURE = "SIGNATURE"

    local X_POSITION = "X_POSITION"
    local Y_POSITION = "Y_POSITION"
    local IS_BUBBLE  = "IS_BUBBLE"

    -- header format
    add(header_format, GAME_VERSION_MAJOR, UINT16)
    add(header_format, GAME_VERSION_MINOR, UINT16)
    add(header_format, DURATION, FLOAT64)
    add(header_format, FPS, UINT32) -- path sampled at 1 / FPS
    add(header_format, TIME, UINT32) -- os.time stamp
    add(header_format, N_NODES, UINT32)
    add(header_format, LEVEL_ID, STRING, 64) -- padded level id
    add(header_format, LEVEL_SHA256, STRING, 64) -- sha256 hash
    add(header_format, SIGNATURE, STRING, 64)

    -- node format
    add(node_format, X_POSITION, INT32) -- (int32_t) floor(t * 10e2)
    add(node_format, Y_POSITION, INT32)

    add(node_format, IS_BUBBLE, UINT8) -- 0x0 or 0x1

    --- @brief
    function ow.PlayerRecorder:encode()
        local size = header_format.size + #self._nodes * node_format.size -- number of bytes
        local data = love.data.newByteData(size)

        local set = function(format, id, value, offset)
            local entry = format[id]
            assert(entry ~= nil)
            if entry.type == STRING then
                data[entry.setter](data,
                    value,
                    entry.offset + (offset or 0)
                )
            else
                data[entry.setter](data,
                    entry.offset + (offset or 0),
                    value
                )
            end
        end

        -- write header
        local major, minor = rt.get_version()
        set(header_format, GAME_VERSION_MAJOR, major)
        set(header_format, GAME_VERSION_MINOR, minor)
        set(header_format, DURATION, self._path_duration or 0) -- ADDED
        set(header_format, FPS, math.floor(1 / rt.SceneManager:get_timestep()))
        set(header_format, TIME, os.time())
        set(header_format, N_NODES, #self._nodes)

        local hash = self._stage:get_config_hash()
        assert(#hash == 64, #hash, hash)
        set(header_format, LEVEL_SHA256, hash)
        set(header_format, LEVEL_ID, string.sha256(self._stage:get_id()))

        local signed = generate_signature()
        set(header_format, SIGNATURE, signed)

        -- encode nodes

        local node_offset = header_format.size
        for _, node in ipairs(self._nodes) do
            set(node_format, X_POSITION, float_to_int32(node.x), node_offset)
            set(node_format, Y_POSITION, float_to_int32(node.y), node_offset)
            set(node_format, IS_BUBBLE, ternary(node.is_bubble, 0x1, 0x0), node_offset)

            node_offset = node_offset + node_format.size
        end

        return data:getString()
    end

    --- @brief
    function ow.PlayerRecorder:decode(encoded)
        local data = love.data.newByteData(encoded)

        local get = function(format, id, offset)
            local entry = format[id]
            assert(entry ~= nil)

            if entry.type == STRING then
                return data[entry.getter](data,
                    entry.offset + (offset or 0),
                    entry.length
                )
            else
                return data[entry.getter](data,
                    entry.offset + (offset or 0)
                )
            end
        end

        local major, minor = rt.get_version()
        local encoded_major = get(header_format, GAME_VERSION_MAJOR)
        local encoded_minor = get(header_format, GAME_VERSION_MINOR)
        if encoded_major ~= major or encoded_minor ~= minor then
            rt.warning("In ow.PlayereRecorder.decode: encoded path has version `", encoded_major, ".", encoded_minor, "`, but game is version `", major, ".", minor, "`")
        end

        self._path_duration = get(header_format, DURATION)
        self._path_time_step = 1 / get(header_format, FPS)

        local encoded_signature = get(header_format, SIGNATURE)
        if encoded_signature ~= generate_signature() then
            rt.fatal("In ow.PlayerRecorded.decode: encoded path has invalid signature")
        end

        local encoded_level_id = get(header_format, LEVEL_ID)
        if string.sha256(self._stage:get_id()) ~= encoded_level_id then
            rt.fatal("In ow.PlayerRecorded.decode: encoded path has a level id that is different from the current id")
        end
        
        local encoded_level_hash = get(header_format, LEVEL_SHA256)
        if self._stage:get_config_hash() ~= encoded_level_hash then
            rt.critical("In ow.PlayerRecorder.decode: encoded path uses a different version of the level than is currently active")
        end

        self._nodes = {}

        local n_nodes = get(header_format, N_NODES)
        if n_nodes <= 0 then
            return
        end

        local node_offset = header_format.size


        for i = 1, n_nodes do
            self._nodes[i] = {
                x = int32_to_float(get(node_format, X_POSITION)),
                y = int32_to_float(get(node_format, Y_POSITION)),
                is_bubble = get(node_format, IS_BUBBLE) == 0x1
            }
            node_offset = node_offset + node_format.size
        end

        self._path_elapsed = 0
    end
end

--- @brief
function ow.PlayerRecorder:export(file_name)
    if self._path == nil then
        rt.warning("In ow.PlayerRecorder.export: trying to export to file `", file_name, "`, but no recording is active")
        return
    end

    bd.create_file(
        bd.join_path(rt.settings.overworld.player_recorder.path_directory_alias, file_name),
        self:export_to_string()
    )
end

--- @brief
function ow.PlayerRecorder:import(file_name, origin_x, origin_y)
    local path = bd.join_path(rt.settings.overworld.player_recorder.path_directory_alias, file_name)
    local file = bd.read_file(path)
    if file ~= nil then
        self:import_from_string(file, origin_x, origin_y)
    else
        rt.error("In ow.PlayerRecorder.import: unable to read file at `", path, "`")
    end
end
