rt.random = {}

rt.random.DEFAULT_SEED = os.time()
if not love == nil then
    love.math.setRandomSeed(rt.random.DEFAULT_SEED)
else
    math.randomseed(rt.random.DEFAULT_SEED)
end

--- @brief generate number in [0, 1]
--- @param seed_maybe Number (or nil)
--- @return Number
function rt.rand(seed_maybe)
    if not (seed_maybe == nil) then
        love.math.setRandomSeed(seed_maybe)
    end
    return love.math.random()
end

--- @brief re-seed randomness
--- @param seed Number
function rt.random.seed(seed)
    love.math.setRandomSeed(seed)
end

--- @brief get random number in given range
--- @param min Number
--- @param max Number
--- @return Number
function rt.random.integer(min, max)
    return love.math.random(min, max)
end

--- @brief get random float in given range
--- @param min Number
--- @param max Number
--- @return Number
function rt.random.number(min, max)
    if min == nil then min = 0 end
    if max == nil then max = 1 end
    local lower, upper = math.min(min, max), math.max(min, max)
    return lower + rt.rand() * (upper - lower)
end

--- @brief pick random element from table
--- @param set Table
function rt.random.choose(set)
    local i = rt.random.integer(1, sizeof(set))
    local n_seen = 1
    for key, value in pairs(set) do
        if n_seen == i then return value end
        n_seen = n_seen + 1
    end
end

--- @brief pick random subset, no repeats
function rt.random.choose_multiple(set)
    local out = {}
    local n_indices = rt.random.integer(1, sizeof(set))
    local indices = {}
    for i = 1, n_indices do
        ::retry::
        local index = rt.random.integer(1, sizeof(set))
        if indices[index] == true then
            goto retry
        end

        indices[index] = true
        table.insert(out, set[index])
    end

    return out
end

--- @brief reorder table
function rt.random.shuffle_in_place(t)
    for i = 1, #t do
        local j = rt.random.integer(1, #t)
        local temp = t[i]
        t[i] = t[j]
        t[j] = temp
    end
    return t
end

--- @brief reorder table
function rt.random.shuffle(t)
    local indices = {}
    for i = 1, sizeof(t) do
        table.insert(indices, i)
    end
    rt.random.shuffle_in_place(indices)

    local out = {}
    for i, j in pairs(indices) do
        out[i] = t[j]
    end
    return out
end

--- @brief
function rt.random.toss_coin(success_chance)
    success_chance = which(success_chance, 0.5)
    return rt.rand() <= success_chance
end

rt.random.CHAR_LIST = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
}

--- @brief generate string
--- @param length Number
--- @param set Table<String> (or nil)
function rt.random.string(length, ...)
    local set
    if _G._select("#", ...) == 0 then
        set = rt.random.CHAR_LIST
    else
        set = {table.unpack(rt.random.CHAR_LIST)}
        for c in range(...) do
            table.insert(set, c)
        end
    end

    local out = {}
    for i = 1, length do
        table.insert(out, set[rt.random.integer(1, #set)])
    end
    return table.concat(out, "")
end

--- @brief
function rt.random.noise(x, ...)
    return love.math.simplexNoise(x, ...)
end
