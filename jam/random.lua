local _generator = love.math.newRandomGenerator(os.time())

local _random = function(...)
    return _generator:random(...)
end

local _random_normal = function(...)
    return _generator:randomNormal(...)
end

random_seed = function(seed)
    _generator = love.math.newRandomGenerator(seed)
end

random_number = function(min, max)
    return math_mix(min or 0, max or 1, _random())
end

random_integer = function(min, max)
    return _random(min, max) -- already an int
end

random_gaussian = function(min, max)
    local r = _random_normal(0.25, 0.5) -- 95% fall into [0, 1]
    return math_clamp(math_mix(min, max, r), min, max)
end

random_uniform = random_number

random_choose = function(...)
    local n = select("#", ...)
    if n > 1 then
        return select(random_integer(1, n), ...)
    else
        local t = select(1, ...)
        return t[random_integer(1, #t)]
    end
end

random_shuffle_in_place = function(t)
    local keys = {}
    for k in iter_keys(t) do
        table_push(keys, k)
    end

    for i = 1, #keys do
        local j = random_integer(1, #keys)
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

random_shuffle = function(t)
    local keys = {}
    for k in pairs(t) do
        table_push(keys, k)
    end

    random_shuffle_in_place(keys)

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

random_toss_coin = function(success_chance)
    success_chance = success_chance or 0.5
    if success_chance >= 1 then return true elseif success_chance <= 0 then return false end
    return random_number(0, 1) <= success_chance
end

random_char_list = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
}

random_string = function(length, ...)
    local set
    if select("#", ...) == 0 then
        set = random_char_list
    else
        set = table_deepcopy(random_char_list)
        for c in iter_varargs(...) do
            table_push(set, c)
        end
    end

    local out = {}
    for i = 1, length do
        table_push(out, set[random_integer(1, #set)])
    end
    return table_concat(out, "")
end

local mul = math_pi / 3
random_noise = function(x, y, z, w)
    if love.getVersion() <= 12 then
        return love.math.noise(
            x * mul,
            y * mul,
            z * mul,
            w * mul
        )
    else
        return love.math.simplexNoise(
            x * mul,
            y * mul,
            z * mul,
            w * mul
        )
    end
end