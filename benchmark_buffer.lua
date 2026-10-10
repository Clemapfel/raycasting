local n_runs = 5
local thread_counts = { 8 }
local particle_counts = { 3e7 }

require "table.new"
local buffer = require "string.buffer"
io.stdout:setvbuf("no")

local perform_str = [[
local sqrt, cos, sin = math.sqrt, math.cos(0.1), math.sin(0.1)
local perform = function(particles)
    for i = 1, #particles - 1, 2 do
        local x, y = particles[i], particles[i+1]
        local sign = (((i - 1) / 2) % 2 == 0) and 1 or -1

        local magnitude = sqrt(x^2 + y^2) + 1
        x, y = x * cos - y * sin, x * sin + y * cos
        x, y = x + sign * magnitude * 1e-3, y + sign * magnitude * 1e-3

        particles[i], particles[i+1] = x, y
    end
    return particles
end
]]

local thread_str = [[
    local main_to_worker, worker_to_main, MessageType = ...
]] .. perform_str .. [[
    require "table.new"
    local buffer = require "string.buffer"

    while true do
        local message = main_to_worker:demand()

        if message.type == MessageType.SHUTDOWN then
            return
        elseif message.type == MessageType.WORK then
            perform(message.data)
            worker_to_main:push({
                type = MessageType.WORK_RESPONSE,
                data = message.data,
                offset = message.offset
            })
        elseif message.type == MessageType.WORK_ENCODED then
            local data = buffer.decode(message.data)
            data = perform(data)
            worker_to_main:push({
                type = MessageType.WORK_ENCODED_RESPONSE,
                data = buffer.encode(data),
                offset = message.offset
            })
        end
    end
]]

local MessageType = {
    SHUTDOWN = 0,
    WORK = 1,
    WORK_RESPONSE = 2,
    WORK_ENCODED = 3,
    WORK_ENCODED_RESPONSE = 4
}

local mix = function(lower, upper, ratio)
    return lower * (1 - ratio) + upper * ratio
end

local generate_data = function(n_particles)
    local data = table.new(2 * n_particles, 0)
    for _ = 1, n_particles do
        table.insert(data, mix(-4000, 4000, math.random()))
        table.insert(data, mix(-4000, 4000, math.random()))
    end
    return data
end

local mean = function(t)
    local sum = 0
    for i = 1, #t do sum = sum + t[i] end
    return sum / #t
end

local median = function(t)
    local n = #t
    if n == 0 then return nil end
    table.sort(t)
    local mid = math.floor(n / 2)
    if n % 2 == 1 then
        return t[mid + 1]
    else
        return (t[mid] + t[mid + 1]) / 2
    end
end

local println = function(...)
    print(table.concat({ ... }))
end

