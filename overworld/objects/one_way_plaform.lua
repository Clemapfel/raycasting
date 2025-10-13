rt.settings.overworld.one_way_platform = {
    thickness = 40,
    bloom_intensity = 0.5, -- fraction
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

    self._active = false
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

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._mesh:set_vertex_map(triangulation)

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

    self._hue = _hue_steps[_current_hue_step]
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    _current_hue_step = _current_hue_step % _n_hue_steps + 1
end

--- @brief
function ow.OneWayPlatform:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local x1, y1, x2, y2 = table.unpack(self._line_draw_vertices)

    local base_line_width = rt.settings.overworld.one_way_platform.line_width
    local line_width = base_line_width + 2
    love.graphics.setLineWidth(line_width)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._line_draw_vertices)

    love.graphics.circle("fill", x1, y1, line_width * 0.5)
    love.graphics.circle("fill", x2, y2, line_width * 0.5)

    line_width = base_line_width
    love.graphics.setLineWidth(line_width)
    self._color:bind()
    love.graphics.line(self._line_draw_vertices)
    love.graphics.circle("fill", x1, y1, line_width * 0.5)
    love.graphics.circle("fill", x2, y2, line_width * 0.5)

    love.graphics.push("all")
    love.graphics.setLineWidth(1)
    rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    love.graphics.line(self._highlight_draw_vertices)
    love.graphics.pop()
end

--- @brief
function ow.OneWayPlatform:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    local line_width = rt.settings.overworld.one_way_platform.line_width
    local x1, y1, x2, y2 = table.unpack(self._line_draw_vertices)

    local player = self._scene:get_player()
    local thickness = rt.settings.overworld.one_way_platform.thickness
    local px, py = player:get_position()

    love.graphics.setColor(1, 1, 1, rt.settings.overworld.one_way_platform.bloom_intensity)
    _shader:bind()
    _shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(px, py) })
    _shader:send("player_hue", player:get_hue())
    _shader:send("hue", self._hue)
    self._mesh:draw()
    _shader:unbind()
end

--- @brief
function ow.OneWayPlatform:get_segment_light_sources()
    return { self._line_draw_vertices }, { { self._color:unpack() } }
end