--- @class ow.FlowGraph
ow.FlowGraphNode = meta.class("FlowGraphNode")

--- @brief
function ow.FlowGraphNode:instantiate(object, stage, scene)
    stage:signal_connect("initialized", function()
        self.object = object
        local next = object:get_object("next")
        if next ~= nil then
            self.next = stage:object_wrapper_to_instance(object:get_object("next"))
        end

        self.x = object.x
        self.y = object.y
    end)

    stage:_notify_flow_graph_node_added(self)
end

--- @class ow.FlowGraphNode
ow.FlowGraph = meta.class("FlowGraph")

--- @brief
--- @param nodes Table<ow.FlowGraphNode>?
function ow.FlowGraph:instantiate(nodes)
    self._entries = {}
    if nodes ~= nil then
        self:initialize(nodes)
    end
end

--- @brief
--- @param nodes Table<ow.FlowGraphNode>
function ow.FlowGraph:initialize(nodes)
    if table.sizeof(nodes) < 2 then
        rt.error("In ow.FlowGraph: need at least two nodes to construct a graph")
    end

    self._segments = {}
    self._last_fraction = 0

    local node_to_does_not_have_next = {}
    local node_to_does_not_have_previous = {}

    for node in values(nodes) do
        node_to_does_not_have_next[node] = true
        node_to_does_not_have_previous[node] = true
    end

    for node in values(nodes) do
        local current = node
        local next = node.next

        if next ~= nil then
            node_to_does_not_have_next[current] = nil
            node_to_does_not_have_previous[next] = nil
        end
    end

    -- check that only one node is a leaf
    if table.sizeof(node_to_does_not_have_next) > 1 then
        local ids, n = {}, 0
        for node in keys(node_to_does_not_have_next) do
            table.insert(ids, node.object.id)
            n = n + 1
        end

        local to_concat = {}
        for i = 1, n do
            local id = ids[i]
            if i == n then
                table.insert(to_concat, id)
            else
                table.insert(to_concat, id .. ", ")
            end
        end

        rt.error("In ow.FlowGraph.initialize: multiple nodes do not have a next, graph has multiple leaves. List of nodes: " .. table.concat(to_concat))
    end

    -- check that only one node is root
    if table.sizeof(node_to_does_not_have_previous) > 1 then
        local ids, n = {}, 0
        for node in keys(node_to_does_not_have_previous) do
            table.insert(ids, node.object.id)
            n = n + 1
        end

        local to_concat = {}
        for i = 1, n do
            local id = ids[i]
            if i == n then
                table.insert(to_concat, id)
            else
                table.insert(to_concat, id .. ", ")
            end
        end

        rt.error("In ow.FlowGraph.initialize: multiple nodes do not have a previous, graph has multiple roots. List of nodes: " .. table.concat(to_concat))
    end

    local root
    for node in keys(node_to_does_not_have_previous) do
        root = node
        break
    end

    if root == nil then
        rt.error("In ow.FlowGraph.initialize: graph does not have a node that has no previous")
    end

    self._last_x, self._last_y = root.x, root.y
    self._last_player_x,self._last_player_y = root.x, root.y

    -- construct path as nodes in order
    local current = root
    local next = root.next
    local path = {}
    local n_entries = 0

    local total_length = 0
    while next ~= nil do
       local entry = {
            current = current,
            next = next,
            length = math.distance(current.x, current.y, next.x, next.y),
            x1 = current.x,
            y1 = current.y,
            x2 = next.x,
            y2 = next.y,
            start_fraction = 0,
            finish_fraction = 0,
        }

        total_length = total_length + entry.length
        n_entries = n_entries + 1
        table.insert(path, entry)

        local after = current.next
        current = next
        next = after
    end

    self._entries = path
    self._n_entries = n_entries


    -- precompute fractions
    local current_length = 0
    for i = 1, n_entries do
        local entry = self._entries[i]
        local start = current_length / total_length
        current_length = current_length

        local finish = (current_length + entry.length) / total_length
        entry.start_fraction = start
        entry.finish_fraction = finish
    end
end

function _point_to_segment(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length_sq = dx * dx + dy * dy

    local t = ((px - x1) * dx + (py - y1) * dy) / length_sq
    t = math.max(0, math.min(1, t))

    local nearest_x = x1 + t * dx
    local nearest_y = y1 + t * dy

    local dist_x = px - nearest_x
    local dist_y = py - nearest_y
    return math.sqrt(dist_x * dist_x + dist_y * dist_y), nearest_x, nearest_y
end

--- @brief
--- @return Number fraction
function ow.FlowGraph:update_player_position(player_x, player_y)
    -- find closest segment, and point on that segment
    local fraction, closest_x, closest_y = self:get_fraction(player_x, player_y)
    self._last_fraction = fraction
    self._last_x, self._last_y = closest_x, closest_y
    self._last_player_x, self._last_player_y = player_x, player_y
    return fraction, closest_x, closest_y
end

--- @brief
function ow.FlowGraph:get_fraction(x, y)
    meta.assert(x, "Number", y, "Number")
    local min_distance, min_entry, closest_x, closest_y = math.huge, nil, nil, nil, nil
    for i = 1, self._n_entries do
        local entry = self._entries[i]
        local distance, segment_x, segment_y = _point_to_segment(x, y, entry.x1, entry.y1, entry.x2, entry.y2)
        if distance < min_distance then
            min_distance = distance
            min_entry = entry
            closest_x = segment_x
            closest_y = segment_y
        end
    end

    local local_fraction = math.distance(min_entry.x1, min_entry.y1, closest_x, closest_y) / min_entry.length
    local total_fraction = min_entry.start_fraction + local_fraction * (min_entry.finish_fraction - min_entry.start_fraction)

    return total_fraction, closest_x, closest_y
end

--- @brief
function ow.FlowGraph:draw()
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0, 1, 0, 1)
    for i = 1, self._n_entries do
        local entry = self._entries[i]
        love.graphics.line(entry.x1, entry.y1, entry.x2, entry.y2)
        love.graphics.circle("fill", entry.x1, entry.y1, 2)
    end

    love.graphics.setColor(1, 0, 1, 1)
    love.graphics.circle("fill", self._last_x, self._last_y, 4)
end
