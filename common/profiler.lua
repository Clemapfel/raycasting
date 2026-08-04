profiler = {}

local _noop = function() end

if PROFILE then
    local _is_active = false

    local _id_stack = {}
    local _current_id = ""
    local _id_needs_update = true

    local _data_id = {}
    local _data_timestamp = {}
    local _data_duration = {}

    profiler.start = function()
        _is_active = true
    end

    profiler.stop = function()
        _is_active = false
    end

    profiler.push = function(id)
        if _is_active then
            table.insert(_id_stack, id)
            _id_needs_update = true
        end
    end

    profiler.pop = function(id)
        if _is_active then
            table.remove(_id_stack, #_id_stack)
            _id_needs_update = true
        end
    end

    profiler.notify = function(duration)
        if _is_active then
            if _id_needs_update then
                _current_id = table.concat(_id_stack, ">")
            end

            table.insert(_data_id, _current_id)
            table.insert(_data_timestamp, love.timer.getTime())
            table.insert(_data_duration, duration)
        end
    end

    profiler.get_is_active = function()
        return _is_active == true
    end

    profiler.report = function()
        if #_data_id == 0 then
            error("In profiler.report: no collected data to report")
        end

        local unified = {}
        local id_to_duration = {}
        for i = 1, #_data_id do
            local id = _data_id[i]
            local duration = _data_duration[i]
            local timestamp = _data_timestamp[i]

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
            table.insert(entry, duration)  -- fixed: was missing the value
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

        local round = function(x)
            return math.floor(x * 1e6) / 1e6
        end

        local to_print = {}

        for stack_id, durations in pairs(id_to_duration) do
            local n = #durations

            local sorted = {}
            for i = 1, n do
                sorted[i] = durations[i]
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

            local id = string.match(stack_id, ".*>(.*)") or stack_id

            mean = round(mean)
            median = round(median)
            min_value = round(min_value)
            max_value = round(max_value)
            stddev = round(stddev)
            local percentage = round(sum / total_duration)

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

        for id in values(order) do
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

        return table.concat(res)
    end
else
    profiler.start = _noop
    profiler.stop = _noop
    profiler.push = _noop
    profiler.pop = _noop
    profiler.report = _noop
end

return profiler