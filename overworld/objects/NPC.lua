require "common.delaunay_triangulation"

rt.settings.overworld.npc = {
    segment_length = 10,
    buffer_depth = rt.settings.player.radius
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

local _collision_group = b2.CollisionGroup.GROUP_07

local _data_mesh_format = {
    { location = 4, name = "origin", format = "floatvec2" }, -- spring origin
    { location = 5, name = "contour_vector", format = "floatvec3" } -- normalized xy, z is length
}


--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._velocity_x = 0
    self._velocity_y = 0

    self._world = stage:get_physics_world()

    -- inner, hard-body shell
    local contour = object:create_contour()
    contour = rt.subdivide_contour(contour, rt.settings.overworld.npc.segment_length * rt.get_pixel_scale())

    local centroid_x, centroid_y = 0, 0
    for i = 1, #contour, 2 do
        local cx, cy = contour[i+0], contour[i+1]
        centroid_x = centroid_x + cx
        centroid_y = centroid_y + cy
    end

    centroid_x = centroid_x / #contour
    centroid_y = centroid_y / #contour

    -- translate to origin
    for i = 1, #contour, 2 do
        contour[i+0] = contour[i+0] - centroid_x
        contour[i+1] = contour[i+1] - centroid_y
    end

    local delaunay = rt.DelaunayTriangulation()

    -- inner hard object
    table.insert(contour, centroid_x)
    table.insert(contour, centroid_y)
    delaunay:triangulate(contour, contour)
    local shapes = {}
    for tri in values(delaunay:get_triangles()) do
        table.insert(shapes, b2.Polygon(table.unpack(tri)))
    end

    self._body = b2.Body(stage:get_physics_world(), b2.BodyType.DYNAMIC, centroid_x, centroid_y, shapes)


    -- outer, soft-body shell
    self._data_mesh_data = {}
    local depth = rt.settings.overworld.npc.buffer_depth
    local outer_contour = {}
    for i = 1, #contour, 2 do
        local cx, cy = contour[i+0], contour[i+1]
        local dx, dy = cx - centroid_x, cy - centroid_y
        local length = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)
        table.insert(outer_contour, cx + dx * (length + depth))
        table.insert(outer_contour, cy + dy * (length + depth))

        table.insert(self._data_mesh_data, {
            cx + length * dx, -- vector origin
            cy + length * dy,
            dx, dy, depth -- normalized xy, magnitude
        })
    end

    self._inner_contour = contour
    self._outer_contour = outer_contour
end

--- @brief
function ow.NPC:draw()
    self._body:draw()
    love.graphics.line(self._inner_contour)
    love.graphics.line(self._outer_contour)
end

--- @brief
function ow.NPC:update(delta)
end