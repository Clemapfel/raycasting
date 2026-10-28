--- @class rt.LinkedListNode
rt.LinkedListNode = meta.plain_class("LinkedListNode", function(self, ...)
    if select("#", ...) <= 1 then
        self.value = select(1, ...)
        self.unpack = function(self)
            return self.value
        end
    else
        self.value = { ... }
        self.unpack = function(self)
            return table.unpack(self.value)
        end
    end

    self.next = nil
    self.previous = nil
end)

--- @class rt.LinkedList
rt.LinkedList = meta.class("LinkedList")

--- @brief
function rt.LinkedList:instantiate()
    meta.install(self, {
        _front = nil,
        _back = nil,
        _count = 0
    })
end

--- @brief
function rt.LinkedList:get_n_nodes()
    return self._count
end

--- @brief
function rt.LinkedList:has(value)
    local current = self._front
    while current ~= nil do
        if current.value == value then
            return true
        end

        current = current.next
    end

    return false
end

--- @brief remove either a node or the first node holding the given value
--- @return Boolean true if a node was removed
function rt.LinkedList:remove(input_target)
    local node_to_remove = nil

    if meta.isa(input_target, rt.LinkedListNode) then
        node_to_remove = input_target
    else
        local current_node = self._front
        while current_node ~= nil do
            if current_node.value == input_target then
                node_to_remove = current_node
                break
            end
            current_node = current_node.next
        end
    end

    if node_to_remove == nil then
        return false
    end

    if node_to_remove.previous ~= nil then
        node_to_remove.previous.next = node_to_remove.next
    else
        self._front = node_to_remove.next
    end

    if node_to_remove.next ~= nil then
        node_to_remove.next.previous = node_to_remove.previous
    else
        self._back = node_to_remove.previous
    end

    self._count = self._count - 1
    return true
end

--- @brief 0-based position of value, or nil if not found
function rt.LinkedList:get_position(value)
    local current = self._front
    local position = 0
    while current ~= nil do
        if current.value == value then
            return position
        end

        current = current.next
        position = position + 1
    end

    return nil
end

--- @brief
function rt.LinkedList:get_front()
    if self._front == nil then return nil end
    return self._front.value
end

--- @brief
function rt.LinkedList:get_front_node()
    if self._front == nil then return nil end
    return self._front
end

--- @brief
function rt.LinkedList:pop_front()
    if self._front == nil then return nil end

    local value = self._front.value
    self._front = self._front.next
    if self._front ~= nil then
        self._front.previous = nil
    else
        self._back = nil
    end

    self._count = self._count - 1
    return value
end

--- @brief
function rt.LinkedList:push_front(...)
    local node = rt.LinkedListNode(...)
    node.next = self._front
    if self._front ~= nil then
        self._front.previous = node
    else
        self._back = node
    end

    self._front = node
    self._count = self._count + 1
end

--- @brief
function rt.LinkedList:get_back()
    if self._back == nil then return nil end
    return self._back.value
end

--- @brief
function rt.LinkedList:get_back_node()
    if self._back == nil then return nil end
    return self._back
end

--- @brief
function rt.LinkedList:pop_back()
    if self._back == nil then return nil end

    local value = self._back.value
    self._back = self._back.previous
    if self._back ~= nil then
        self._back.next = nil
    else
        self._front = nil
    end

    self._count = self._count - 1
    return value
end

--- @brief
function rt.LinkedList:push_back(...)
    local node = rt.LinkedListNode(...)
    node.previous = self._back

    if self._back ~= nil then
        self._back.next = node
    else
        self._front = node
    end

    self._count = self._count + 1
    self._back = node
end

--- @brief
function rt.LinkedList:iterate()
    local current = self._front
    return function()
        if current == nil then return nil end
        local value = current.value
        current = current.next
        return value
    end
end

function rt.LinkedList:iterate_nodes()
    local current = self._front
    return function()
        if current == nil then return nil end
        local value = current.value
        current = current.next
        return value
    end
end