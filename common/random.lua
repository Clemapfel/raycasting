rt.random = {}

local _generator_stack = {}
local _default_generator = love.math.newRandomGenerator(os.time())

local _random = function(...)
    if #_generator_stack == 0 then
        return _default_generator:random(...)
    else
        return _generator_stack[1]:random(...)
    end
end

local _random_normal = function(...)
    if #_generator_stack == 0 then
        return _default_generator:randomNormal(...)
    else
        return _generator_stack[1]:randomNormal(...)
    end
end

--- @brief
function rt.random.push(seed)
    table.insert(_generator_stack, love.math.newRandomGenerator(seed or os.time()))
end

--- @brief
function rt.random.pop()
    if #_generator_stack == 0 then
        rt.error("In rt.random.pop: stack is empty, more pops than pushes?")
    end

    table.remove(_generator_stack, 1)
end

--- @brief generate random float in given range
--- @param min Number
--- @param max Number
--- @return Number
function rt.random.number(min, max)
    return math.mix(min or 0, max or 1, _random()) -- float with no rags
end

--- @brief generate random integer in given range
--- @param min Number
--- @param max Number
--- @return Number
function rt.random.integer(min, max)
    return _random(min, max) -- already an int
end

--- @brief
function rt.random.gaussian(min, max)
    local r = _random_normal(0.25, 0.5) -- 95% fall into [0, 1]
    return math.clamp(math.mix(min, max, r), min, max)
end

--- @brief pick random element from table
--- @param set Table
function rt.random.choose(...)
    local n = select("#", ...)
    if n > 1 then
        return select(rt.random.integer(1, n), ...)
    else
        local t = select(1, ...)
        return t[rt.random.integer(1, #t)]
    end
end

--- @brief reorder table (works with any table)
function rt.random.shuffle_in_place(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end

    for i = 1, #keys do
        local j = rt.random.integer(1, #keys)
        local temp = keys[i]
        keys[i] = keys[j]
        keys[j] = temp
    end

    local values = {}
    for i, key in ipairs(keys) do
        values[i] = t[key]
    end

    for i, key in ipairs(keys) do
        t[key] = values[i]
    end

    return t
end

--- @brief reorder table (works with any table)
function rt.random.shuffle(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end

    rt.random.shuffle_in_place(keys)

    local values = {}
    for i, key in ipairs(keys) do
        values[i] = t[key]
    end

    local out = {}
    for i, key in ipairs(keys) do
        out[key] = values[i]
    end

    return out
end

--- @brief
function rt.random.toss_coin(success_chance)
    success_chance = success_chance or 0.5
    if success_chance >= 1 then return true elseif success_chance <= 0 then return false end
    return rt.random.number(0, 1) <= success_chance
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
    if select("#", ...) == 0 then
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
    return love.math.simplexNoise(x * math.pi / 3, ...)
end

