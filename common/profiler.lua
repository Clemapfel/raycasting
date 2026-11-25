rt.settings.profiler = {
    n_measurements = 10000, -- how many to keep
    reference_duration = 1 / 60,
    out_folder = "profile",
    whitelist = {
        "triangulate"
    }
}

rt.Profiler = meta.class("Profile")

--- @brief
function rt.Profiler:instantiate()
    self._data = {} -- Table<String, { measurements, n, sum }
    self._frame_data = {} -- Table<String, { measurements, n, sum, frame_i, frame_sum }
    self._stack = {} -- Stack<{ start, time, frame_i }>
    self._is_recording = false
end

--- @brief
function rt.Profiler:start_region(region)
    meta.typecheck(region, mt.String)
    if self._is_recording == false then return end

    table.insert(self._stack, {
        start = love.timer.getTime(),
        time = 0,
        frame_i = rt.SceneManager:get_frame_index()
    })
end

--- @brief
function rt.Profiler:end_region(region)
    local end_time = love.timer.getTime()

    meta.typecheck(region, mt.String)
    if self._is_recording == false then return end

    local stack = self._stack
    local n = #stack
    if n == 0 then return end

    local frame = table.remove(stack)
    local total = end_time - frame.start

    if n > 1 then
        local parent = stack[n - 1]
        parent.time = parent.time + total
    end

    local duration = total - frame.time
    self:notify(region, duration)
    self:_notify_frame(region, frame.frame_i, duration)
end

local function _push(entry, duration)
    entry.measurements:push_back(duration)
    entry.sum = entry.sum + duration
    entry.n = entry.n + 1

    if entry.n > rt.settings.profiler.n_measurements then
        local front = entry.measurements:pop_front()
        entry.sum = entry.sum - front
        entry.n = entry.n - 1
    end
end

--- @brief
function rt.Profiler:notify(region, duration)
    meta.typecheck(region, mt.String, duration, mt.Number)
    if self._is_recording == false then return end

    local entry = self._data[region]
    if entry == nil then
        entry = {
            measurements = rt.LinkedList(),
            n = 0,
            sum = 0
        }
        self._data[region] = entry
    end

    _push(entry, duration)
end

function rt.Profiler:_notify_frame(region, frame_i, duration)
    local entry = self._frame_data[region]
    if entry == nil then
        entry = {
            measurements = rt.LinkedList(),
            n = 0,
            sum = 0,
            frame_i = frame_i,
            frame_sum = 0
        }
        self._frame_data[region] = entry
    end

    if entry.frame_i ~= frame_i then
        _push(entry, entry.frame_sum)
        entry.frame_i = frame_i
        entry.frame_sum = 0
    end

    entry.frame_sum = entry.frame_sum + duration
end

local function _median(t)
    table.sort(t)
    local n = #t
    if n % 2 == 1 then
        return t[(n + 1) / 2]
    else
        return (t[n / 2] + t[n / 2 + 1]) / 2
    end
end

local function _stddev(t, mean)
    local n = #t
    local sum = 0
    for i = 1, n do
        local delta = t[i] - mean
        sum = sum + delta * delta
    end
    return math.sqrt(sum / n)
end

