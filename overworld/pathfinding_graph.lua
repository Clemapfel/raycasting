--- @class ow.PathfindingGraph
ow.PathfindingGraph = meta.class("PathfindingGraph")

--- @class ow.PathfindingNode
ow.PathfindingNode = meta.class("PathfindingNode")

--- @brief
function ow.PathfindingNode:instantiate(x, y)
    self.x = x
    self.y = y
end

--- @brief
function ow.PathfindingGraph:instantiate()
    meta.install(self, {
        _nodes = {},
        _lines = {}
    })
end

--- @brief add a new edge
--- @param a ow.PathfindingNode
--- @param b ow.PathfindingNode
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

--- @brief finde a path from one node to another, uses A*
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