local deepcopy = function(t)
    local out = table.new(#t, 0)
    for i = 1, #t do out[i] = t[i] end
    return out
end

local perform = loadstring(perform_str .. "\nreturn perform")()

-- ###

local results = {}
for _, n_threads in ipairs(thread_counts) do
    local worker_to_main = love.thread.newChannel()
    local main_to_worker = love.thread.newChannel()
    local threads = {}

    for _ = 1, n_threads do
        local thread = love.thread.newThread(thread_str)
        thread:start(main_to_worker, worker_to_main, MessageType)
        table.insert(threads, thread)
    end

    for _, n_particles in ipairs(particle_counts) do
        local synch_times = {}
        local no_buffer_times = {}
        local buffer_times = {}

        local particle_dimension = 2
        local total_coords = n_particles * particle_dimension
        local slice_size = math.max(particle_dimension, math.floor(total_coords / n_threads / particle_dimension) * particle_dimension)

        for run = 1, n_runs do
            local base_data = generate_data(n_particles)

            -- ###

            local data_no_buffer = deepcopy(base_data)
            local no_buffer_start = love.timer.getTime()

            local n_messages = 0
            for i = 1, #data_no_buffer, slice_size do
                local end_i = math.min(#data_no_buffer, i + slice_size - 1)
                local slice = table.new(end_i - i + 1, 0)
                for j = i, end_i do
                    slice[j - i + 1] = data_no_buffer[j]
                end

                main_to_worker:push({
                    type = MessageType.WORK,
                    data = slice,
                    offset = i
                })
                n_messages = n_messages + 1
            end

            for _ = 1, n_messages do
                local message = worker_to_main:demand()
                assert(message.type == MessageType.WORK_RESPONSE)
                local offset = message.offset
                for i = 1, #message.data do
                    data_no_buffer[offset + i - 1] = message.data[i]
                end
            end
            local no_buffer_end = love.timer.getTime()

            -- ###

            local buffer_data = deepcopy(base_data)
            local buffer_start = love.timer.getTime()

            n_messages = 0
            for i = 1, #buffer_data, slice_size do
                local end_i = math.min(#buffer_data, i + slice_size - 1)
                local slice = table.new(end_i - i + 1, 0)
                for j = i, end_i do
                    slice[j - i + 1] = buffer_data[j]
                end

                main_to_worker:push({
                    type = MessageType.WORK_ENCODED,
                    data = buffer.encode(slice),
                    offset = i
                })
                n_messages = n_messages + 1
            end

            for _ = 1, n_messages do
                local message = worker_to_main:demand()
                assert(message.type == MessageType.WORK_ENCODED_RESPONSE)
                local offset = message.offset
                local message_data = buffer.decode(message.data)
                for i = 1, #message_data do
                    buffer_data[offset + i - 1] = message_data[i]
                end
            end
            local buffer_end = love.timer.getTime()

            -- ###

            local synch_data = deepcopy(base_data)
            local synch_start = love.timer.getTime()
            perform(synch_data)
            local synch_end = love.timer.getTime()

            table.insert(synch_times, synch_end - synch_start)
            table.insert(no_buffer_times, no_buffer_end - no_buffer_start)
            table.insert(buffer_times, buffer_end - buffer_start)
        end

        local row = {
            n_threads, n_particles,
            mean(synch_times), median(synch_times),
            mean(no_buffer_times), median(no_buffer_times),
            mean(buffer_times), median(buffer_times)
        }
        table.insert(results, row)
        println("finished ", n_threads, " ", n_particles)
    end

    for _ = 1, n_threads do
        main_to_worker:push({ type = MessageType.SHUTDOWN })
    end
end

local function pretty_print(res)
    local headers = {
        "n_threads", "n_particles",
        "synch (mean)", "synch (median)",
        "no buffer (mean)", "no buffer (median)",
        "yes buffer (mean)", "yes buffer (median)"
    }

    local rows = {}
    local precision = "%.6f"
    for i, row in ipairs(res) do
        rows[i] = {
            tostring(row[1]), -- n_threads
            string.format("%d", row[2]), -- n_particles
            string.format(precision, row[3]),
            string.format(precision, row[4]),
            string.format(precision, row[5]),
            string.format(precision, row[6]),
            string.format(precision, row[7]),
            string.format(precision, row[8])
        }
    end

    local widths = {}
    for i, header in ipairs(headers) do
        widths[i] = #header
        for _, row in ipairs(rows) do
            widths[i] = math.max(widths[i], #row[i])
        end
    end

    local function format_row(cells)
        local out = {}
        for i, cell in ipairs(cells) do
            out[i] = string.rep(" ", widths[i] - #cell) .. cell
        end
        return "| " .. table.concat(out, " | ") .. " |"
    end

    local sep = {}
    for i, width in ipairs(widths) do
        sep[i] = string.rep("-", width + 2)
    end
    local separator = "+" .. table.concat(sep, "+") .. "+"

    println(perform_str)

    println("###")
    println("# runs per row: ", n_runs)
    println(separator)
    println(format_row(headers))
    println(separator)
    for _, row in ipairs(rows) do
        println(format_row(row))
    end
    println(separator)
end

pretty_print(results)