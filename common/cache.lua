--- @enum rt.CachePolicy
rt.CachePolicy = meta.enum("CachePolicy", {
    FIRST_IN_FIRST_OUT = true,
    FIRST_IN_LAST_OUT = false
})

--- @class rt.Cache
rt.Cache = meta.class("Cache")

--- @class rt.CacheFIFO
rt.CacheFIFO = function(...)
    return rt.Cache(rt.CachePolicy.FIRST_IN_FIRST_OUT, ...)
end

--- @class rt.CacheLIFO
rt.CacheLIFO = function(...)
    return rt.Cache(rt.CachePolicy.FIRST_IN_LAST_OUT, ...)
end

--- @brief
function rt.Cache:instantiate(policy)
    if policy == nil then policy = rt.CachePolicy.FIRST_IN_FIRST_OUT end
    meta.assert(policy, rt.CachePolicy)

    self._policy = policy
    self._current_hash = 0

    self._hash_to_node = {} -- Table<Hash, Any>

    self._hash_to_next = {} -- Table<Hash, Hash>
    self._hash_to_previous = {} -- Table<Hash, Hash>

    self._size = 0

    self._max_priority_hash = nil -- hash for object with highest priority
    self._min_priority_hash = nil -- lowest priority
end

--- @brief
function rt.Cache:get(hash)
    return self._hash_to_node[hash]
end

--- @brief
function rt.Cache:get_hash(node)
    local current_hash = self._max_priority_hash
    while current_hash ~= nil do
        if self._hash_to_node[current_hash] == node then
            return current_hash
        end
        current_hash = self._hash_to_next[current_hash]
    end
    return nil
end

--- @brief
function rt.Cache:contains(hash)
    return self._hash_to_node[hash] ~= nil
end

--- @brief
function rt.Cache:get_front()
    return self._hash_to_node[self._max_priority_hash], self._max_priority_hash
end

--- @brief
function rt.Cache:get_back()
    return self._hash_to_node[self._min_priority_hash], self._min_priority_hash
end

--- @brief
function rt.Cache:get_front_node()
    return self._hash_to_node[self._max_priority_hash]
end

--- @brief
function rt.Cache:get_back_node()
    return self._hash_to_node[self._min_priority_hash]
end

--- @brief
function rt.Cache:get_front_hash()
    return self._max_priority_hash
end

--- @brief
function rt.Cache:get_back_hash()
    return self._min_priority_hash
end

--- @brief add an object to the cache, or if it already exists, bump
function rt.Cache:push(...)
    local object, hash_override
    if select("#", ...) == 1 then
        object = select(1, ...)
        hash_override = nil
        meta.assert(object, mt.Any)
    elseif select("#", ...) == 2 then
        hash_override = select(1, ...)
        object = select(2, ...)
        meta.assert(hash_override, mt.Any, object, mt.Any)
    end

    if hash_override ~= nil and self._hash_to_node[hash_override] ~= nil then
        return
    end

    local hash
    if hash_override ~= nil then
        hash = hash_override
    else
        hash = self._current_hash
        self._current_hash = self._current_hash + 1
    end

    self._hash_to_node[hash] = object

    if self._policy == rt.CachePolicy.FIRST_IN_FIRST_OUT then
        -- queue
        local old_min = self._min_priority_hash
        self._hash_to_previous[hash] = nil
        self._hash_to_next[hash] = old_min

        if old_min ~= nil then
            self._hash_to_previous[old_min] = hash
        end

        self._min_priority_hash = hash

        if self._max_priority_hash == nil then
            self._max_priority_hash = hash
        end

    elseif self._policy == rt.CachePolicy.FIRST_IN_LAST_OUT then
        -- stack
        local old_max = self._max_priority_hash
        self._hash_to_next[hash] = nil
        self._hash_to_previous[hash] = old_max

        if old_max ~= nil then
            self._hash_to_next[old_max] = hash
        end

        self._max_priority_hash = hash

        if self._min_priority_hash == nil then
            self._min_priority_hash = hash
        end
    else
        rt.error("In rt.Cache.instantiate: unhandled policy `", self._policy, "`")
    end

    self._size = self._size + 1

    return hash
end

--- @brief remove an object from the highest priority spot in the cache
function rt.Cache:pop(hash)
    if hash == nil then
        if self._policy == rt.CachePolicy.FIRST_IN_FIRST_OUT then
            hash = self._min_priority_hash
        else
            hash = self._max_priority_hash
        end
    end

    meta.assert(hash, mt.Any)

    local object = self._hash_to_node[hash]
    if object == nil then
        rt.warning("In rt.Cache.pop: no object with hash `", tostring(hash), "`")
        return nil
    end

    return self:remove(hash)
end

--- @brief remove an object from the cache
function rt.Cache:remove(hash)
    meta.assert(hash, mt.Any)

    local object = self._hash_to_node[hash]
    if object == nil then
        rt.warning("In rt.Cache.remove: no object with hash `", tostring(hash), "`")
        return nil
    end

    local previous_hash = self._hash_to_previous[hash]
    local next_hash = self._hash_to_next[hash]

    if previous_hash ~= nil then
        self._hash_to_next[previous_hash] = next_hash
    else
        self._min_priority_hash = next_hash
    end

    if next_hash ~= nil then
        self._hash_to_previous[next_hash] = previous_hash
    else
        self._max_priority_hash = previous_hash
    end

    self._hash_to_previous[hash] = nil
    self._hash_to_next[hash] = nil

    self._hash_to_node[hash] = nil
    self._size = self._size - 1

    return object
end

--- @brief move an object up n spots towards the highest priority spot, or if n is inf, move it to the highest priority spot
function rt.Cache:bump(hash, n_steps)
    if n_steps == nil then n_steps = math.huge end
    if n_steps <= 0 then return end

    meta.assert(hash, mt.Any, n_steps, mt.Number)

    if self._hash_to_node[hash] == nil then
        rt.warning("In rt.Cache.bump: no object with hash `", tostring(hash), "`")
        return
    end

    local previous_hash = self._hash_to_previous[hash]
    local next_hash = self._hash_to_next[hash]

    if next_hash == nil then return end -- already max

    if previous_hash ~= nil then
        self._hash_to_next[previous_hash] = next_hash
    else
        self._min_priority_hash = next_hash
    end
    self._hash_to_previous[next_hash] = previous_hash

    local current = next_hash
    local steps = 0
    while current ~= nil and steps < n_steps do
        current = self._hash_to_next[current]
        steps = steps + 1
    end

    if current ~= nil then
        local new_previous = self._hash_to_previous[current]

        self._hash_to_next[hash] = current
        self._hash_to_previous[hash] = new_previous

        self._hash_to_previous[current] = hash
        if new_previous ~= nil then
            self._hash_to_next[new_previous] = hash
        else
            self._min_priority_hash = hash
        end
    else
        local old_max = self._max_priority_hash
        self._hash_to_next[hash] = nil
        self._hash_to_previous[hash] = old_max

        if old_max ~= nil then
            self._hash_to_next[old_max] = hash
        end
        self._max_priority_hash = hash
    end
end

--- @brief
function rt.Cache:get_size()
    return self._size
end