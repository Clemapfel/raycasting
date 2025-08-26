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
        _nodes = {},
        _lines = {}
    })
end

--- @brief
--- @param
function ow.PathfindingGraph:add(a, b)
    meta.assert(a, ow.PathfindingNode, b, ow.PathfindingNode)
    local distance = math.distance(a.x, a.y, b.x, b.y)

    local a_data = self._nodes[a]
    if a_data == nil then
        a_data = {}
        self._nodes[a] = a_data
    end
    a_data[b] = distance

    local b_data = self._nodes[b]
    if b_data == nil then
        b_data = {}
        self._nodes[b] = b_data
    end
    b_data[a] = distance

    table.insert(self._lines, {
        a.x, a.y, b.x, b.y
    })
end

--- @brief
function ow.PathfindingGraph:get_path(from, to)
    local function heuristic(node_a, node_b)
        -- euclidean distance as heuristic
        local dx = node_b.x - node_a.x
        local dy = node_b.y - node_a.y
        return math.sqrt(dx * dx + dy * dy)
    end

    local open_set = {[from] = true}
    local came_from = {}
    local g_score = {[from] = 0}
    local f_score = {[from] = heuristic(from, to)}

    while next(open_set) do
        -- find node in open_set with lowest f_score
        local current, current_f_score = nil, math.huge
        for node in pairs(open_set) do
            if f_score[node] < current_f_score then
                current, current_f_score = node, f_score[node]
            end
        end

        if current == to then
            -- reconstruct path
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = came_from[current]
            end
            local out = {}
            for _, node in ipairs(path) do
                table.insert(out, node.x)
                table.insert(out, node.y)
            end
            return out
        end

        open_set[current] = nil

        for neighbor, _ in pairs(self._nodes[current]) do
            local tentative_g_score = g_score[current] + heuristic(current, neighbor)
            if tentative_g_score < (g_score[neighbor] or math.huge) then
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = tentative_g_score + heuristic(neighbor, to)
                if not open_set[neighbor] then
                    open_set[neighbor] = true
                end
            end
        end
    end

    return nil -- no path found
end

--- @brief
function ow.PathfindingGraph:get_closest_node(x, y)
    local min_distance = math.huge
    local min_node = nil
    for node in keys(self._nodes) do
        local distance = math.distance(node.x, node.y, x, y)
        if distance < min_distance then
            min_distance = distance
            min_node = node
        end
    end

    return min_node
end

--- @brief
function ow.PathfindingGraph:get_closest_reachable_node(x, y, world, radius)
    meta.assert(x, "Number", y, "Number", world, b2.World, radius, "Number")

    local nodes = {}
    for node in keys(self._nodes) do
        table.insert(nodes, {
            node = node,
            distance = math.distance(node.x, node.y, x, y)
        })
    end

    table.sort(nodes, function(a, b) -- sort to minimize circle casting
        return a.distance < b.distance
    end)

    for entry in values(nodes) do
        local node = entry.node
        local occluded = world:circle_cast(radius, x, y, node.x, node.y)
        if not occluded then
            return node
        end
    end
end

--- @brief
function ow.PathfindingGraph:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    for line in values(self._lines) do
        love.graphics.line(table.unpack(line))
    end

    for node in keys(self._nodes) do
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("fill", node.x, node.y, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", node.x, node.y, 3)
    end
end
