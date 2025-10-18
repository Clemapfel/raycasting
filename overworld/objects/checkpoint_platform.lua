--- @class CheckpointPlatform
ow.CheckpointPlatform = meta.class("CheckpointPlatform")

local _shader = rt.Shader("overworld/objects/checkpoint_platform.glsl")

--- @brief
function ow.CheckpointPlatform:instantiate(x1, y1, x2, y2, radius)
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "p" then _shader:recompile() end
    end)

    self._color = { rt.lcha_to_rgba(0.8, 1, 0, 1) }

    meta.assert(x1, "Number", y1, "Number", x2, "Number", y2, "Number")

    local inner_thickness = 0.25 * radius
    local outer_thickness = radius

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
    function add_vertex(x, y, u, v, alpha)
        table.insert(mesh_data, { x, y, u, v, 1, 1, 1, alpha })
    end

    add_vertex(inner_top_left_x, inner_top_left_y, 0/4,   1, 1)
    add_vertex(inner_top_right_x, inner_top_right_y, 1/4, 1, 1)
    add_vertex(inner_bottom_right_x, inner_bottom_right_y, 2/4, 1, 1)
    add_vertex(inner_bottom_left_x, inner_bottom_left_y, 3/4,   1, 1)
    add_vertex(inner_top_left_x, inner_top_left_y, 4/4,   1, 1) -- duplicate for wrapping

    add_vertex(outer_top_left_x, outer_top_left_y, 0,   0, 0)
    add_vertex(outer_top_right_x, outer_top_right_y, 1/4, 0, 0)
    add_vertex(outer_bottom_right_x, outer_bottom_right_y, 2/4, 0, 0)
    add_vertex(outer_bottom_left_x, outer_bottom_left_y, 3/4,   0, 0)
    add_vertex(outer_top_left_x, outer_top_left_y, 4/4,   0, 0) -- duplicate for wrapping

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._mesh:set_vertex_map({
        1, 2, 3,  1, 3, 4,

        1, 6, 2,   2, 6, 7,
        2, 7, 3,   3, 7, 8,
        3, 8, 4,   4, 8, 9,

        4, 9, 5,   5, 9, 10
    })
end

--- @brief
function ow.CheckpointPlatform:draw()
    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("color", self._color)
    _shader:send("bloom_active", false)
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    _shader:unbind()
end

--- @brief
function ow.CheckpointPlatform:draw_bloom()
    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("color", self._color)
    _shader:send("bloom_active", true)
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    _shader:unbind()
end

--- @brief
function ow.CheckpointPlatform:set_hue(hue)
    self._color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }
end