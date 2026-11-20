--- @class rt.RequestHandler
rt.RequestHandler = meta.class("RequestHandler")

--- @enum rt.RequestReduceMode
rt.RequestReduceMode = {
    AT_LEAST_ONE_TRUE = 1,
    AT_LEAST_ONE_FALSE = 2,
    ALL_TRUE = 3,
    ALL_FALSE = 4,
    SUM = 5,
    MEAN = 6,
    MAX = 7,
    MIN = 8,
    ADD = 5, -- sic
    SUBTRACT = 9,
    MULTIPLY = 10,
    DIVIDE = 11,
    CUSTOM = 12,
    OLDEST = 13,
    NEWEST = 14,
    ENUMERATE = 15
}
rt.RequestReduceMode = meta.enum("RequestReduceMode", rt.RequestReduceMode)

local _id_t = mt.Any

--- @brief
function rt.RequestHandler:instantiate(...)
    self._default_value = { ... }
    self._id_to_request = {}
end

local _timestamp = 0

--- @brief
function rt.RequestHandler:request(id, ...)
    meta.typecheck(id, _id_t)

    local n = select("#", ...)
    local should_remove = n == 0
    if should_remove ~= true then
        should_remove = true
        for i = 1, n do
            if select(i, ...) ~= nil then
                should_remove = false
            end
        end
    end

    if should_remove then
        -- remove request
        self:remove(id)
    else
        local request = self._id_to_request[id]
        if request == nil then
            request = {}
            self._id_to_request[id] = request
        end

        request.values = { ... }
        request.timestamp = _timestamp
        _timestamp = _timestamp + 1
    end

    return id
end

--- @brief
function rt.RequestHandler:remove(id)
    meta.typecheck(id, _id_t)
    self._id_to_request[id] = nil
end

--- @brief
function rt.RequestHandler:clear()
    self._id_to_request = {}
end

--- @brief
function rt.RequestHandler:get_count()
    return table.count(self._id_to_request)
end

local _reducers = {
    [rt.RequestReduceMode.AT_LEAST_ONE_TRUE] = function(requests)
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x == true then return true end
            end
        end

        return false
    end,

    [rt.RequestReduceMode.AT_LEAST_ONE_FALSE] = function(requests)
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x == false then return true end
            end
        end

        return false
    end,

    [rt.RequestReduceMode.ALL_TRUE] = function(requests)
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x ~= true then return false end
            end
        end

        return true
    end,

    [rt.RequestReduceMode.ALL_FALSE] = function(requests)
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x ~= false then return false end
            end
        end

        return true
    end,

    [rt.RequestReduceMode.SUM] = function(requests, ...)
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 0) + x
            end
        end

        return table.unpack(res)
    end,

    [rt.RequestReduceMode.SUBTRACT] = function(requests, ...)
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 0) - x
            end
        end

        return table.unpack(res)
    end,

    [rt.RequestReduceMode.MULTIPLY] = function(requests, ...)
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 1) * x
            end
        end

        return table.unpack(res)
    end,

    [rt.RequestReduceMode.DIVIDE] = function(requests, ...)
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 1) / x
            end
        end

        return table.unpack(res)
    end,

    [rt.RequestReduceMode.MEAN] = function(requests)
        local sum = {}
        local ns = {}
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                sum[i] = (sum[i] or 0) + x
                ns[i] = (ns[i] or 0) + 1
            end
        end

        for i, x in ipairs(sum) do
            sum[i] = x / ns[i]
        end

        return table.unpack(sum)
    end,

    [rt.RequestReduceMode.MAX] = function(requests)
        local maxs = {}
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                if maxs[i] == nil then
                    maxs[i] = x
                else
                    maxs[i] = math.max(maxs[i], x)
                end
            end
        end

        return table.unpack(maxs)
    end,

    [rt.RequestReduceMode.MIN] = function(requests)
        local mins = {}
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                if mins[i] == nil then
                    mins[i] = x
                else
                    mins[i] = math.min(mins[i], x)
                end
            end
        end

        return table.unpack(mins)
    end,

    [rt.RequestReduceMode.NEWEST] = function(requests)
        local max_request = nil
        local max_timestamp = -math.huge
        for _, request in pairs(requests) do
            if request.timestamp >= max_timestamp then
                max_timestamp = request.timestamp
                max_request = request
            end
        end

        return table.unpack(max_request.values)
    end,

    [rt.RequestReduceMode.OLDEST] = function(requests)
        local min_request = nil
        local min_timestamp = math.huge
        for _, request in pairs(requests) do
            if request.timestamp <= min_timestamp then
                min_timestamp = request.timestamp
                min_request = request
            end
        end

        return table.unpack(min_request.values)
    end,

    [rt.RequestReduceMode.ENUMERATE] = function(requests)
        local res = {}
        for _, request in pairs(requests) do
            if #request.values == 1 then
                table.insert(res, request.values[1])
            else
                table.insert(res, table.deepcopy(request.values))
            end
        end

        return res
    end
}

--- @brief
function rt.RequestHandler:reduce(mode, ...)
    if mode == nil then mode = self._reduce_mode end
    meta.typecheck(mode, rt.RequestReduceMode)

    if table.is_empty(self._id_to_request) then
        if mode == rt.RequestReduceMode.ENUMERATE then
            -- match table of table layout
            if #self._default_value == 1 then
                return { table.deepcopy(self._default_value[1]) }
            else
                return { table.deepcopy(self._default_value) }
            end
        else
            return table.unpack(self._default_value)
        end
    end

    return _reducers[mode](self._id_to_request, ...)
end