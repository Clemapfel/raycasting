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
        _data = {}
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
end

--- @brief
function ow.PathfindingGraph:get_path(from, to)
    local function get_edge_weight(a, b)
        returself._data[a][b]
    end

end