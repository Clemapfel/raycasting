require "common.drawable"

--- @class rt.SelectionGraph
rt.SelectionGraph = meta.class("SelectionGraph", rt.Drawable)

function rt.SelectionGraph:instantiate()
    meta.install(self, {
        _nodes = {}, -- Set<rt.SelectionGraphNode>
        _current_node = nil,
        _n_nodes = 0
    })
end

local _noop_function = function() return nil end

--- @class rt.SelectionGraphNode
--- @signal enter (rt.SelectionGraphNode) -> nil
--- @signal exit (rt.SelectionGraphNode) -> nil
--- @signal rt.InputButton.UP (rt.SelectionGraphNode) -> rt.SelectionGraphNode
--- @signal rt.InputButton.RIGHT (rt.SelectionGraphNode) -> rt.SelectionGraphNode
--- @signal rt.InputButton.DOWN (rt.SelectionGraphNode) -> rt.SelectionGraphNode
--- @signal rt.InputButton.LEFT (rt.SelectionGraphNode) -> rt.SelectionGraphNode
--- @signal rt.InputButton.A (rt.SelectionGraphNode) -> nil
--- @signal rt.InputButton.B (rt.SelectionGraphNode) -> nil
--- @signal rt.InputButton.X (rt.SelectionGraphNode) -> nil
--- @signal rt.InputButton.Y (rt.SelectionGraphNode) -> nil
rt.SelectionGraphNode = meta.class("SelectionGraphNode", rt.Drawable)
function rt.SelectionGraphNode:instantiate(aabb)
    meta.install(self, {
        _aabb = rt.AABB(0, 0, 1, 1),
        _control_layout_function = function() return {} end,
        _centroid_x = 0,
        _centroid_y = 0,
        _up = _noop_function,
        _right = _noop_function,
        _down = _noop_function,
        _left = _noop_function
    })

    if aabb ~= nil then
        self._aabb = aabb
        self._centroid_x = aabb.x + 0.5 * aabb.width
        self._centroid_y = aabb.y + 0.5 * aabb.height
    end
end

meta.add_signals(rt.SelectionGraphNode,
    "enter",
    "exit",
    rt.InputButton.A,
    rt.InputButton.B,
    rt.InputButton.X,
    rt.InputButton.Y,
    "leave_up",
    "leave_down",
    "leave_left",
    "leave_right",
    "enter_up",
    "enter_down",
    "enter_left",
    "enter_right"
)

--- @brief
function rt.SelectionGraphNode:set_bounds(aabb_or_x, y, w, h)
    if meta.typeof(aabb_or_x) == "AABB" then
        self._aabb = aabb_or_x
    else
        self._aabb = rt.AABB(aabb_or_x, y, w, h)
    end

    self._centroid_x = self._aabb.x + 0.5 * self._aabb.width
    self._centroid_y = self._aabb.y + 0.5 * self._aabb.height
end

--- @brief
function rt.SelectionGraphNode:get_bounds()
    return rt.aabb_copy(self._aabb)
end

for which in range("_up", "_right", "_down", "_left") do
    --- @brief set_up, set_right, set_down, set_left
    rt.SelectionGraphNode["set" .. which] = function(self, next)
        if next == nil then
            self[which] = _noop_function
        elseif meta.is_function(next) then
            self[which] = next
        else
            meta.assert_isa(next, rt.SelectionGraphNode)
            self[which] = function(self)
                return next
            end
        end
    end

    --- @brief get_up, get_right, get_down, get_left
    rt.SelectionGraphNode["get" .. which] = function(self)
        return self[which](self)
    end
end

--- @brief

