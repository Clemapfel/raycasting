--- @class rt.Matrix
rt.Matrix = meta.class("Matrix")

--- @brief
function rt.Matrix:instantiate()
    meta.install(self, {
        _data = {}, -- Table<Table<Any>>, not inline so it can be sparse
        _min_x = 0,
        _min_y = 0,
        _max_x = 0,
        _max_y = 0,
        _index_range_update_needed = true
    })
end

--- @return Number
function rt.Matrix:get(x, y)
    if self._data[x] ~= nil and self._data[x][y] ~= nil then
        return self._data[x][y]
    else
        return nil
    end
end

--- @param value Number
function rt.Matrix:set(x, y, value)
    if self._data[x] == nil then
        self._data[x] = {}
    end

    self._data[x][y] = value

    if x < self._min_x then self._min_x = x end
    if x > self._max_x then self._max_x = x end
    if y < self._min_y then self._min_y = y end
    if y > self._max_y then self._max_y = y end
end

--- @return (Number, Number, Number, Number) min_x, min_y, max_x, max_y
function rt.Matrix:get_index_range()
    if self._index_range_update_needed then
        self:_update_index_range()
    end

    return self._min_x, self._min_y, self._max_x, self._max_y
end

--- @brie
function rt.Matrix:_update_index_range()
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for x, row in pairs(self._data) do
        for y, _ in pairs(row) do
            if x < min_x then min_x = x end
            if y < min_y then min_y = y end
            if x > max_x then max_x = x end
            if y > max_y then max_y = y end
        end
    end

    self._min_x, self._min_y = min_x, min_y
    self._max_x, self._max_y = max_x, max_y
    self._index_range_update_needed = false
end

function rt.Matrix:clear(keep_allocated)
    if keep_allocated == true then
        require "table.clear"
        for row in values(self._data) do
            for column in values(row) do
                table.clear(column)
            end
        end
    else
        self._data = {}
    end

    self._min_x = 0
    self._min_y = 0
    self._max_x = 0
    self._max_y = 0
    self._index_range_update_needed = true
end