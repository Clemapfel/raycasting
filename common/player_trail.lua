require "common.render_texture"
require "common.blend_mode"

rt.settings.player_trail = {
    decay_rate = 0.4
}

--- @class rt.PlayerTrail
rt.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

local _boom_mesh = nil
local _glow_texture, _glow_shader = nil, nil
local _trail_canvas_a, _trail_canvas_b, _trail_mesh, _trail_circle_mesh = nil, nil, nil, nil

--- @brief
function rt.PlayerTrail:instantiate(player)
    self._player = player
    self._player_x, self._player_y = player:get_position()

    -- init sonic boom
    if _boom_mesh == nil then
        local player_radius = rt.settings.player.radius
        local x_radius = 1.75 * player_radius -- width
        local y_radius = 2 * player_radius -- stretch
        local y_offset = y_radius - player_radius

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

        _boom_mesh = rt.Mesh(data):get_native()
    end

    -- init glow
    if _glow_shader == nil then _glow_shader = rt.Shader("common/player_trail_glow.glsl") end
    if _glow_texture == nil then
        local radius = rt.settings.player.radius * 4
        local padding = 10
        local width = 2 * radius + 2 * padding
        local height = width

        _glow_texture = rt.RenderTexture(width, height)
        _glow_texture:bind()
        love.graphics.push()
        love.graphics.origin()
        _glow_shader:bind()
        love.graphics.rectangle("fill", 0, 0, width, height)
        _glow_shader:unbind()
        love.graphics.pop()
        _glow_texture:unbind()

        _glow_texture = _glow_texture:get_native()
    end

    -- init trail
    if _trail_canvas_a == nil or _trail_canvas_b == nil then
        self._width, self._height = love.graphics.getDimensions()
        _trail_canvas_a = rt.RenderTexture(self._width, self._height, 0)
        _trail_canvas_b = rt.RenderTexture(self._width, self._height, 0)
        self._a_or_b = true
    end

    self._trail_elapsed = 0
    self:update(0)
end

--- @brief
function rt.PlayerTrail:clear()
    self._previous_screen_x, self._previous_screen_y = nil, nil
end

