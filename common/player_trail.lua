rt.settings.player_trail = {
    decay_rate = 0.4,          -- controls fade time together with trail_intensity (lifetime ≈ decay_rate * 4 * trail_intensity)
    glow_radius_factor = 4
}

--- @class rt.PlayerTrail
rt.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

local _glow_shader = rt.Shader("common/player_trail_glow.glsl")

local function _compute_tangent(points, i)
    local n = #points
    if n <= 1 then return 1, 0 end
    if i <= 1 then
        local p1, p2 = points[1], points[2]
        return math.normalize(p2.x - p1.x, p2.y - p1.y)
    elseif i >= n then
        local p1, p2 = points[n-1], points[n]
        return math.normalize(p2.x - p1.x, p2.y - p1.y)
    else
        local p0, p1, p2 = points[i-1], points[i], points[i+1]
        local ax, ay = p1.x - p0.x, p1.y - p0.y
        local bx, by = p2.x - p1.x, p2.y - p1.y
        local sx, sy = ax + bx, ay + by
        local mx, my = math.normalize(sx, sy)
        if math.is_nan(mx) or math.is_nan(my) then -- NaN check if both segments cancel out
            return math.normalize(bx, by)
        end
        return mx, my
    end
end

--- @brief
function rt.PlayerTrail:instantiate(radius)
    self._radius = radius
    self._position_x, self._position_y = 0, 0
    self._velocity_x, self._velocity_y = 0, 0
    self._angle = 0

    self._glow_intensity = 0
    self._boom_intensity = 0
    self._trail_intensity = 0

    self._r, self._g, self._b, self._opacity = 0, 0, 0, 1

    self._points = {}
    self._min_sample_distance = math.max(1, radius * 0.15)
    self._last_sample_x, self._last_sample_y = nil, nil

    self._trail_mesh = nil
    self._trail_vertex_count = 0
    self._trail_index_count = 0
    self.trail_needs_update = true

    -- boom geometry
    do
        local x_radius = 1.9 * radius -- width
        local y_radius = 2 * radius   -- stretch
        local y_offset = y_radius - radius * 1.2 -- to account for body

        local _boom_shape = function(x)
            return math.sqrt(1 - x^2)
        end

        local data = {{ 0, x_radius, 0, 0, 1, 1, 1, 0 }}

        local n_vertices = 16
        local i = 1
        for v = -1, 1, 2 / (2 * n_vertices) do
            local a = 1
            if i <= n_vertices then
                a = (i - 1) / n_vertices
            elseif i >= n_vertices then
                a = 1 - (i - n_vertices - 1) / n_vertices
            end

            table.insert(data, {
                v * x_radius,
                -1 * _boom_shape(v) * y_radius + y_offset,
                0, 0, 1, 1, 1, a * 2
            })

            i = i + 1
        end

        self._boom_mesh = rt.Mesh(data)
    end

    -- precompute glow texture
    do
        local glow_radius = radius * rt.settings.player_trail.glow_radius_factor
        local padding = 10
        local width = 2 * glow_radius + 2 * padding
        local height = width

        love.graphics.push("all")
        love.graphics.reset()
        self._glow_texture = rt.RenderTexture(width, height)
        self._glow_texture:bind()

        love.graphics.push()
        love.graphics.origin()
        _glow_shader:bind()
        love.graphics.rectangle("fill", 0, 0, width, height)
        _glow_shader:unbind()
        love.graphics.pop()
        self._glow_texture:unbind()

        love.graphics.pop()
    end
end

--- @brief
function rt.PlayerTrail:set_glow_intensity(t)
    self._glow_intensity = t
end

--- @brief
function rt.PlayerTrail:set_boom_intensity(t)
    self._boom_intensity = t
end

--- @brief
function rt.PlayerTrail:set_trail_intensity(t)
    self._trail_intensity = t
    self.trail_needs_update = true
end

--- @brief
function rt.PlayerTrail:set_position(x, y)
    self._position_x, self._position_y = x, y
end

--- @brief
function rt.PlayerTrail:set_velocity(vx, vy)
    self._velocity_x, self._velocity_y = vx, vy
    self._angle = math.angle(self._velocity_x, self._velocity_y) + 0.5 * math.pi
end

