local _insertion_sort_threshold = 16

--- @brief
function rt.stable_sort(values, compare_fn)
    local n = #values
    if n <= 1 then
        return values
    end

    -- use insertion sort for small arrays (typically faster due to lower overhead)
    local function insertion_sort(arr, left, right, cmp_fn)
        for i = left + 1, right do
            local key = arr[i]
            local j = i - 1
            while j >= left and not cmp_fn(arr[j], key) and cmp_fn(key, arr[j]) do
                arr[j + 1] = arr[j]
                j = j - 1
            end
            arr[j + 1] = key
        end
    end

    -- pre-allocate auxiliary buffer once
    local aux = {}
    for i = 1, n do
        aux[i] = values[i]
    end

    -- optimized merge function
    local function merge(arr, aux_arr, left_start, left_end, right_start, right_end)
        -- copy to auxiliary array only the range we need
        for i = left_start, right_end do
            aux_arr[i] = arr[i]
        end

        local i, j, k = left_start, right_start, left_start

        while i <= left_end and j <= right_end do
            local a, b = aux_arr[i], aux_arr[j]
            if compare_fn(a, b) then
                arr[k] = a
                i = i + 1
            elseif compare_fn(b, a) then
                arr[k] = b
                j = j + 1
            else
                -- equal: take from left for stability
                arr[k] = a
                i = i + 1
            end
            k = k + 1
        end

        -- copy remaining elements
        while i <= left_end do
            arr[k] = aux_arr[i]
            i, k = i + 1, k + 1
        end

        while j <= right_end do
            arr[k] = aux_arr[j]
            j, k = j + 1, k + 1
        end
    end

    -- handle small subarrays with insertion sort first
    local current_width = 1
    while current_width < _insertion_sort_threshold and current_width < n do
        local left_start = 1
        while left_start <= n do
            local right_end = math.min(left_start + 2 * current_width - 1, n)
            if left_start < right_end then
                insertion_sort(values, left_start, right_end, compare_fn)
            end
            left_start = left_start + 2 * current_width
        end
        current_width = current_width * 2
    end

    -- continue with merge sort for larger subarrays
    while current_width < n do
        local left_start = 1
        while left_start <= n do
            local left_end = math.min(left_start + current_width - 1, n)
            local right_start = left_end + 1
            local right_end = math.min(left_start + 2 * current_width - 1, n)

            if right_start <= right_end then
                merge(values, aux, left_start, left_end, right_start, right_end)
            end

            left_start = left_start + 2 * current_width
        end
        current_width = current_width * 2
    end

    return values
end