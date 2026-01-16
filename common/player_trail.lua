rt.settings.player_trail = {
    decay_duration = 20 / 60,          -- controls fade time together with trail_intensity (lifetime ≈ decay_rate * 4 * trail_intensity)
    glow_radius_factor = 4,
    boom_min_velocity = 115
}

--- @class rt.PlayerTrail
rt.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

local _glow_shader = rt.Shader("common/player_trail_glow.glsl")

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

    self._trail_needs_update = true
    self._trail = {}

    self._is_visible = true

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
    self._trail_needs_update = true
end

--- @brief
function rt.PlayerTrail:set_is_visible(should_draw)
    self._is_visible = should_draw
end

--- @brief
function rt.PlayerTrail:set_position(x, y)
    self._trail_needs_update = math.distance(self._position_x, self._position_y, x, y) > 1
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
    self._trail_needs_update = true
end

--- @brief
function rt.PlayerTrail:set_opacity(opacity)
    self._opacity = opacity
end

--- @brief
function rt.PlayerTrail:update(delta)
    local intensity = self._trail_intensity
    local rate = (1 / math.mix(0, rt.settings.player_trail.decay_duration, math.clamp(
        self._trail_intensity, 0, 1)
    ))

    -- add new segment
    if self._trail_needs_update then
        local ax = self._position_x
        local ay = self._position_y
        local bx = self._position_x + self._velocity_x * delta
        local by = self._position_y + self._velocity_y * delta

        local dx, dy = bx - ax, by - ay
        local left_x, left_y = math.normalize(math.turn_left(dx, dy))
        local right_x, right_y = math.normalize(math.turn_right(dx, dy))

        local entry = {
            ax = ax,
            ay = ay,
            bx = bx,
            by = by,
            dx = dx,
            dy = dy,
            left_x = left_x,
            left_y = left_y,
            right_x = right_x,
            right_y = right_y,
            opacity = 1,
            timestamp = love.timer.getTime(),
            is_visible = self._is_visible
        }

        table.insert(self._trail, 1, entry)

        -- preallocate mesh
        if self._mesh_data == nil or self._mesh == nil then
            self._mesh_data = {}

            local vertices_per_entry = 4
            local max_n_vertices = vertices_per_entry * rt.settings.player_trail.decay_duration / rt.SceneManager:get_timestep()

            local vertex_map = {}
            local vertex_i = 1
            for i = 1, max_n_vertices do
                for j = 1, vertices_per_entry do
                    table.insert(self._mesh_data, {
                        0, 0,
                        0, 0,
                        0, 0, 0, 0
                    })
                end

                local i1 = vertex_i + 0
                local i2 = vertex_i + 1
                local i3 = vertex_i + 2
                local i4 = vertex_i + 3

                for k in range(i1, i2, i4, i2, i3, i4) do
                    table.insert(vertex_map, k)
                end

                vertex_i = vertex_i + 4
            end

            self._mesh = rt.Mesh(
                self._mesh_data,
                rt.MeshDrawMode.TRIANGLES,
                rt.VertexFormat,
                rt.GraphicsBufferUsage.STREAM
            )

            self._mesh:set_vertex_map(vertex_map)
        end

        if #self._trail > 2 then -- rebuild trail mesh
            local max_trail_width = rt.settings.player.radius - 0.5 * rt.settings.player.inner_body_radius

            local vertex_i = 1
            local add_vertex = function(x, y, opacity)
                local data = self._mesh_data[vertex_i]
                if data == nil then return end

                data[1] = x
                data[2] = y
                data[3] = 0
                data[4] = 0
                data[5] = opacity -- pre-mult
                data[6] = opacity
                data[7] = opacity
                data[8] = opacity

                vertex_i = vertex_i + 1
            end

            local add_quad = function(
                start_left_x, start_left_y,
                start_right_x, start_right_y,
                end_right_x, end_right_y,
                end_left_x, end_left_y,
                start_opacity, end_opacity
            )
                add_vertex(start_left_x, start_left_y, start_opacity)
                add_vertex(start_right_x, start_right_y, start_opacity)
                add_vertex(end_right_x, end_right_y, end_opacity)
                add_vertex(end_left_x, end_left_y, end_opacity)
            end

            local function miter(point_x, point_y, normal_1_x, normal_1_y, normal_2_x, normal_2_y, width)
                local miter_x = normal_1_x + normal_2_x
                local miter_y = normal_1_y + normal_2_y
                local miter_length_squared = math.dot(miter_x, miter_y, miter_x, miter_y)

                if miter_length_squared < math.eps then
                    return point_x + normal_2_x * width, point_y + normal_2_y * width
                end

                local miter_normalized_x, miter_normalized_y = math.normalize(miter_x, miter_y)
                local denominator = math.dot(miter_normalized_x, miter_normalized_y, normal_2_x, normal_2_y)

                if math.abs(denominator) < 0.05 then
                    return point_x + normal_2_x * width, point_y + normal_2_y * width
                end

                local scale = width / denominator
                local max_miter = width * 4

                if math.abs(scale) > max_miter then
                    scale = max_miter * (scale > 0 and 1 or -1)
                end

                return point_x + miter_normalized_x * scale,
                point_y + miter_normalized_y * scale
            end

            local width_easing = function(t)
                local decay = 0.5
                return math.mix(0, max_trail_width, math.exp(-decay * (1 - t)))
            end

            local get_opacity = function(entry)
                if entry.is_visible == false then
                    return 0
                else
                    return entry.opacity
                end
            end

            local n = #self._trail
            if n > 0 then
                -- build joint opacity
                local joint_opacity = {}
                joint_opacity[1] = get_opacity(self._trail[1])

                for i = 1, n - 1 do
                    joint_opacity[i + 1] = math.mix(
                        get_opacity(self._trail[i + 0]),
                        get_opacity(self._trail[i + 1]),
                        0.5
                    )
                end

                joint_opacity[n + 1] = get_opacity(self._trail[n])

                local min_segment_length = 1

                -- precompute joint geometry (shared vertices)
                local joints = {}

                for i = 1, n + 1 do
                    local current_entry
                    local previous_entry
                    local next_entry

                    if i == 1 then
                        current_entry = self._trail[1]
                        previous_entry = nil
                        next_entry = self._trail[1]
                    elseif i == n + 1 then
                        current_entry = self._trail[n]
                        previous_entry = self._trail[n]
                        next_entry = nil
                    else
                        current_entry = self._trail[i]
                        previous_entry = self._trail[i - 1]
                        next_entry = self._trail[i]
                    end

                    local segment_length_squared = math.dot(
                        current_entry.dx, current_entry.dy,
                        current_entry.dx, current_entry.dy
                    )

                    if segment_length_squared < min_segment_length then
                        joints[i] = nil
                        goto continue
                    end

                    local width = width_easing(joint_opacity[i])

                    local current_left_x, current_left_y
                    local current_right_x, current_right_y

                    if previous_entry ~= nil and next_entry ~= nil then
                        current_left_x, current_left_y = miter(
                            current_entry.ax, current_entry.ay,
                            previous_entry.left_x, previous_entry.left_y,
                            next_entry.left_x, next_entry.left_y,
                            width
                        )

                        current_right_x, current_right_y = miter(
                            current_entry.ax, current_entry.ay,
                            previous_entry.right_x, previous_entry.right_y,
                            next_entry.right_x, next_entry.right_y,
                            width
                        )
                    else
                        current_left_x = current_entry.ax + current_entry.left_x * width
                        current_left_y = current_entry.ay + current_entry.left_y * width
                        current_right_x = current_entry.ax + current_entry.right_x * width
                        current_right_y = current_entry.ay + current_entry.right_y * width
                    end

                    joints[i] = {
                        left_x = current_left_x,
                        left_y = current_left_y,
                        right_x = current_right_x,
                        right_y = current_right_y,
                        opacity = joint_opacity[i]
                    }

                    ::continue::
                end

                for i = 1, math.min(n, #self._mesh_data - 1) do
                    local start_joint = joints[i]
                    local end_joint = joints[i + 1]

                    if start_joint ~= nil and end_joint ~= nil then
                        add_quad(
                            start_joint.left_x, start_joint.left_y,
                            start_joint.right_x, start_joint.right_y,
                            end_joint.right_x, end_joint.right_y,
                            end_joint.left_x, end_joint.left_y,
                            start_joint.opacity,
                            end_joint.opacity
                        )
                    end
                end
            end

            -- invalidate rest of buffer
            for i = vertex_i, #self._mesh_data do
                add_vertex(0, 0, 0)
            end

            self._mesh:replace_data(self._mesh_data)
        end
    end

    -- update opacity
    local now = love.timer.getTime()
    local to_remove = {}
    for entry_i, entry in ipairs(self._trail) do
        local elapsed = now - entry.timestamp
        entry.opacity = math.exp(-rate * elapsed) -- linear decay
        if entry.opacity < 2 / 256 then
            table.insert(to_remove, 1, entry_i)
        end
    end

    for entry_i in values(to_remove) do
        table.remove(self._trail, entry_i)
    end
end

--- @brief
function rt.PlayerTrail:draw_below()
    if self._mesh == nil or self._trail_intensity < math.eps then return end

    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")

    local alpha = self._trail_intensity
    love.graphics.setColor(self._r * alpha, self._g * alpha, self._b * alpha, alpha)
    self._mesh:draw()

    love.graphics.pop()
end

--- @brief
function rt.PlayerTrail:draw_above()
    if not self._is_visible then return end 
    
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    if self._glow_intensity > math.eps then
        local w, h = self._glow_texture:get_size()
        love.graphics.setColor(self._r, self._g, self._b, self._glow_intensity * self._opacity)
        love.graphics.draw(self._glow_texture:get_native(), self._position_x - 0.5 * w, self._position_y - 0.5 * h)
    end

    local boom_alpha = math.min(1, math.magnitude(self._velocity_x, self._velocity_y) / rt.settings.player_trail.boom_min_velocity)
    if self._boom_intensity * boom_alpha > math.eps then
        love.graphics.setColor(self._r, self._g, self._b, self._boom_intensity * self._opacity * boom_alpha)
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
    self._trail = {}

    if self._mesh_data ~= nil then
        for data in values(self._mesh_data) do
            for i = 1, #data do
                data[i] = 0
            end
        end

        self._mesh:replace_data(self._mesh_data)
    end
end

--- @brief
function rt.PlayerTrail:set_is_visible(b)
    self._is_visible = b
end
