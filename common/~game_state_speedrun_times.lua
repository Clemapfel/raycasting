local _new_splits = function(n_segments)
    return {
        n_segments = n_segments,
        bests = table.rep(0, n_segments),
        current = table.rep(0, n_segments)
    }
end

local _get_sum_of_best = function(splits)
    local sum = 0
    for i = 1, splits.n_segments do
        sum = sum + splits.bests[i]
    end
    return sum
end

