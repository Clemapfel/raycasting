--- @class ow.PathfindingGraph
ow.PathfindingGraph = meta.class("PathfindingGraph")

--- @class ow.PathfindingNode
ow.PathfindingNode = meta.class("PathfindingNode")

--- @brief
function ow.PathfindingNode:instantiate(object, stage, scene)
    local graph = stage:get_pathfinding_graph()
    assert(object.type == ow.ObjectType.POINT, "In ow.PathfindingNode: object is not a point")
    meta.install(self, {
        x = object.x,
        y = object.y
    })

    stage:signal_connect("initialized", function(_)

    end)
end