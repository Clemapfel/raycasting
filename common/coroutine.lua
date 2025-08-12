--- @class rt.Coroutine
rt.Coroutine = meta.class("Coroutine")

--- @brief
function rt.Coroutine:instantiate(f)
    f()
    --self._native = coroutine.create(f)
end

--- @brief
function rt.Coroutine:start(...)
    if self._native == nil then return self end
    self:resume()
    return self
end

--- @brief
function rt.Coroutine:resume(...)
    if self._native == nil then return end
    if coroutine.status(self._native) == "dead" then return end

    local result = { coroutine.resume(self._native, ...) }
    if not result[1] then
        rt.error(result[2])
    else
        return table.unpack(result)
    end
end

--- @brief
function rt.Coroutine:get_is_done()
    if self._native == nil then return true end
    return coroutine.status(self._native) == "dead"
end