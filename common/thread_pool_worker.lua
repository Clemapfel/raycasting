










require("physics.slick.slick.init")




--[[


require "love.timer"
require "love.math"
require "love.filesystem"
require("physics.slick.slick.init")

-- ### MESSAGE HANDLERS (add new handlers here) ### --

_G["example_handler"] = function(data)
    love.timer.sleep()
    return data -- should be pure function that only returns data
end

_G["overworld.bubble_field"] = function(data)
    -- wave equation solver
    local polygon_positions = data.polygon_positions
    local outline_positions = data.outline_positions
    local wave = data.wave
    local offset_sum, offset_max = 0, -math.huge
    local n_points = data.n_points
    for i = 1, n_points do
        local left = (i == 1) and n_points or (i - 1)
        local right = (i == n_points) and 1 or (i + 1)
        local new = 2 * wave.current[i] - wave.previous[i] + data.courant^2 * (wave.current[left] - 2 * wave.current[i] + wave.current[right])
        new = new * data.damping
        wave.next[i] = new

        offset_sum = offset_sum + math.abs(new)
        offset_max = math.max(offset_sum, math.abs(new))

        local entry = data.contour_vectors[i]
        local x = data.contour_center_x + entry.dx * (1 + new) * entry.magnitude
        local y = data.contour_center_y + entry.dy * (1 + new) * entry.magnitude
        table.insert(polygon_positions, x)
        table.insert(polygon_positions, y)
    end
    wave.previous, wave.current, wave.next = wave.current, wave.next, wave.previous

    if offset_max < data.wave_deactivation_threshold then
        data.is_active = false
    end

    -- lerp to avoid step pattern artifacting
    for i = 1, #polygon_positions - 2, 2 do
        local x1, y1 = polygon_positions[i+0], polygon_positions[i+1]
        local x2, y2 = polygon_positions[i+2], polygon_positions[i+3]

        local x, y = math.mix2(x1, y1, x2, y2, 0.5)
        table.insert(outline_positions, x)
        table.insert(outline_positions, y)
    end

    do
        local x1, y1 = polygon_positions[1], polygon_positions[2]
        local x2, y2 = polygon_positions[#polygon_positions-1], polygon_positions[#polygon_positions]
        local x, y = math.mix2(x1, y1, x2, y2, 0.5)
        table.insert(outline_positions, x)
        table.insert(outline_positions, y)
    end

    local success, solid_tris = pcall(love.math.triangulate, polygon_positions)
    if not success then
        success, solid_tris = pcall(slick.triangulate, polygon_positions)
    end

    if success and #solid_tris > 0 then
        local solid_data = {}
        for tri in values(solid_tris) do
            for i = 1, 6, 2 do
                table.insert(solid_data, {
                    tri[i+0], tri[i+1]
                })
            end
        end

        data.mesh_data = solid_data
    else
        data.mesh_data = nil
    end

    return data
end

-- ### WORKER LOGIC (do not modify) ### --

local main_to_worker, worker_to_main, MessageType = ...

while true do
    --- message = { hash, handler_id, data }
    local message = main_to_worker:demand()

    -- quit safely
    if message.type == MessageType.EXIT then
        break
    end

    -- if handler unknown, promote error to main
    local handler = _G[message.handler_id]
    if handler == nil then
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = message.hash,
            reason = "In thread_pool_worker: for message from object `" .. message.hash .. "`: handler_id `" .. message.handler_id .. "` does not refer to a function in common/thread_pool_worker.lua"
        })
    end

    -- invoke handler, promote error if one occurrs
    local success, data_or_error, _ = pcall(handler, message.data)
    if not success then
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = message.hash,
            reason = "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. data_or_error
        })
    else
        -- check if handler correctly operates on data as a pure function
        if _ ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = message.hash,
                reason = "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. "returns more than one object"
            })
        end

        if not type(data_or_error) == "table" then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = message.hash,
                reason = "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. "handler does not return pure data object"
            })
        else
            -- send back result
            worker_to_main:push({
                type = MessageType.SUCCESS,
                hash = message.hash,
                data = data_or_error
            })
        end
    end
end

worker_to_main:push({
    type = MessageType.EXIT
})

return
]]--