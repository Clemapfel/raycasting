profiler = {}

local _noop = function() end

local _min_duration = 0.01 -- percentage of frame at 60fps

if PROFILE then
    local _is_active = false

    -- Track states per coroutine to avoid stack corruption
    local _co_states = setmetatable({}, { __mode = "k" })
    local _main_state = { id_stack = {}, current_id = "", id_needs_update = true }

    -- Helper to get or initialize the state for the current running thread
    local function get_state()
        local co, is_main = coroutine.running()

        -- In Lua 5.1/LuaJIT, 'co' is nil on the main thread.
        -- In Lua 5.2+, 'is_main' is true.
        if co == nil or is_main then
            return _main_state
        end

        local state = _co_states[co]
        if not state then
            state = {
                id_stack = {},
                current_id = "",
                id_needs_update = true
            }
            _co_states[co] = state
        end

        return state
    end

    local _data_id = {}
    local _data_timestamp = {}
    local _data_duration = {}

    profiler.start = function(reset)
        if _is_active == false and reset == true then
            _data_id = {}
            _data_timestamp = {}
            _data_duration = {}

            -- Clear all coroutine states
            _co_states = setmetatable({}, { __mode = "k" })
            _main_state = { id_stack = {}, current_id = "", id_needs_update = true }
        end

        _is_active = true
    end

    profiler.stop = function()
        _is_active = false
    end

    profiler.push = function(id)
        local state = get_state()
        table.insert(state.id_stack, id)
        state.id_needs_update = true
    end

    profiler.pop = function(id)
        local state = get_state()
        local stack = state.id_stack

        assert(#stack > 0 and stack[#stack] == id, "In profiler.pop: trying to pop id `" .. id .. "`, but it is not currently active")
        table.remove(stack, #stack)
        state.id_needs_update = true
    end

    profiler.notify = function(duration)
        if _is_active then
            if duration < _min_duration then return end

            local state = get_state()

            if state.id_needs_update then
                state.current_id = table.concat(state.id_stack, ">")
                state.id_needs_update = false
            end

            table.insert(_data_id, state.current_id)
            table.insert(_data_timestamp, love.timer.getTime())
            table.insert(_data_duration, duration)
        end
    end

    profiler.get_is_active = function()
        return _is_active == true
    end

    profiler.report = function(min_depth)
        if min_depth == nil then min_depth = 0 end

        if #_data_id == 0 then
            error("In profiler.report: no collected data to report")
        end

        local unified = {}
        local id_to_duration = {}
        for i = 1, #_data_id do
            local id = _data_id[i]
            local duration = _data_duration[i]
            local timestamp = _data_timestamp[i]

            if select(2, string.gsub(id, ">", "")) >= min_depth then
                table.insert(unified, {
                    id = id,
                    timestamp = timestamp,
                    duration = duration
                })

                local entry = id_to_duration[id]
                if entry == nil then
                    entry = {}
                    id_to_duration[id] = entry
                end
                table.insert(entry, duration)
            end
        end

        table.sort(unified, function(a, b)
            return a.timestamp < b.timestamp
        end)

        local total_duration = unified[#unified].timestamp - unified[1].timestamp

        local max_id_width = 0
        local max_mean_width = 0
        local max_median_width = 0
        local max_min_width = 0
        local max_max_width = 0
        local max_stddev_width = 0
        local max_percentage_width = 0

        local normalize = function(x)
            return x / (1 / 60)
        end

        local round = function(x)
            return math.floor(x * 1e6) / 1e6
        end

        local to_print = {}

        for stack_id, durations in pairs(id_to_duration) do
            local n = #durations

            local sorted = {}
            for i = 1, n do
                sorted[i] = normalize(durations[i])
            end
            table.sort(sorted)

            local sum = 0
            for i = 1, n do
                sum = sum + sorted[i]
            end
            local mean = sum / n

            local median
            if n % 2 == 1 then
                median = sorted[(n + 1) / 2]
            else
                local lo = n / 2
                local hi = lo + 1
                median = (sorted[lo] + sorted[hi]) / 2
            end

            local min_value = sorted[1]
            local max_value = sorted[n]

            local variance_sum = 0
            for i = 1, n do
                local diff = sorted[i] - mean
                variance_sum = variance_sum + diff * diff
            end
            local stddev = math.sqrt(variance_sum / n)

            local percentage_sum = 0
            for i = 1, n do
                percentage_sum = percentage_sum + durations[i]
            end
            local percentage = round(percentage_sum / total_duration)

            local id = stack_id

            mean = round(mean)
            median = round(median)
            min_value = round(min_value)
            max_value = round(max_value)
            stddev = round(stddev)

            max_id_width = math.max(max_id_width, #id)
            max_mean_width = math.max(max_mean_width, #tostring(mean))
            max_median_width = math.max(max_median_width, #tostring(median))
            max_min_width = math.max(max_min_width, #tostring(min_value))
            max_max_width = math.max(max_max_width, #tostring(max_value))
            max_stddev_width = math.max(max_stddev_width, #tostring(stddev))
            max_percentage_width = math.max(max_percentage_width, #tostring(percentage))

            if percentage > 0 then
                table.insert(to_print, {
                    id = id,
                    mean = mean,
                    median = median,
                    min = min_value,
                    max = max_value,
                    stddev = stddev,
                    percentage = percentage * 100
                })
            end
        end

        table.sort(to_print, function(a, b) return a.percentage > b.percentage end)

        -- pretty format table
        local order = { "percentage", "mean", "median", "max", "min", "stddev", "id" }

        local labels = {
            id = "ID",
            mean = "mean",
            median = "median",
            min = "max",
            max = "min",
            stddev = "stddev",
            percentage = "%",
        }

        local widths = {
            id = max_id_width,
            mean = max_mean_width,
            median = max_median_width,
            min = max_min_width,
            max = max_max_width,
            stddev = max_stddev_width,
            percentage = max_percentage_width,
        }

        -- [Fix]: Changed values(order) to ipairs(order) for standard Lua compatibility
        for _, id in ipairs(order) do
            widths[id] = math.max(widths[id], #labels[id])
        end

        local h_divider = "-"
        local v_divider = "|"
        local corner = "+"

        local function pad(str, width)
            str = tostring(str)
            return str .. string.rep(" ", width - #str)
        end

        local res = {}

        -- top/bottom/mid border
        local border_parts = {}
        for _, col in ipairs(order) do
            table.insert(border_parts, string.rep(h_divider, widths[col] + 2))
        end
        local border = corner .. table.concat(border_parts, corner) .. corner

        table.insert(res, border)
        table.insert(res, "\n")

        -- header row
        local header_parts = {}
        for _, col in ipairs(order) do
            table.insert(header_parts, " " .. pad(labels[col], widths[col]) .. " ")
        end
        table.insert(res, v_divider .. table.concat(header_parts, v_divider) .. v_divider)
        table.insert(res, "\n")

        table.insert(res, border)
        table.insert(res, "\n")

        -- data rows
        for _, row in ipairs(to_print) do
            local row_parts = {}
            for _, col in ipairs(order) do
                table.insert(row_parts, " " .. pad(row[col], widths[col]) .. " ")
            end
            table.insert(res, v_divider .. table.concat(row_parts, v_divider) .. v_divider)
            table.insert(res, "\n")
        end

        table.insert(res, border)
        print(table.concat(res))
    end
else
    profiler.start = _noop
    profiler.stop = _noop
    profiler.push = _noop
    profiler.pop = _noop
    profiler.notify = _noop
    profiler.get_is_active = _noop
    profiler.report = _noop
end

return profiler