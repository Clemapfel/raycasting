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
    ADDITION = 5, -- sic
    SUBTRACTION = 9,
    MULTIPLICATION = 10,
    DIVISION = 11,
    CUSTOM = 12,
    MANUAL = 13
}
rt.RequestReduceMode = meta.enum("RequestReduceMode", rt.RequestReduceMode)

local _id_t = mt.Any

--- @brief
function rt.RequestHandler:instantiate(reduce_mode, ...)
    meta.assert(reduce_mode, rt.RequestReduceMode)
    if select("#", ...) > 0 then
        for i = 1, select("#", ...) do
            meta.assert_argument_type(select(1, ...), mt.Union(mt.Boolean, mt.Number), 1 + i)
        end
    end

    self._default_value = { ... }
    self._reduce_mode = reduce_mode
    self._id_to_request = {}
end

--- @brief
function rt.RequestHandler:request(id, ...)
    meta.assert(id, _id_t)

    if select("#", ...) == 0 then
        -- remove request
        self:remove(id)
    else
        local request = self._id_to_request[id]
        if request == nil then
            request = { values = nil }
            self._id_to_request[id] = request
        end

        request.values = { ... }
    end
    
    return id
end

--- @brief
function rt.RequestHandler:remove(id)
    meta.assert(id, _id_t)
    self._id_to_request[id] = nil
end

--- @brief
function rt.RequestHandler:clear()
    self._id_to_request = {}
end

--- @brief
function rt.RequestHandler:reduce(mode, ...)
    if mode == nil then mode = self._reduce_mode end
    meta.assert(mode, rt.RequestReduceMode)

    if table.is_empty(self._id_to_request) then
        if mode == rt.RequestReduceMode.MANUAL then
            if #self._default_value == 1 then
                return { table.deepcopy(self._default_value[1]) }
            else
                return { table.deepcopy(self._default_value) }
            end
        else
            return table.unpack(self._default_value)
        end
    end

    local requests = self._id_to_request
    if mode == rt.RequestReduceMode.AT_LEAST_ONE_TRUE then
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x == true then return true end
            end
        end

        return false

    elseif mode == rt.RequestReduceMode.AT_LEAST_ONE_FALSE then
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x == false then return true end
            end
        end

        return false

    elseif mode == rt.RequestReduceMode.ALL_TRUE then
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x ~= true then return false end
            end
        end

        return true

    elseif mode == rt.RequestReduceMode.ALL_FALSE then
        for _, request in pairs(requests) do
            for _, x in ipairs(request.values) do
                if x ~= false then return false end
            end
        end

        return true

    elseif mode == rt.RequestReduceMode.SUM or mode == rt.RequestHandler.ADDITION then
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 0) + x
            end
        end

        return table.unpack(res)

    elseif mode == rt.RequestReduceMode.SUBTRACTION then
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 0) - x
            end
        end

        return table.unpack(res)

    elseif mode == rt.RequestReduceMode.MULTIPLICATION then
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 1) * x
            end
        end

        return table.unpack(res)

    elseif mode == rt.RequestReduceMode.DIVISION then
        local res = { ... }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                res[i] = (res[i] or 1) / x
            end
        end

        return table.unpack(res)

    elseif mode == rt.RequestReduceMode.MEAN then
        local sum = { }
        local ns = { }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                sum[i] = (sum[i] or 0) + x
                ns[i] = (ns[i] or 0) + 1
            end
        end

        for i, x in ipairs(sum) do
            sum[i] = sum[i] / ns[i]
        end

        return table.unpack(sum)

    elseif mode == rt.RequestReduceMode.MAX then
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

    elseif mode == rt.RequestReduceMode.MIN then
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

    elseif mode == rt.RequestReduceMode.MANUAL then
        local res = {}
        for id, request in pairs(requests) do
            if #request.values == 1 then
                table.insert(res, request.values[1])
            else
                table.insert(res, table.deepcopy(request.values))
            end
        end

        return res
    end
end