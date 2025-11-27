local _buffer = {}

local function _merge_pass(destination, source, length, run_width, compare)
    local run_start = 1
    while run_start <= length do
        local left_end = run_start + run_width - 1

        if left_end >= length then
            for index = run_start, length do
                destination[index] = source[index]
            end
            break
        end

        local right_end = run_start + run_width + run_width - 1
        if right_end > length then
            right_end = length
        end

        local left_index = run_start
        local right_index = left_end + 1
        local output_index = run_start

        while left_index <= left_end and right_index <= right_end do
            local left_value = source[left_index]
            local right_value = source[right_index]

            if compare(right_value, left_value) then
                destination[output_index] = right_value
                right_index = right_index + 1
            else
                -- prefer left on equality to maintain stability
                destination[output_index] = left_value
                left_index = left_index + 1
            end
            output_index = output_index + 1
        end

        while left_index <= left_end do
            destination[output_index] = source[left_index]
            left_index = left_index + 1
            output_index = output_index + 1
        end

        while right_index <= right_end do
            destination[output_index] = source[right_index]
            right_index = right_index + 1
            output_index = output_index + 1
        end

        run_start = right_end + 1
    end
end

local _default_comparator = function(a, b) return a < b end

--- @brief merge sort
function table.stable_sort(array, comparator)
    if comparator == nil then comparator = _default_comparator end

    local length = #array
    if length < 2 then
        return array
    end

    if table.clear then
        table.clear(_buffer)
    else
        for index = length + 1, #_buffer do
            _buffer[index] = nil
        end
    end

    local source = array
    local destination = _buffer
    local run_width = 1

    while run_width < length do
        _merge_pass(destination, source, length, run_width, comparator)
        source, destination = destination, source
        run_width = run_width + run_width
    end

    -- ff the final result is in the temp buffer, copy it back to the array
    if source ~= array then
        for index = 1, length do
            array[index] = source[index]
        end
    end

    return array
end
