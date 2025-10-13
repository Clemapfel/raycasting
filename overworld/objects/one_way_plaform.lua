rt.settings.overworld.one_way_platform = {
    thickness = 20
}

--- @class ow.OneWayPlatform
--- @types Rectangle
ow.OneWayPlatform = meta.class("OneWayPlatform")

--- @brief
function ow.OneWayPlatform:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    local x1, y1 = object.x, object.y
    local w, h = object.width, object.height
    local angle = object.rotation

    local dx, dy = math.rotate(w, 0, angle)
    local x2, y2 = x1 + dx, y1 + dy

    local shape = b2.Segment(x1, y1, x2, y2)
    shape:set_is_one_sided(true)

    local world = stage:get_physics_world()
    self._body = b2.Body(world, b2.BodyType.STATIC, 0, 0, shape)
    self._body:add_tag("stencil", "hitbox")
    self._body:add_tag("segment_light_source")
    self._body:set_user_data(self)

    local thickness = rt.settings.overworld.one_way_platform.thickness

    local sensor_r = rt.settings.player.radius
    local ldx, ldy = math.turn_left(math.normalize(dx, dy))
    local rdx, rdy = math.turn_right(math.normalize(dx, dy))
    self._sensor = b2.Body(world, b2.BodyType.STATIC, 0, 0, b2.Polygon(
        x1 + ldx * sensor_r,
        y1 + ldy * sensor_r,
        x1 + rdx * sensor_r,
        y1 + rdy * sensor_r,
        x2 + rdx * sensor_r,
        y2 + rdy * sensor_r,
        x2 + ldx * sensor_r,
        y2 + ldy * sensor_r
    ))
    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    self._sensor:signal_connect("collision_start", function(_)
        local player =  self._scene:get_player()

        -- buffer fallthrough
        if player._down_button_is_down then
            self._body:set_is_sensor(true)
        else
            player:signal_connect("duck", function(_)
                self._body:set_is_sensor(true)
                return meta.DISCONNECT_SIGNAL
            end)
        end
    end)

    self._sensor:signal_connect("collision_end", function(_)
        self._body:set_is_sensor(false)
    end)

    local mesh_data = {}
    self._line_draw_vertices = {}

    function add_vertex(x, y, u, v, v)
        table.insert(mesh_data, { x, y, u, v, 1, 1, 1, v })
    end

    local left_x, left_y, right_x, right_y = x1, y1, x2, y2
    local n_half_circle_vertices = 8
    local contour_points = {}

    dx, dy = math.normalize(dx, dy)
    local normal_x, normal_y = math.turn_left(dx, dy)

    for i = 0, n_half_circle_vertices - 1 do
        local t = ternary(n_half_circle_vertices == 1, 0, i / (n_half_circle_vertices - 1))
        local alpha = math.pi + t * math.pi
        local cos_alpha = math.cos(alpha)
        local sin_alpha = math.sin(alpha)
        local vx = normal_x * cos_alpha + dx * sin_alpha
        local vy = normal_y * cos_alpha + dy * sin_alpha
        contour_points[#contour_points + 1] = left_x + vx * thickness
        contour_points[#contour_points + 1] = left_y + vy * thickness
    end

    for i = 0, n_half_circle_vertices - 1 do
        local t = ternary(n_half_circle_vertices == 1, 0, i / (n_half_circle_vertices - 1))
        local alpha = t * math.pi
        local cos_alpha = math.cos(alpha)
        local sin_alpha = math.sin(alpha)
        local vx = normal_x * cos_alpha + dx * sin_alpha
        local vy = normal_y * cos_alpha + dy * sin_alpha
        contour_points[#contour_points + 1] = right_x + vx * thickness
        contour_points[#contour_points + 1] = right_y + vy * thickness
    end

    for i = 1, #contour_points, 2 do
        add_vertex(contour_points[i], contour_points[i + 1], 0, 0, 0)
    end

    -- center vertices for nicer triangulation
    local left_center_index = #mesh_data + 1
    add_vertex(left_x, left_y, 0, 0, 1)

    local right_center_index = #mesh_data + 1
    add_vertex(right_x, right_y, 0, 0, 1)

    -- triangulate
    local triangulation = {}

    for i = 1, n_half_circle_vertices - 1 do
        triangulation[#triangulation + 1] = left_center_index
        triangulation[#triangulation + 1] = i
        triangulation[#triangulation + 1] = i + 1
    end

    local right_arc_start = n_half_circle_vertices
    for i = 1, n_half_circle_vertices - 1 do
        local a = right_arc_start + i
        triangulation[#triangulation + 1] = right_center_index
        triangulation[#triangulation + 1] = a
        triangulation[#triangulation + 1] = a + 1
    end

    local left_top = n_half_circle_vertices
    local right_top = n_half_circle_vertices + 1
    local left_bottom = 1
    local right_bottom = n_half_circle_vertices + n_half_circle_vertices

    triangulation[#triangulation + 1] = left_top
    triangulation[#triangulation + 1] = right_top
    triangulation[#triangulation + 1] = left_center_index

    triangulation[#triangulation + 1] = right_top
    triangulation[#triangulation + 1] = right_center_index
    triangulation[#triangulation + 1] = left_center_index

    triangulation[#triangulation + 1] = left_bottom
    triangulation[#triangulation + 1] = left_center_index
    triangulation[#triangulation + 1] = right_center_index

    triangulation[#triangulation + 1] = left_bottom
    triangulation[#triangulation + 1] = right_center_index
    triangulation[#triangulation + 1] = right_bottom

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._mesh:set_vertex_map(triangulation)


    self._line_draw_vertices = {
        --x1 + , y1 + down_y,
        x1, y1,
        x2, y2,
        --x2 + down_x, y2 + down_y
    }

    self._color = rt.RGBA(1, 1, 1, 1)
end

--- @brief
function ow.OneWayPlatform:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    self._color:bind()
    love.graphics.line(self._line_draw_vertices)
    self._mesh:draw()
end

--- @brief
function ow.OneWayPlatform:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    self._color:bind()
    love.graphics.line(self._line_draw_vertices)
end

--- @brie
function ow.OneWayPlatform:get_segment_light_sources()
    return { self._line_draw_vertices }, { self._color }
end