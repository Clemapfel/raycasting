rt.settings.overworld.one_way_platform = {
    thickness = 40,
    bloom_intensity = 0.5, -- fraction
    direction_light_intensity = 0.5, -- fraction
    line_width = 5
}

--- @class ow.OneWayPlatform
--- @types Rectangle
ow.OneWayPlatform = meta.class("OneWayPlatform")

local _shader = rt.Shader("overworld/objects/one_way_platform.glsl")

local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

--- @brief
function ow.OneWayPlatform:instantiate(object, stage, scene)

    -- TODO
    self._input_subscriber = rt.InputSubscriber()
    self._input_subscriber:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "p" then _shader:recompile() end
    end)

    self._scene = scene
    self._stage = stage

    local x1, y1 = object.x, object.y
    local w, h = object.width, object.height

    local dx, dy = math.rotate(w, 0, object.rotation)
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

    --[[
    -- allow fallthrough
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
    ]]--

    local mesh_data = {}
    self._line_drawdraw_vertices = {}

    function add_vertex(x, y, u, v, alpha)
        table.insert(mesh_data, { x, y, u, v, 1, 1, 1, alpha })
    end

    local left_x, left_y, right_x, right_y = x1, y1, x2, y2
    local n_half_circle_vertices = 8

    dx, dy = math.normalize(dx, dy)
    local normal_x, normal_y = math.turn_left(dx, dy)

    for i = 0, n_half_circle_vertices - 1 do
        local t = ternary(n_half_circle_vertices == 1, 0, i / (n_half_circle_vertices - 1))
        local angle = math.pi + t * math.pi
        local cos_alpha = math.cos(angle)
        local sin_alpha = math.sin(angle)
        local vx = normal_x * cos_alpha + dx * sin_alpha
        local vy = normal_y * cos_alpha + dy * sin_alpha
        add_vertex(
            left_x + vx * thickness,
            left_y + vy * thickness,
            cos_alpha, sin_alpha,
            0
        )
    end

    for i = 0, n_half_circle_vertices - 1 do
        local t = ternary(n_half_circle_vertices == 1, 0, i / (n_half_circle_vertices - 1))
        local angle = t * math.pi
        local cos_alpha = math.cos(angle)
        local sin_alpha = math.sin(angle)
        local vx = normal_x * cos_alpha + dx * sin_alpha
        local vy = normal_y * cos_alpha + dy * sin_alpha
        add_vertex(
            right_x + vx * thickness,
            right_y + vy * thickness,
            cos_alpha, sin_alpha,
        0
        )
    end

    -- center vertices for nicer triangulation
    local left_center_index = #mesh_data + 1
    add_vertex(left_x, left_y, 0, 0, 1)

    local right_center_index = #mesh_data + 1
    add_vertex(right_x, right_y, 0, 0, 1)

    -- triangulate
    local triangulation = {}

    for i = 1, n_half_circle_vertices - 1 do
        table.insert(triangulation, left_center_index)
        table.insert(triangulation, i)
        table.insert(triangulation, i + 1)
    end

    local right_arc_start = n_half_circle_vertices
    for i = 1, n_half_circle_vertices - 1 do
        local j = right_arc_start + i
        table.insert(triangulation, right_center_index)
        table.insert(triangulation, j)
        table.insert(triangulation, j + 1)
    end

    local left_top = n_half_circle_vertices
    local right_top = n_half_circle_vertices + 1
    local left_bottom = 1
    local right_bottom = n_half_circle_vertices + n_half_circle_vertices

    table.insert(triangulation, left_top)
    table.insert(triangulation, right_top)
    table.insert(triangulation, left_center_index)

    table.insert(triangulation, right_top)
    table.insert(triangulation, right_center_index)
    table.insert(triangulation, left_center_index)

    table.insert(triangulation, left_bottom)
    table.insert(triangulation, left_center_index)
    table.insert(triangulation, right_center_index)

    table.insert(triangulation, left_bottom)
    table.insert(triangulation, right_center_index)
    table.insert(triangulation, right_bottom)

    self._line_draw_vertices = {
        x1, y1,
        x2, y2,
    }

    local line_width = rt.settings.overworld.one_way_platform.line_width
    local highlight_offset = 0.5 * line_width - 2
    local highlight_shorten = 2 -- px
    self._highlight_draw_vertices = {
        x1 + ldx * highlight_offset + dx * highlight_shorten,
        y1 + ldy * highlight_offset + dy * highlight_shorten,
        x2 + ldx * highlight_offset - dx * highlight_shorten,
        y2 + ldy * highlight_offset - dy * highlight_shorten,
    }

    do -- direction mesh
        local width = 1 * thickness
        local down_x, down_y = math.turn_left(math.normalize(dx, dy))
        down_x = down_x * width
        down_y = down_y * width

        local overshoot = 10
        local left_x, left_y = -dx * overshoot, -dy * overshoot
        local right_x, right_y = dx * overshoot, dy * overshoot

        x1 = x1 + right_x / 2
        y1 = y1 + right_y / 2
        x2 = x2 + left_x / 2
        y2 = y2 + left_y / 2

        local r, alpha = 1, rt.settings.overworld.one_way_platform.direction_light_intensity
        local segments = 8 -- Number of segments per quarter circle

        -- Create vertices array
        local vertices = {}

        -- Top vertices (center line)
        table.insert(vertices, { x1, y1, 0, 0, r, r, r, alpha }) -- 1: top-left center
        table.insert(vertices, { x2, y2, 0, 0, r, r, r, alpha }) -- 2: top-right center

        -- Left quarter circle (from top-left to bottom-left)
        for i = 0, segments do
            local t = i / segments
            local angle = t * math.pi / 2 -- 0 to 90 degrees

            -- Interpolate between left_x/y (forward) and down_x/y (perpendicular)
            local offset_x = left_x * math.cos(angle) + down_x * math.sin(angle)
            local offset_y = left_y * math.cos(angle) + down_y * math.sin(angle)

            table.insert(vertices, {
                x1 + offset_x,
                y1 + offset_y,
                math.cos(angle), math.sin(angle),
                r, r, r, 0
            })
        end

        -- Right quarter circle (from top-right to bottom-right)
        for i = 0, segments do
            local t = i / segments
            local angle = t * math.pi / 2 -- 0 to 90 degrees

            -- Interpolate between right_x/y (backward) and down_x/y (perpendicular)
            local offset_x = right_x * math.cos(angle) + down_x * math.sin(angle)
            local offset_y = right_y * math.cos(angle) + down_y * math.sin(angle)

            table.insert(vertices, {
                x2 + offset_x,
                y2 + offset_y,
                math.cos(angle), math.sin(angle),
                r, r, r, 0
            })
        end

        self._direction_mesh = rt.Mesh(vertices, rt.MeshDrawMode.TRIANGLES)

        -- Generate triangulation
        local indices = {}

        -- Fan triangulation from top-left center (vertex 1)
        local left_start = 3 -- First vertex of left quarter circle
        local left_end = left_start + segments -- Last vertex of left quarter circle

        for i = left_start, left_end - 1 do
            table.insert(indices, 1) -- top-left center
            table.insert(indices, i)
            table.insert(indices, i + 1)
        end

        -- Connect the two arcs at the bottom
        local right_start = left_end + 1 -- First vertex of right quarter circle
        local right_end = right_start + segments -- Last vertex of right quarter circle

        -- Center quad (two triangles)
        table.insert(indices, 1) -- top-left center
        table.insert(indices, left_end) -- end of left arc
        table.insert(indices, 2) -- top-right center

        table.insert(indices, left_end) -- end of left arc
        table.insert(indices, right_end) -- end of right arc
        table.insert(indices, 2) -- top-right center

        -- Bottom connection
        table.insert(indices, left_end) -- end of left arc
        table.insert(indices, right_start) -- start of right arc
        table.insert(indices, right_end) -- end of right arc

        -- Fan triangulation from top-right center (vertex 2)
        for i = right_start, right_end - 1 do
            table.insert(indices, 2) -- top-right center
            table.insert(indices, i)
            table.insert(indices, i + 1)
        end

        self._direction_mesh:set_vertex_map(indices)
    end

    self._hue = _hue_steps[_current_hue_step]
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    _current_hue_step = _current_hue_step % _n_hue_steps + 1
end

