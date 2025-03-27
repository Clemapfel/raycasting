--- @class ow.PathfindingGraph
ow.PathfindingGraph = meta.class("PathfindingGraph")

--- @class ow.PathfindingNode
ow.PathfindingNode = meta.class("PathfindingNode")

--- @brief
function ow.PathfindingNode:instantiate(object, stage, scene)
    assert(object.type == ow.ObjectType.POINT, "In ow.PathfindingNode: object is not a point")
    meta.install(self, {
        x = object.x,
        y = object.y
    })

    stage:signal_connect("initialized", function(_)
        local graph = stage:get_pathfinding_graph()
        for key, value in pairs(object.properties) do
            local as_number = tonumber(key)
            if as_number ~= nil then
                local other = stage:get_object_instance(value)
                if meta.typeof(other) == "PathfindingNode" then
                    graph:add(self, other) -- add edge
                else
                    rt.warning("In ow.PathfindingNode: property `" .. key .. "` has numerical key, but does not point to other PathfindingNode")
                end
            end
        end
    end)
end

--- @brief
function ow.PathfindingGraph:instantiate()
    meta.install(self, {
        _data = {},
        _lines = {}
    })
end

--- @brief
--- @param
function ow.PathfindingGraph:add(a, b)
    meta.assert(a, ow.PathfindingNode, b, ow.PathfindingNode)
    local distance = math.distance(a.x, a.y, b.x, b.y)

    local a_data = self._data[a]
    if a_data == nil then
        a_data = {}
        self._data[a] = a_data
    end
    a_data[b] = distance

    local b_data = self._data[b]
    if b_data == nil then
        b_data = {}
        self._data[b] = b_data
    end
    a_data[a] = distance

    table.insert(self._lines, {
        a.x, a.y, b.x, b.y
    })
end

--- @brief
function ow.PathfindingGraph:_a_star(from, to)
    local function heuristic(node, goal)
        return math.distance(node.x, node.y, goal.x, goal.y)
    end

    -- https://en.wikipedia.org/wiki/A*_search_algorithm#Pseudocode
    local open_set = {[from] = true}
    local came_from = {}
    local g_score = {[from] = 0}
    local f_score = {[from] = heuristic(from, to)}

    while next(open_set) do
        local current = nil
        local lowest_f_score = math.huge
        for node in pairs(open_set) do
            if f_score[node] < lowest_f_score then
                lowest_f_score = f_score[node]
                current = node
            end
        end

        if current == to then
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = came_from[current]
            end
            return path
        end

        open_set[current] = nil

        for neighbor, weight in pairs(self._data[current] or {}) do
            local tentative_g_score = g_score[current] + weight
            if tentative_g_score < (g_score[neighbor] or math.huge) then
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = tentative_g_score + heuristic(neighbor, to)
                open_set[neighbor] = true
            end
        end
    end

    return nil -- no path is found
end

--- @brief
function ow.PathfindingGraph:get_path(from, to)
    meta.assert_isa(from, ow.PathfindingNode, to, ow.PathfindingNode)

    local path_data = {}
    for node in values(self:_a_star(from, to)) do
        table.insert(path_data, node.x)
        table.insert(path_data, node.y)
    end

    return rt.Path(path_data)
end

--- @brief
function ow.PathfindingGraph:get_closest_node(x, y)
    local min_distance = math.huge
    local min_node = nil
    for node in keys(self._data) do
        local distance = math.distance(node.x, node.y, x, y)
        if distance < min_distance then
            min_distance = distance
            min_node = node
        end
    end

    return min_node.x, min_node.y
end

--- @brief
function ow.PathfindingGraph:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    for line in values(self._lines) do
        love.graphics.line(table.unpack(line))
    end

    for node in keys(self._data) do
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", node.x, node.y, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", node.x, node.y, 3)
    end
end
