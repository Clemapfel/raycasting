rt.settings.disk_out = {
    buffer_size = 512
}

--- @class rt.DiskOut
rt.DiskOut = meta.class("DiskOut")

--- @brief
function rt.DiskOut:instantiate(path, _max_buffer_size)
    if _max_buffer_size == nil then _max_buffer_size = rt.settings.disk_out.buffer_size end
    meta.assert(path, mt.String, _max_buffer_size, mt.Number)

    self._path = path
    bd.create_file(self._path, "")
    self._file = bd.open_file(self._path, bd.FileMode.APPEND)

    self._buffer = {}
    self._buffer_size = 0
    self._max_buffer_size = _max_buffer_size
end

--- @brief
function rt.DiskOut:write(...)
    local char_size = 8
    local size = 0
    local n = math.max(1, select("#", ...)) -- if write() is called, append `nil` to buffer and grow

    for i = 1, n do
        local x = select(i, ...)
        if meta.is_number(x) or meta.is_string(x) or meta.is_boolean(x) or meta.is_nil(x) then
            self._buffer_size = self._buffer_size + 1
            self._buffer[self._buffer_size] = x
        else
            rt.error("In rt.DiskOut.write: unsupported type for argument #", i, ": `", meta.typeof(x), "`")
        end
    end

    if self._buffer_size > self._max_buffer_size then
        self:flush()
    end
end

local _element_sep = "\030"
local _line_sep = "\029"
local _encode = function(to_encode, n)
    meta.assert(to_encode, mt.Table, n, mt.Number)
    local to_concat = {}
    for i = 1, n do
        local x = to_encode[i]
        if x == nil then
            table.insert(to_concat, "nil")
        elseif x == true then
            table.insert(to_concat, "true")
        elseif x == false then
            table.insert(to_concat, "false")
        elseif meta.is_number(x) then
            table.insert(to_concat, tostring(x))
        elseif meta.is_string(x) then
            table.insert(to_concat, x)
        else
            rt.error("In rt.DiskOut.encode: unsupported type `", meta.typeof(x), "`")
        end
    end
    return table.concat(to_concat, _element_sep) .. _line_sep
end

local _decode = function(data)
    meta.assert(data, mt.String)

    local result = {}
    local n_elements = 0

    local push = function(s)
        local value
        if s == "nil" then
            value = nil
        elseif s == "true" then
            value = true
        elseif s == "false" then
            value = false
        elseif s == "inf" then
            value = math.huge
        elseif s == "-inf" then
            value = -math.huge
        elseif s == "nan" or s == "-nan" then
            value = 0 / 0
        else
            local as_number = tonumber(s)
            if as_number ~= nil then
                value = as_number
            else
                value = s
            end
        end
        n_elements = n_elements + 1
        result[n_elements] = value
    end

    for record in string.gmatch(data, "([^" .. _line_sep .. "]*)" .. _line_sep) do
        local start = 1
        while true do
            local sep_i = string.find(record, _element_sep, start, true)
            if sep_i == nil then
                push(string.sub(record, start))
                break
            end
            push(string.sub(record, start, sep_i - 1))
            start = sep_i + 1
        end
    end

    return result, n_elements
end

--- @brief
function rt.DiskOut:flush()
    if self._buffer_size > 0 then
        local success, error = pcall(
            self._file.write,
            self._file,
            _encode(self._buffer, self._buffer_size)
        )

        if not success then
            rt.error("In rt.DiskOut.flush: error when writing to file at `", self._path, "`: ", error)
        end
    end

    self._file:flush()
    table.clear(self._buffer)
    self._buffer_size = 0
end

--- @brief
function rt.DiskOut:free()
    self:flush()
    bd.close_file(self._file)
end

function rt.DiskOut:read()
    self:flush()
    bd.close_file(self._file)

    local out, n = _decode(bd.read_file(self._path))

    self._file = bd.open_file(self._path, bd.FileMode.APPEND)

    return out, n
end