--- @brief
function rt.PlayerTrail:set_hue(hue)
    self._r, self._g, self._b = rt.lcha_to_rgba(0.8, 1, hue, 1)
    self.trail_needs_update = true
end

--- @brief
function rt.PlayerTrail:set_opacity(opacity)
    self._opacity = opacity
end

--- @brief
function rt.PlayerTrail:update(delta)
    local intensity = self._trail_intensity
    local rate = (1 / rt.settings.player_trail.decay_rate) * (1 / (intensity * 4)) * delta

    -- opacity decay
    local points = self._points
    local write = 1
    for read = 1, #points do
        local p = points[read]
        p.alpha = p.alpha - rate
        if p.alpha > 0 then
            if write ~= read then
                points[write] = p
            end
            write = write + 1
        end
    end

    for i = write, #points do
        points[i] = nil
    end

    local x, y = self._position_x, self._position_y
    local last_x, last_y = self._last_sample_x, self._last_sample_y

    if last_x == nil or math.distance(x, y, last_x, last_y) >= self._min_sample_distance then
        table.insert(points, { x = x, y = y, alpha = 1.0 })
        self._last_sample_x, self._last_sample_y = x, y
        self.trail_needs_update = true
    else
        local n = #points
        if n >= 1 then
            local head = points[n]
            head.x, head.y = x, y
            self.trail_needs_update = true
        end
    end
end

--- Build/refresh the ribbon mesh to fit through stored points.
function rt.PlayerTrail:_rebuild_trail_mesh()
    self.trail_needs_update = false

    local n = #self._points
    if n < 2 then
        self._trail_mesh = nil
        self._trail_vertex_count = 0
        self._trail_index_count = 0
        return
    end

    -- width model matches prior code
    local t = self._trail_intensity
    local inner_width = math.min(100 * (t ^ 1.8), self._radius / 2.5)
    local outer_width = t
    local total_half = inner_width + outer_width

    if total_half < 1e-3 then
        self._trail_mesh = nil
        self._trail_vertex_count = 0
        self._trail_index_count = 0
        return
    end

    local mesh_data = {}
    local index_map = {}

    local points = self._points
    local previous_normal_x, previous_normal_y = 1, 0

    for i = 1, n do
        local point = points[i]
        local tangent_x, tangent_y = _compute_tangent(points, i)

        if tangent_x ~= tangent_x or tangent_y ~= tangent_y then
            -- tangent invalid (NaN), reuse previous or default
            tangent_x, tangent_y = previous_normal_x, previous_normal_y
        else
            previous_normal_x, previous_normal_y = tangent_x, tangent_y
        end

        local ux, uy = math.turn_left(tangent_x, tangent_y) -- normal
        local in_up_x, in_up_y = ux * inner_width, uy * inner_width
        local out_up_x, out_up_y = ux * (inner_width + outer_width), uy * (inner_width + outer_width)

        local down_x, down_y = -ux, -uy
        local in_down_x, in_down_y = down_x * inner_width, down_y * inner_width
        local out_down_x, out_down_y = down_x * (inner_width + outer_width), down_y * (inner_width + outer_width)

        local outer_alpha = 0.0
        local inner_alpha = math.max(0, math.min(1, point.alpha)) * self._opacity
        local center_alpha = inner_alpha -- keep same alpha on center for stability

        -- premultiplied color per vertex
        local function multiply(r, g, b, a)
            return r * a, g * a, b * a, a
        end

        local od_r, od_g, od_b, od_a = multiply(self._r, self._g, self._b, outer_alpha)
        local id_r, id_g, id_b, id_a = multiply(self._r, self._g, self._b, inner_alpha)
        local c_r, c_g, c_b, c_a = multiply(self._r, self._g, self._b, center_alpha)
        local iu_r, iu_g, iu_b, iu_a = id_r, id_g, id_b, id_a
        local ou_r, ou_g, ou_b, ou_a = od_r, od_g, od_b, od_a

        -- outer_down
        table.insert(mesh_data, { point.x + out_down_x, point.y + out_down_y, od_r, od_g, od_b, od_a })
        -- inner_down
        table.insert(mesh_data, { point.x + in_down_x, point.y + in_down_y, id_r, id_g, id_b, id_a })
        -- center
        table.insert(mesh_data, { point.x, point.y, c_r, c_g, c_b, c_a })
        -- inner_up
        table.insert(mesh_data, { point.x + in_up_x, point.y + in_up_y, iu_r, iu_g, iu_b, iu_a })
        -- outer_up
        table.insert(mesh_data, { point.x + out_up_x, point.y + out_up_y, ou_r, ou_g, ou_b, ou_a })
    end

    -- index mapping: 8 triangles per segment
    local function base(i) return (i - 1) * 5 end
    for i = 1, n - 1 do
        local a = base(i)
        local b = base(i + 1)
        -- using 1-based vertex indices
        -- (od_i, od_{i+1}, id_{i+1})
        table.insert(index_map, a + 1); table.insert(index_map, b + 1); table.insert(index_map, b + 2)
        -- (od_i, id_i, id_{i+1})
        table.insert(index_map, a + 1); table.insert(index_map, a + 2); table.insert(index_map, b + 2)
        -- (id_i, id_{i+1}, c_{i+1})
        table.insert(index_map, a + 2); table.insert(index_map, b + 2); table.insert(index_map, b + 3)
        -- (id_i, c_i, c_{i+1})
        table.insert(index_map, a + 2); table.insert(index_map, a + 3); table.insert(index_map, b + 3)
        -- (c_i, c_{i+1}, iu_{i+1})
        table.insert(index_map, a + 3); table.insert(index_map, b + 3); table.insert(index_map, b + 4)
        -- (c_i, iu_i, iu_{i+1})
        table.insert(index_map, a + 3); table.insert(index_map, a + 4); table.insert(index_map, b + 4)
        -- (iu_i, iu_{i+1}, ou_{i+1})
        table.insert(index_map, a + 4); table.insert(index_map, b + 4); table.insert(index_map, b + 5)
        -- (iu_i, ou_i, ou_{i+1})
        table.insert(index_map, a + 4); table.insert(index_map, a + 5); table.insert(index_map, b + 5)
    end

    local desired_vertex_count = #mesh_data
    local desired_index_count = #index_map

    if self._trail_mesh == nil or self._trail_vertex_count ~= desired_vertex_count then
        local mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES, {
            {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"},
            {location = 2, name = rt.VertexAttribute.COLOR,    format = "floatvec4"},
        }, rt.GraphicsBufferUsage.STREAM)

        mesh:set_vertex_map(index_map)

        self._trail_mesh = mesh
        self._trail_vertex_count = desired_vertex_count
        self._trail_index_count = desired_index_count
    else
        self._trail_mesh:replace_data(mesh_data)

        if self._trail_index_count ~= desired_index_count then
            self._trail_mesh:set_vertex_map(index_map)
            self._trail_index_count = desired_index_count
        end
    end
