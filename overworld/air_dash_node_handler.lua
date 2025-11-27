--- @class ow.AirDashNodeHandler
ow.AirDashNodeHandler = meta.class("AirDashNodeHandler")

--- @brief
function ow.AirDashNodeHandler:instantiate(stage)
    self._stage = stage
    self._nodes = meta.make_weak({})
end

--- @brief
function ow.AirDashNodeHandler:notify_node_added(node)
    table.insert(self._nodes, node)
end