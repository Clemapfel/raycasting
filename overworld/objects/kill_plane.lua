require "common.contour"
require "overworld.movable_object"

rt.settings.overworld.kill_plane = {
    border_width = 20
}

--- @class ow.KillPlane
--- @types Polygon, Rectangle, Ellipse
--- @field is_visible Boolean?
ow.KillPlane = meta.class("KillPlane", ow.MovableObject)

local _inner_shader = rt.Shader("overworld/objects/kill_plane.glsl", { MODE = 0 })
local _outer_shader = rt.Shader("overworld/objects/kill_plane.glsl", { MODE = 1 })

function ow.KillPlane:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    -- collision
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._is_blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            if self._is_blocked == true then return end
            self._is_blocked = true
            self._stage:get_physics_world():signal_connect("step", function()
                self._is_blocked = false
                return meta.DISCONNECT_SIGNAL
            end)
        end
    end)

    -- visibility : disable mesh
    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end
    if self._is_visible == false then return end

    -- inner mesh solid
    self._inner_mesh = nil

    self._contour = object:create_contour()
    local center_x, center_y = object:get_centroid()
    local n = 0
    for i = 1, #self._contour, 2 do
        self._contour[i+0] = self._contour[i+0] - center_x
        self._contour[i+1] = self._contour[i+1] - center_y
        n = n + 1
    end

    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    if rt.contour.is_convex(self._contour) then
        -- if convex, use regular centroid
        local vertex_map = {}
        local inner_mesh_data = {
            {
              0, 0,
              0, 0,
              0, 0, 0, 0
            }
        }

        for i = 1, #self._contour, 2 do
            table.insert(inner_mesh_data, {
                self._contour[i+0], self._contour[i+1], 1, 1, 1, 1, 1, 1
            })
        end

        self._inner_mesh = rt.Mesh(
            inner_mesh_data,
            rt.MeshDrawMode.TRIANGLE_FAN
        )
    else
        -- if concave, first use common centroid for triangulation
        -- then use triangle-weighted centroid for fraction

        local inner_mesh_data = {}
        local temp = table.deepcopy(self._contour)
        table.insert(temp, 1, center_x)
        table.insert(temp, 1, center_y)

        local triangles = rt.DelaunayTriangulation(temp, temp):get_triangles()
        local data = {}

        local total_area = 0
        for tri in values(triangles) do
            local x1, y1, x2, y2, x3, y3 = table.unpack(tri)
            local cx = (x1 + x2 + x3) / 3
            local cy = (y1 + y2 + y3) / 3
            local area = 0.5 * math.abs((x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2)))

            table.insert(data, {
                cx, cy, area
            })
            total_area = total_area + area
        end

        center_x, center_y, n = 0, 0
        for t in values(data) do
            local weight = t[3] / total_area
            center_x = center_x + t[1] * weight
            center_y = center_y + t[2] * weight
        end

        local max_distance = -math.huge
        for i = 1, #self._contour, 2 do
            max_distance = math.max(max_distance, math.distance(center_x, center_y, self._contour[1], self._contour[2]))
        end

        for tri_i, tri in ipairs(triangles) do
            for i = 1, #tri, 2 do
                local x, y = tri[i+0], tri[i+1]
                local t = math.distance(x, y, center_x, center_y) / max_distance

                    data = {
                        x, y, 0, 0, t, t, t, t
                    }


                table.insert(inner_mesh_data, data)
            end
        end

        self._inner_mesh = rt.Mesh(
            inner_mesh_data,
            rt.MeshDrawMode.TRIANGLES
        )
    end

    -- outer mesh

    self._outer_mesh = nil
    local arc_lengths = { 0 } -- cumulative distances
    local total_perimeter = 0

    for i = 1, #self._contour - 2, 2 do
        local x1, y1 = self._contour[i+0], self._contour[i+1]
        local x2, y2 = self._contour[i+2], self._contour[i+3]
        total_perimeter = total_perimeter + math.distance(x1, y1, x2, y2)
        table.insert(arc_lengths, total_perimeter)
    end

    local outer_mesh_data = {}
    local outer_mesh_vertex_map = {}

    local border_w = rt.settings.overworld.kill_plane.border_width

    local _contour_x1, _contour_y1, _contour_x2, _contour_y2 = 1, 2, 3, 4
    local _outer_x1, _outer_y1, _outer_x2, _outer_y2 = 5, 6, 7, 8

    local quads = {}
    for i = 1, #self._contour - 2, 2 do
        local contour_x1, contour_y1 = self._contour[i+0], self._contour[i+1]
        local contour_x2, contour_y2 = self._contour[i+2], self._contour[i+3]

        local dx, dy = math.normalize(contour_x2 - contour_x1, contour_y2 - contour_y1)
        dx, dy = math.turn_right(dx, dy)

        local outer_x1, outer_y1 = contour_x1 + dx * border_w, contour_y1 + dy * border_w
        local outer_x2, outer_y2 = contour_x2 + dx * border_w, contour_y2 + dy * border_w

        table.insert(quads, {
            [_contour_x1] = contour_x1,
            [_contour_y1] = contour_y1,
            [_contour_x2] = contour_x2,
            [_contour_y2] = contour_y2,
            [_outer_x1] = outer_x1,
            [_outer_y1] = outer_y1,
            [_outer_x2] = outer_x2,
            [_outer_y2] = outer_y2,
        })
    end

    local function _segment_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
        local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

        if denom == 0 then
            return nil
        end

        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom

        if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
            local px = x1 + t * (x2 - x1)
            local py = y1 + t * (y2 - y1)
            return px, py
        end

        return nil
    end

    local vertex_i = 1
    for quad_i = 1, #quads do
        local current = quads[quad_i+0]
        local next = quads[(quad_i % #quads) + 1]

        local ix, iy = _segment_intersection(
            current[_outer_x1], current[_outer_y1], current[_outer_x2], current[_outer_y2],
            next[_outer_x1], next[_outer_y1], next[_outer_x2], next[_outer_y2]
        )

        if ix ~= nil then -- concave corner, quads would overlap
            current[_outer_x2], current[_outer_y2] = ix, iy
            next[_outer_x1], next[_outer_y1] = ix, iy
        end

        -- calculate normalized arc-length texture coordinates
        local u1 = arc_lengths[quad_i] / total_perimeter
        local u2 = arc_lengths[quad_i + 1] / total_perimeter

        table.insert(outer_mesh_data, {
            current[_contour_x1], current[_contour_y1], u1, 0, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            current[_contour_x2], current[_contour_y2], u2, 0, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            current[_outer_x1], current[_outer_y1], u1, 1, 0, 0, 0, 1
        })

        table.insert(outer_mesh_data, {
            current[_outer_x2], current[_outer_y2], u2, 1, 0, 0, 0, 1
        })

        for j in range(
            vertex_i + 0, vertex_i + 1, vertex_i + 2,
            vertex_i + 1, vertex_i + 2, vertex_i + 3
        ) do
            table.insert(outer_mesh_vertex_map, j)
        end

        vertex_i = vertex_i + 4
    end

    -- fill triangles
    local n_vertices = vertex_i
    for i = 1, n_vertices - 6, 4 do
        for j in range(
            i + 1, -- contour
            i + 3, -- current outer
            i + 4 + 2 -- next outer
        ) do
            table.insert(outer_mesh_vertex_map, j)
        end
    end

    -- last fill triangle needs special vertices
    if n_vertices >= 9 then -- ensure at least two quads exist
        local inner = table.deepcopy(outer_mesh_data[n_vertices - 3])
        local outer_last = table.deepcopy(outer_mesh_data[n_vertices - 1])
        local outer_first = table.deepcopy(outer_mesh_data[3])

        -- replace arc length parameterized texture coord to avoid interpolation
        for vertex in range(outer_last, outer_first) do
            vertex[3] = 1
        end

        local i = n_vertices
        for vertex in range(inner, outer_last, outer_first) do
            table.insert(outer_mesh_data, vertex)
            table.insert(outer_mesh_vertex_map, i)
            i = i + 1
        end
    end

    self._outer_mesh = rt.Mesh(
        outer_mesh_data,
        rt.MeshDrawMode.TRIANGLES
    )
    self._outer_mesh:set_vertex_map(outer_mesh_vertex_map)
end

function ow.KillPlane:draw()
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    local px, py = self._scene:get_player():get_position()

    local transform = self._scene:get_camera():get_transform()
    local player_position = { transform:transform_point(px, py) }

    transform:translate(offset_x, offset_y)
    transform = transform:inverse()

    local red = { rt.Palette.MINT:unpack() }
    love.graphics.setColor(1, 1, 1, 1)


    _inner_shader:bind()
    _inner_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _inner_shader:send("player_position", player_position)
    _inner_shader:send("screen_to_world_transform", transform)
    _inner_shader:send("red", red)
    _inner_shader:send("center", { offset_x, offset_y })
    self._inner_mesh:draw()
    _inner_shader:unbind()

    _outer_shader:bind()
    _outer_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _outer_shader:send("screen_to_world_transform", transform)
    _outer_shader:send("red", red)
    self._outer_mesh:draw()
    _outer_shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.KillPlane:get_render_priority()
    return 2
end