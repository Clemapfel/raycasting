--- @class CheckpointPlatform
ow.CheckpointPlatform = meta.class("CheckpointPlatform")

--- @brief
function ow.CheckpointPlatform:instantiate(x1, y1, x2, y2, radius)
    meta.assert(x1, "Number", y1, "Number", x2, "Number", y2, "Number")
    self._x1 = math.min(x1, x2)
    self._y1 = math.min(y1, y2)
    self._x2 = math.max(x1, x2)
    self._y2 = math.max(y1, y2)

    -- create mesh
    local dx = self._x2 - self._x1
    local dy = self._y2 - self._y1

    local ndx, ndy = math.normalize(dx, dy)
    local left_x, left_y = math.turn_left(ndx, ndy)
    local right_x, right_y = math.turn_right(ndx, ndy)

    local inner_thickness = 2 * radius
    local outer_thickness = radius

    -- vertices
    local inner_top_left_x = x1 + left_x * inner_thickness
    local inner_top_left_y = y1 + left_y * inner_thickness

    local inner_top_right_x = x2 + left_x * inner_thickness
    local inner_top_right_y = y2 + left_y * inner_thickness

    local inner_bottom_right_x = x2 + right_x * inner_thickness
    local inner_bottom_right_y = y2 + right_y * inner_thickness

    local inner_bottom_left_x = x1 + right_x * inner_thickness
    local inner_bottom_left_y = y1 + right_y * inner_thickness

    local outer_top_left_x = inner_top_left_x - ndx * outer_thickness - right_x * outer_thickness
    local outer_top_left_y = inner_top_left_y - ndy * outer_thickness - right_y * outer_thickness

    local outer_top_right_x = inner_top_right_x + ndx * outer_thickness + right_x * outer_thickness
    local outer_top_right_y = inner_top_right_y - ndy * outer_thickness - right_y * outer_thickness

    local outer_bottom_right_x = inner_bottom_right_x + ndx * outer_thickness + right_x * outer_thickness
    local outer_bottom_right_y = inner_bottom_right_y + ndy * outer_thickness + right_y * outer_thickness

    local outer_bottom_left_x = inner_bottom_left_x - ndx * outer_thickness - right_x * outer_thickness
    local outer_bottom_left_y = inner_bottom_left_y + ndy * outer_thickness + right_y * outer_thickness

    local mesh_data = {}
    function add_vertex(x, y, opacity)
        table.insert(mesh_data, { x, y, 0, 0, 1, 1, 1, opacity })
    end

    add_vertex(inner_top_left_x, inner_top_left_y, 1)
    add_vertex(inner_top_right_x, inner_top_right_y, 1)
    add_vertex(inner_bottom_right_x, inner_bottom_right_y, 1)
    add_vertex(inner_bottom_left_x, inner_bottom_left_y, 1)
    add_vertex(outer_top_left_x, outer_top_left_y, 0)
    add_vertex(outer_top_right_x, outer_top_right_y, 0)
    add_vertex(outer_bottom_right_x, outer_bottom_right_y, 0)
    add_vertex(outer_bottom_left_x, outer_bottom_left_y, 0)

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._mesh:set_vertex_map({
        1, 2, 3,
        1, 3, 4,
        1, 5, 2,
        2, 5, 6,
        2, 6, 3,
        3, 6, 7,
        3, 4, 8,
        3, 7, 8,
        1, 5, 8,
        1, 4, 8
    })
end

--- @brief
function ow.CheckpointPlatform:draw()
    self._mesh:draw()
end

--- @brief
function ow.CheckpointPlatform:draw_bloom()
    -- TODO
end