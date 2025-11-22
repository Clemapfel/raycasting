rt.settings.player_trail = {
    decay_rate = 0.4,
    glow_radius_factor = 4
}

--- @class rt.PlayerTrail
rt.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

local _glow_shader = rt.Shader("common/player_trail_glow.glsl")

--- @brief
function rt.PlayerTrail:instantiate(radius)
    self._position_x, self._position_y = 0, 0
    self._velocity_x, self._velocity_y = 0, 0
    self._angle = 0

    self._glow_intensity = 0
    self._boom_intensity = 0
    self._trail_intensity = 0

    self._r, self._g, self._b, self._opacity = 0, 0, 0, 1
    
    do
        local x_radius = 1.9 * radius -- width
        local y_radius = 2 * radius -- stretch
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
end

--- @brief
function rt.PlayerTrail:set_opacity(opacity)
    self._opacity = opacity
end

--- @brief
function rt.PlayerTrail:update(delta)
    
end

--- @brief
function rt.PlayerTrail:draw_below()

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
    -- TODO
end