end

--- @brief
function rt.PlayerTrail:draw_below()
    if self.trail_needs_update then
        self:_rebuild_trail_mesh()
    end

    local mesh = self._trail_mesh
    if mesh == nil then return end

    love.graphics.push("all")
    -- additive with premultiplied source (we authored vertices as premultiplied)
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh:get_native())
    love.graphics.pop()
end

--- @brief
function rt.PlayerTrail:draw_above()
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    if self._glow_intensity > 0 then
        local w, h = self._glow_texture:get_size()
        love.graphics.setColor(self._r, self._g, self._b, self._glow_intensity * self._opacity)
        love.graphics.draw(self._glow_texture:get_native(), self._position_x - 0.5 * w, self._position_y - 0.5 * h)
    end

    if self._boom_intensity > 0 then
        love.graphics.setColor(self._r, self._g, self._b, self._boom_intensity * self._opacity)
        love.graphics.push()
        love.graphics.translate(self._position_x, self._position_y)
        love.graphics.rotate(self._angle)
        love.graphics.translate(-self._position_x, -self._position_y)
        love.graphics.draw(self._boom_mesh:get_native(), self._position_x, self._position_y)
        love.graphics.pop()
    end

    love.graphics.pop()
end

--- @brief
function rt.PlayerTrail:clear()
    for i = #self._points, 1, -1 do
        self._points[i] = nil
    end
    self._last_sample_x, self._last_sample_y = nil, nil
    self._trail_mesh = nil
    self._trail_vertex_count = 0
    self._trail_index_count = 0
    self.trail_needs_update = true
end