--- @brief
function ow.OneWayPlatform:draw()
    if not self._stage:get_is_body_visible(self._sensor) then return end

    local x1, y1, x2, y2 = table.unpack(self._line_draw_vertices)

    local base_line_width = rt.settings.overworld.one_way_platform.line_width
    local line_width = base_line_width + 4
    love.graphics.setLineWidth(line_width)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._line_draw_vertices)
    love.graphics.circle("fill", x1, y1, line_width * 0.5)
    love.graphics.circle("fill", x2, y2, line_width * 0.5)

    line_width = base_line_width
    love.graphics.setLineWidth(line_width)
    self._color:bind()

    _shader:bind()
    self._direction_mesh:draw()
    _shader:unbind()
    love.graphics.line(self._line_draw_vertices)
    love.graphics.circle("fill", x1, y1, line_width * 0.5)
    love.graphics.circle("fill", x2, y2, line_width * 0.5)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(self._highlight_draw_vertices)
end

--- @brief
function ow.OneWayPlatform:draw_bloom()
    if not self._stage:get_is_body_visible(self._sensor) then return end

    self._color:bind()
    _shader:bind()
    self._direction_mesh:draw()
    _shader:unbind()
end

--- @brief
function ow.OneWayPlatform:get_segment_light_sources()
    return { self._line_draw_vertices }, { { self._color:unpack() } }
end