function rt.SelectionGraphNode:draw(color)
    love.graphics.setColor(rt.color_unpack(color))

    local centroid_x, centroid_y = self._centroid_x, self._centroid_y
    local top, right, bottom, left = self._up(self), self._right(self), self._down(self), self._left(self)
    for node in range(top, right, bottom, left) do -- automatically skips nils
        love.graphics.line(centroid_x, centroid_y, node._centroid_x, node._centroid_y)
    end

    love.graphics.circle("fill", centroid_x, centroid_y, 4)
    love.graphics.rectangle("line", self._aabb.x, self._aabb.y, self._aabb.width, self._aabb.height)
end

--- ###

do
    local _button_to_function_member = {
        [rt.InputButton.UP] = "_up",
        [rt.InputButton.RIGHT] = "_right",
        [rt.InputButton.DOWN] = "_down",
        [rt.InputButton.LEFT] = "_left"
    }

    local _button_to_leave_directional_signal = {
        [rt.InputButton.UP] = "leave_up",
        [rt.InputButton.RIGHT] = "leave_right",
        [rt.InputButton.DOWN] = "leave_down",
        [rt.InputButton.LEFT] = "leave_left"
    }

    local _button_to_enter_directional_signal = {
        [rt.InputButton.UP] = "enter_down",
        [rt.InputButton.RIGHT] = "enter_left",
        [rt.InputButton.DOWN] = "enter_up",
        [rt.InputButton.LEFT] = "enter_right"
    }

    --- @brief
    function rt.SelectionGraph:handle_button(button)
        local current = self._current_node
        if current == nil then return end

        if button == rt.InputButton.A or button == rt.InputButton.B or button == rt.InputButton.X or button == rt.InputButton.Y then
            current:signal_emit(button)
        else
            local f = _button_to_function_member[button]
            if f ~= nil then
                local next = current[f](current)
                if next ~= nil then
                    if not meta.isa(next, rt.SelectionGraphNode) then
                        rt.error("In rt.SelectionGraph:handle_button: node #" .. meta.hash(current) .. " returns object of type `" .. meta.typeof(next) .. "` on `" .. button .. "` instead of rt.SelectionGraphNode")
                        return
                    end
                    current:signal_emit(_button_to_leave_directional_signal[button])
                    current:signal_emit("exit")
                    self._current_node = next
                    next:signal_emit("enter")
                    next:signal_emit(_button_to_enter_directional_signal[button])
                end
            end
        end
    end
end

--- @brief
function rt.SelectionGraph:add(...)
    for node in range(...) do
        meta.assert_isa(node, rt.SelectionGraphNode)
        if self._nodes[node] == nil then
            self._nodes[node] = true
            if self._n_nodes == 0 then
                self._current_node = node
                self._current_node:signal_emit("enter")
            end
            self._n_nodes = self._n_nodes + 1
        end
    end
end

--- @brief
function rt.SelectionGraph:remove(node)
    if self._nodes[node] ~= nil then
        self._nodes[node] = nil
        self._n_nodes = self._n_nodes - 1
    end
end

--- @brief
function rt.SelectionGraph:set_current_node(node)
    self:add(node)

    if self._current_node ~= nil then
        self._current_node:signal_emit("exit")
    end

    self._current_node = node

    if self._current_node ~= nil then
        self._current_node:signal_emit("enter")
    end
end

--- @brief
function rt.SelectionGraph:get_current_node()
    return self._current_node
end

--- @brief
function rt.SelectionGraph:get_current_node_aabb()
    if self._current_node ~= nil then
        return self._current_node._aabb
    else
        return rt.AABB(0, 0, 1, 1)
    end
end

--- @brief
function rt.SelectionGraph:draw()
    love.graphics.setLineWidth(3)
    for node in keys(self._nodes) do
        node:draw(rt.Palette.GRAY_4)
    end

    if self._current_node ~= nil then
        self._current_node:draw(rt.Palette.SELECTION)
    end
end

--- @brief
function rt.SelectionGraph:clear()
    for node in keys(self._nodes) do
        node:signal_emit("exit")
    end
    self._nodes = {}
    self._current_node = nil
end