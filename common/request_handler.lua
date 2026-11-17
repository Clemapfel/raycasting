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
    MANUAL = 9
}
rt.RequestReduceMode = meta.enum("RequestReduceMode", rt.RequestReduceMode)

local _instance_t = meta.Object

--- @brief
function rt.RequestHandler:instantiate(reduce_mode)
    meta.assert(reduce_mode, rt.RequestReduceMode)

    self._reduce_mode = reduce_mode
    self._instance_to_request = {}
end

--- @brief
function rt.RequestHandler:request(instance, ...)
    meta.assert(instance, _instance_t)

    if select("#", ...) == 0 then
        -- remove request
        self:remove(instance)
    else
        local request = self._instance_to_request[instance]
        if request == nil then
            request = { values = nil }
            self._instance_to_request[instance] = request
        end

        request.values = { ... }
    end
end

--- @brief
function rt.RequestHandler:remove(instance)
    meta.assert(instance, _instance_t)
    self._instance_to_request[instance] = nil
end

--- @brief
function rt.RequestHandler:clear()
    self._instance_to_request = {}
end

--- @brief
function rt.RequestHandler:reduce(mode)
    if mode == nil then mode = self._reduce_mode end

    meta.assert(mode, rt.RequestHandler)
    self._reduce_mode = mode

    local requests = self._instance_to_request
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

    elseif mode == rt.RequestReduceMode.SUM then
        local sum = { }
        for _, request in pairs(requests) do
            for i, x in ipairs(request.values) do
                sum[i] = (sum[i] or 0) + x
            end
        end

        return table.unpack(sum)

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
        for instance, request in pairs(requests) do
            if #request.values == 1 then
                table.insert(res, request.values)
            end

            table.insert(res, table.deepcopy(request.values))
        end

        return res
    end
end