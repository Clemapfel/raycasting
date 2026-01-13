require "common.player"
require "common.input_manager"
require "common.path"

require "overworld.player_recorder_body"

rt.settings.overworld.player_recorder = {
    delta_time_step_factor = 0.5,
    correction_threshold = 1 / 3 * rt.settings.player.radius, -- pixels

    path_directory = "assets/paths",
    path_directory_alias = "paths"
}

--- @class ow.PlayerRecorder
ow.PlayerRecorder = meta.class("PlayerRecorder")

local _STATE_IDLE = "idle"
local _STATE_RECORDING = "recording"
local _STATE_PLAYBACK = "playback"

--- @brief
function ow.PlayerRecorder:instantiate(stage, scene, x, y, is_collidable)
    if is_collidable == nil then is_collidable = false end
    meta.assert(stage, ow.Stage, scene, ow.OverworldScene, x, "Number", y, "Number", is_collidable, "Boolean")

    self._stage = stage
    self._scene = scene
    self._player = scene:get_player()

    -- recording
    self._position_data = {}
    self._is_bubble_data = {}
    self._path_duration = 0

    -- playback
    self._path_elapsed = 0

    self._state = _STATE_IDLE

    self._body = ow.PlayerRecorderBody(self._stage, self._scene)
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

    table.insert(self._position_data, px)
    table.insert(self._position_data, py)
    table.insert(self._is_bubble_data, self._player:get_is_bubble())
    self._path_duration = self._path_duration + step
end

--- @brief
function ow.PlayerRecorder:record()
    if self._state == _STATE_RECORDING then return end
    self._state = _STATE_RECORDING

    self._path_duration = 0
    self._position_data = {}
    self._is_bubble_data = {}
    self._recording_elapsed = 0
    self._path = nil
    self._body:get_physics_body():set_is_enabled(false)
end

--- @brief
function ow.PlayerRecorder:play()
    self._state = _STATE_PLAYBACK

    if self._path == nil then
        self._path = rt.Path(self._position_data)
    end

    self._path_elapsed = 0
    self._body:initialize(self._path:at(0))
    self._body:get_physics_body():set_is_enabled(true)
end

--- @brief
function ow.PlayerRecorder:update(delta)
    local step = rt.SceneManager:get_timestep() * rt.settings.overworld.player_recorder.delta_time_step_factor

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
        local n = #self._is_bubble_data
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

            local b0 = self._is_bubble_data[i0]
            local b1 = self._is_bubble_data[i1]

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
    --[[
    if self._state == _STATE_PLAYBACK then
        love.graphics.setColor(1, 1, 1, 1)
        self._body:draw()
    end

    if self._path ~= nil then
        love.graphics.line(self._path:get_points())
    end
    ]]

    self._body:get_physics_body():draw()
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

local _value_separator = " "
local _line_separator = "\n"

local _string_to_boolean = function(str)
    if str == "1" then
        return true
    elseif str == "0" then
        return false
    else
        rt.error("In ow.PlayerRecorder.import_from_string: string contains `", str, "` for boolean field, which is not `0` or `1`")
        return
    end
end

local _string_to_number = function(str)
    local success, number_or_error = pcall(tonumber, str)
    if not success or number_or_error == nil then
        rt.error("In ow.PlayerRecorder.import_from_string: string contains `", str, "` which is not a number")
        return
    else
        return number_or_error
    end
end

local _number_to_string = function(number)
    return string.format("%.3f", number)
end

local _boolean_to_string = function(b)
    return ternary(b, "1", "0")
end

--- @brief
function ow.PlayerRecorder:export_to_string()
    local points = self._path:get_points()
    rt.assert(#self._is_bubble_data == #points / 2, #self._is_bubble_data, #points)

    local to_concat = {}
    local bubble_i = 1
    for i = 1, #points, 2 do
        local x = _number_to_string(points[i+0])
        local y = _number_to_string(points[i+1])
        local is_bubble = _boolean_to_string(self._is_bubble_data[bubble_i])

        table.insert(to_concat,
            table.concat({ x, y, is_bubble }, _value_separator)
        )
        bubble_i = bubble_i + 1
    end

    table.insert(to_concat, tostring(self._path_duration))
    return table.concat(to_concat, _line_separator)
end

--- @brief
function ow.PlayerRecorder:import_from_string(to_import_from, origin_x, origin_y, interpolate, loop)
    local separated = { string.split(to_import_from, "\n") }
    local duration = _string_to_number(separated[#separated]) -- validate duration too
    if duration == nil then return end

    -- last number is path duration
    table.remove(separated, #separated)

    local points, bubble_data = {}, {}
    for line_i, line in ipairs(separated) do
        local parts = { string.split(line, _value_separator) }

        if #parts ~= 3 then
            rt.error("In ow.PlayerRecorder.import_from_string: line ", line_i,
                " has ", #parts, " values instead of 3")
            return
        end

        local x, y, is_bubble = parts[1], parts[2], parts[3]

        x = _string_to_number(x)
        y = _string_to_number(y)
        is_bubble = _string_to_boolean(is_bubble)

        table.insert(points, x)
        table.insert(points, y)
        table.insert(bubble_data, is_bubble)
    end

    -- translate to new origin
    if origin_x ~= nil or origin_y ~= nil then
        meta.assert_typeof(origin_x, "Number", 2)
        meta.assert_typeof(origin_y, "Number", 3)

        local start_x, start_y = points[1], points[2]
        for i = 1, #points, 2 do
            local x, y = points[i+0], points[i+1]
            points[i+0] = x - start_x + origin_x
            points[i+1] = y - start_y + origin_y
        end
    end

    if self._path == nil then
        self._path = rt.Path(points)
    else
        self._path:create_from(points)
    end

    self._path_elapsed = 0
    self._path_duration = duration
    self._is_bubble_data = bubble_data
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