--- @brief
function rt.PlayerTrail:_draw_trail(x1, y1, x2, y2)
    local dx, dy = math.normalize(x2 - x1, y2 - y1)
    local inner_width = math.min(100 * self._player:get_flow()^1.8, self._player:get_radius() / 2.5)
    local outer_width = self._player:get_flow()

    if inner_width + outer_width < 1 then return end

    local up_x, up_y = math.turn_left(dx, dy)
    local inner_up_x, inner_up_y = up_x * inner_width, up_y * inner_width
    local outer_up_x, outer_up_y = up_x * (inner_width + outer_width), up_y * (inner_width + outer_width)

    local down_x, down_y = math.turn_right(dx, dy)
    local inner_down_x, inner_down_y = down_x * inner_width, down_y * inner_width
    local outer_down_x, outer_down_y = down_x * (inner_width + outer_width), down_y * (inner_width + outer_width)

    local inner_up_x1, inner_up_y1 = x1 + inner_up_x, y1 + inner_up_y
    local outer_up_x1, outer_up_y1 = x1 + outer_up_x, y1 + outer_up_y
    local inner_down_x1, inner_down_y1 = x1 + inner_down_x, y1 + inner_down_y
    local outer_down_x1, outer_down_y1 = x1 + outer_down_x, y1 + outer_down_y

    local inner_up_x2, inner_up_y2 = x2 + inner_up_x, y2 + inner_up_y
    local outer_up_x2, outer_up_y2 = x2 + outer_up_x, y2 + outer_up_y
    local inner_down_x2, inner_down_y2 = x2 + inner_down_x, y2 + inner_down_y
    local outer_down_x2, outer_down_y2 = x2 + outer_down_x, y2 + outer_down_y

    local r1, r2 = 1, 1
    local a1, a2 = 1, 0
    local data = {
        { outer_down_x1, outer_down_y1, r2, r2, r2, a2 },
        { inner_down_x1, inner_down_y1, r1, r1, r1, a1 },
        { x1, y1, r1, r1, r1, a1 },
        { inner_up_x1, inner_up_y1, r1, r1, r1, a1 },
        { outer_up_x1, outer_up_y1, r2, r2, r2, a2 },

        { outer_down_x2, outer_down_y2, r2, r2, r2, a2 },
        { inner_down_x2, inner_down_y2, r1, r1, r1, a1 },
        { x2, y2, r1, r1, r1, 2 },
        { inner_up_x2, inner_up_y2, r1, r1, r1, a1 },
        { outer_up_x2, outer_up_y2, r2, r2, r2, a2 },
    }

    if _trail_mesh == nil then
        _trail_mesh = love.graphics.newMesh({
            {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"},
            {location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4"},
        }, data,
            rt.MeshDrawMode.TRIANGLES,
            rt.GraphicsBufferUsage.DYNAMIC
        )

        _trail_mesh:setVertexMap(
            1, 6, 7,
            1, 2, 7,
            2, 7, 8,
            2, 3, 8,
            3, 8, 9,
            3, 4, 9,
            4, 9, 10,
            4, 5, 10
        )
    else
        _trail_mesh:setVertices(data)
    end

    if _trail_circle_mesh == nil then
        _trail_circle_mesh = rt.MeshCircle(0, 0, inner_width + outer_width)
        for i = 2, _trail_circle_mesh:get_n_vertices() do
            _trail_circle_mesh:set_vertex_color(i, r2, r2, r2, a2)
        end
        _trail_circle_mesh = _trail_circle_mesh:get_native()
    end

    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.MAX)
    love.graphics.setColor(self._r, self._g, self._b, 1)
    love.graphics.draw(_trail_circle_mesh, x1, y1)
    love.graphics.draw(_trail_mesh)
    love.graphics.draw(_trail_circle_mesh, x2, y2)
    rt.graphics.set_blend_mode(nil)
end

--- @brief
function rt.PlayerTrail:update(delta)

    local new_w, new_h = love.graphics.getDimensions()

    if new_w ~= self._width or new_h ~= self._height then
        self._width, self._height = new_w, new_h
        _trail_canvas_a = rt.RenderTexture(self._width, self._height, 0)
        _trail_canvas_b = rt.RenderTexture(self._width, self._height, 0)
    end

    self._player_x, self._player_y = self._player:get_predicted_position()
    self._r, self._g, self._b, self._a = rt.lcha_to_rgba(0.8, 1, self._player:get_hue(), 1)
    self._opacity = self._player:get_opacity()

    local flow = self._player:get_flow()
    self._glow_intensity = 0.5 * flow

    self._boom_angle = math.angle(self._player:get_velocity())
    self._boom_intensity = 10 * flow

    self._trail_elapsed = self._trail_elapsed + delta
    do
        local scene = rt.SceneManager:get_current_scene()
        if scene == nil then return end

        local x, y = 0, 0
        if scene.get_camera ~= nil then
            x, y = scene:get_camera():get_position()
        end

        local w, h = self._width, self._height
        x = x - 0.5 * w
        y = y - 0.5 * h

        if self._previous_camera_x == nil and self._previous_camera_y == nil then
            self._previous_camera_x, self._previous_camera_y = x, y
        end

        local dx, dy = self._previous_camera_x - x, self._previous_camera_y - y
        local player_x, player_y = self._player:get_predicted_position()
        if self._previous_player_x == nil or self._previous_player_y == nil then
            self._previous_player_x, self._previous_player_y = player_x, player_y
        end

        local a, b
        if self._a_or_b then
            a = _trail_canvas_a
            b = _trail_canvas_b
        else
            a = _trail_canvas_b
            b = _trail_canvas_a
        end
        self._a_or_b = not self._a_or_b

        local dalpha = (1 / rt.settings.player_trail.decay_rate * 1 / (flow * 4)) * delta

        love.graphics.push()

        b:bind()
        love.graphics.origin()
        rt.graphics.set_blend_mode(rt.BlendMode.SUBTRACT, rt.BlendMode.SUBTRACT)
        love.graphics.setColor(0, 0, 0, dalpha)
        love.graphics.rectangle("fill", 0, 0, self._width, self._height)
        rt.graphics.set_blend_mode(nil)
        b:unbind()

        a:bind()
        love.graphics.clear()
        love.graphics.translate(dx, dy)
        rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.NORMAL)
        b:draw()
        love.graphics.origin()
        love.graphics.translate(-x, -y)
        self:_draw_trail(player_x, player_y, self._previous_player_x, self._previous_player_y)
        a:unbind()

        love.graphics.pop()

        self._previous_camera_x, self._previous_camera_y = x, y
        self._previous_player_x, self._previous_player_y = player_x, player_y
    end
end

--- @brief
function rt.PlayerTrail:draw_below()
    local scene = rt.SceneManager:get_current_scene()
    local x, y = 0, 0
    if scene.get_camera ~= nil then
        x, y = scene:get_camera():get_position()
    end
    local w, h = self._width, self._height
    x = x - 0.5 * w
    y = y - 0.5 * h

    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
    love.graphics.setColor(1, 1, 1, 1)
    if self._a_or_b then
        love.graphics.draw(_trail_canvas_b:get_native(), x, y)
    else
        love.graphics.draw(_trail_canvas_a:get_native(), x, y)
    end
    love.graphics.setBlendMode("alpha")
end

--- @brief
function rt.PlayerTrail:draw_above()
    love.graphics.setBlendMode("add")

    do -- draw glow
        local w, h = _glow_texture:getDimensions()
        love.graphics.setColor(self._r, self._g, self._b, self._glow_intensity * self._opacity)
        love.graphics.draw(_glow_texture, self._player_x - 0.5 * w, self._player_y - 0.5 * h)
    end

    -- draw sonic boom
    if not self._player:get_is_bubble() then
        love.graphics.setColor(self._r, self._g, self._b, self._boom_intensity * self._opacity)
        love.graphics.push()
        love.graphics.translate(self._player_x, self._player_y)
        love.graphics.rotate(self._boom_angle + math.pi / 2)
        love.graphics.translate(-self._player_x, -self._player_y)
        love.graphics.draw(_boom_mesh, self._player_x, self._player_y)
        love.graphics.pop()
    end

    love.graphics.setBlendMode("alpha")
end