function rt.Profiler:report()
    local rows = {}
    local dur = rt.settings.profiler.reference_duration
    for region, entry in pairs(self._data) do
        local data = {}
        for value in entry.measurements:iterate() do
            table.insert(data, value)
        end

        local mean = entry.sum / entry.n
        local median = _median(data)
        local min, max = data[1], data[#data]
        local stddev = _stddev(data, mean)

        local row = {}
        row.region = region
        row.mean = mean / dur
        row.median = median / dur
        row.stddev = stddev / dur
        row.min = min / dur
        row.max = max / dur

        row.frame_mean = 0
        row.frame_max = 0
        local frame_entry = self._frame_data[region]
        if frame_entry ~= nil and frame_entry.n > 0 then
            local frame_max = 0
            for value in frame_entry.measurements:iterate() do
                frame_max = math.max(frame_max, value)
            end
            row.frame_mean = (frame_entry.sum / frame_entry.n) / dur
            row.frame_max = frame_max / dur
        end

        local threshold = 0.0001
        if row.max > threshold
            or row.mean > threshold
            or row.median > threshold
            or row.frame_max > threshold
        then
            table.insert(rows, row)
        end
    end

    table.sort(rows, function(a, b)
        return a.frame_max > b.frame_max
    end)

    local format = function(x)
        return string.format("%.4f", x)
    end

    local max_ws = {
        region = 0,
        mean = 0,
        median = 0,
        stddev = 0,
        min = 0,
        max = 0,
        frame_mean = 0,
        frame_max = 0
    }

    for _, row in ipairs(rows) do
        row.region = tostring(row.region)
        row.mean = format(row.mean)
        row.median = format(row.median)
        row.stddev = format(row.stddev)
        row.min = format(row.min)
        row.max = format(row.max)
        row.frame_mean = format(row.frame_mean)
        row.frame_max = format(row.frame_max)

        max_ws.region = math.max(max_ws.region, string.len(row.region))
        max_ws.mean = math.max(max_ws.mean, string.len(row.mean))
        max_ws.median = math.max(max_ws.median, string.len(row.median))
        max_ws.stddev = math.max(max_ws.stddev, string.len(row.stddev))
        max_ws.min = math.max(max_ws.min, string.len(row.min))
        max_ws.max = math.max(max_ws.max, string.len(row.max))
        max_ws.frame_mean = math.max(max_ws.frame_mean, string.len(row.frame_mean))
        max_ws.frame_max = math.max(max_ws.frame_max, string.len(row.frame_max))
    end

    local header = { "region", "frame_max", "max", "median", "mean", "stddev", "min", "frame_mean" }
    for _, label in ipairs(header) do
        max_ws[label] = math.max(max_ws[label], string.len(label))
    end

    local h = "|"
    local v = "-"
    local hv = "+"

    local res  = {}

    local pad = function(str, width, left)
        local fill = string.rep(" ", width - string.len(str))
        if left then
            return str .. fill
        end
        return fill .. str
    end

    local separator = hv
    for _, label in ipairs(header) do
        separator = separator .. string.rep(v, max_ws[label] + 2) .. hv
    end

    local line = h
    for _, label in ipairs(header) do
        line = line .. " " .. pad(label, max_ws[label], true) .. " " .. h
    end

    table.insert(res, separator)
    table.insert(res, line)
    table.insert(res, separator)

    for _, row in ipairs(rows) do
        line = h
        for _, label in ipairs(header) do
            line = line .. " " .. pad(row[label], max_ws[label], label == "region") .. " " .. h
        end
        table.insert(res, line)
    end

    table.insert(res, separator)
    local out = table.concat(res, "\n")

    local out_dir = rt.settings.profiler.out_folder
    if bd.is_file(out_dir) then
        rt.error("In rt.Profiler: object at `", out_dir, "` is not a directory")
    elseif not bd.exists(out_dir) then
        bd.create_directory(out_dir)
    end

    local filename = bd.join_path(out_dir, "profile_" .. string.unique_timestamp() .. ".txt")
    bd.write_file(filename, out)
    rt.log("wrote profiling session to `", filename, "`")
    return out
end

--- @brief
function rt.Profiler:is_on_whitelist(name)
    meta.typecheck(name, mt.String)
    for _, x in ipairs(rt.settings.profiler.whitelist) do
        if name == x then
            return true
        end
    end

    return false
end

--- @brief
function rt.Profiler:set_is_recording(b)
    self._is_recording = b
    self._stack = {}

    if b == true then
        rt.log("In rt.Profiler: profiler is now recording")
    else
        rt.log("In rt.Profiler: profiler is no longer recording")
    end
end

--- @brief
function rt.Profiler:get_is_recording()
    return self._is_recording
end

rt.Profiler = meta.as_singleton(rt.Profiler)