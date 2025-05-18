require "common.render_texture"
require "common.blend_mode"

rt.settings.player_trail = {
    decay_rate = 0.4
}

--- @class rt.PlayerTrail
rt.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

local _trail_canvas_a, _trail_canvas_b, _trail_canvas_c = nil, nil, nil

--- @brief
function rt.PlayerTrail:instantiate(player)
    meta.assert(player, rt.Player)
    self._player = player
    self._width, self._height = love.graphics.getWidth(), love.graphics.getHeight()

    _trail_canvas_a = rt.RenderTexture(self._width, self._height, 0)
    _trail_canvas_b = rt.RenderTexture(self._width, self._height, 0)

    self._a_or_b = true
    self._r, self._g, self._b = 1, 0, 0
end

--- @brief
function rt.PlayerTrail:clear()
    _trail_canvas_a:bind()
    love.graphics.clear(0, 0, 0, 0)
    _trail_canvas_a:unbind()

    _trail_canvas_b:bind()
    love.graphics.clear(0, 0, 0, 0)
    _trail_canvas_b:unbind()
end

local _boom_mesh

--- @brief
function rt.PlayerTrail:draw()
    if self._player:get_physics_body() == nil then return end

    if _boom_mesh == nil then
        local player_radius = rt.settings.player.radius
        local x_radius = 1.5 * player_radius
        local y_radius = 2 * player_radius
        local y_offset = y_radius - player_radius

        local _boom_shape = function(x)
            return math.sqrt(1 - x^2)
        end

        local data = {{ 0, x_radius, 0, 0, 1, 1, 1, 0 }}

        local i = 1
        for v = -1, 1, 2 / 32 do
            local a = 1
            if i <= 16 then
                a = (i - 1) / 16
            elseif i >= 16 then
                a = 1 - (i - 16 - 1) / 16
            end

            table.insert(data, {
                v * x_radius,
                -1 * _boom_shape(v) * y_radius + y_offset,
                0, 0, 1, 1, 1, a
            })

            i = i + 1
        end

        _boom_mesh = rt.Mesh(data):get_native()
    end

    -- draw canvas
    do
        local scene = rt.SceneManager:get_current_scene()
        local x, y = 0, 0
        if scene.get_camera ~= nil then
            x, y = scene:get_camera():get_position()
        end
        local w, h = self._width, self._height
        x = x - 0.5 * w
        y = y - 0.5 * h

        love.graphics.setBlendState(
            rt.BlendOperation.ADD,         -- rgb_operation
            rt.BlendOperation.ADD,         -- alpha_operation
            rt.BlendFactor.SOURCE_ALPHA,            -- rgb_source_factor (premultiplied alpha)
            rt.BlendFactor.ZERO,           -- alpha_source_factor (commonly ONE or ZERO)
            rt.BlendFactor.ONE,            -- rgb_destination_factor
            rt.BlendFactor.ZERO             -- alpha_destination_factor (commonly ONE or ZERO)
        )

        love.graphics.setColor(1, 1, 1, 1)
        if self._a_or_b then
            love.graphics.draw(_trail_canvas_b:get_native(), x, y)
        else
            love.graphics.draw(_trail_canvas_a:get_native(), x, y)
        end

        rt.graphics.set_blend_mode(nil)
    end

    local player = self._player
    local x, y = player:get_physics_body():get_predicted_position()

    -- draw glow
    self:_draw_glow(x, y, player:get_flow() * 0.25)

    -- draw boom
    local vx, vy = player:get_physics_body():get_linear_velocity()
    local angle = math.angle(vx, vy)

    love.graphics.setColor(self._r, self._g, self._b, 10 * player:get_flow())
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle + math.pi / 2)
    love.graphics.translate(-x, -y)
    love.graphics.draw(_boom_mesh, x, y)
    love.graphics.pop()

    rt.graphics.set_blend_mode(nil)
end

local _previous_x, _previous_y = nil, nil
local _previous_player_x, _previous_player_y = nil, nil

--- @brief
function rt.PlayerTrail:update(delta)
    if self._player:get_physics_body() == nil then return end

    local scene = rt.SceneManager:get_current_scene()
    local x, y = 0, 0
    if scene.get_camera ~= nil then
        x, y = scene:get_camera():get_position()
    end

    local w, h = self._width, self._height
    x = x - 0.5 * w
    y = y - 0.5 * h

    if _previous_x == nil and _previous_y == nil then
        _previous_x, _previous_y = x, y
    end

    local dx, dy = _previous_x - x, _previous_y - y

    local player_x, player_y = self._player:get_physics_body():get_predicted_position()
    if _previous_player_x == nil or _previous_player_y == nil then
        _previous_player_x, _previous_player_y = player_x, player_y
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

    local decay_rate = rt.settings.player_trail.decay_rate
    local dalpha = (1 / rt.settings.player_trail.decay_rate) * delta
    b:bind()

    love.graphics.origin()
    rt.graphics.set_blend_mode(rt.BlendMode.SUBTRACT, rt.BlendMode.SUBTRACT)
    love.graphics.setColor(0, 0, 0, dalpha)
    love.graphics.rectangle("fill", 0, 0, self._width, self._height)
    rt.graphics.set_blend_mode(nil)

    b:unbind()

    love.graphics.push()
    a:bind()

    love.graphics.clear()
    love.graphics.origin()
    love.graphics.translate(dx, dy)
    love.graphics.setBlendMode("alpha", "premultiplied")
    b:draw()

    love.graphics.origin()
    love.graphics.translate(-x, -y)

    local hue = self._player:get_hue()
    self._r, self._g, self._b = rt.lcha_to_rgba(rt.LCHA(0.8, 1, hue, 1):unpack())

    self:_draw_trail(_previous_player_x, _previous_player_y, player_x, player_y)

    a:unbind()
    love.graphics.pop()

    _previous_x, _previous_y = x, y
    _previous_player_x, _previous_player_y = player_x, player_y
end


local _mesh, _circle_mesh = nil

--- @brief
function rt.PlayerTrail:_draw_trail(x1, y1, x2, y2)
    local dx, dy = math.normalize(x2 - x1, y2 - y1)

    local inner_width = math.min(300 * self._player:get_flow()^1.8, 4)
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
        {outer_down_x1, outer_down_y1, r2, r2, r2, a2},
        {inner_down_x1, inner_down_y1, r1, r1, r1, a1},
        {x1, y1, r1, r1, r1, a1},
        {inner_up_x1, inner_up_y1, r1, r1, r1, a1},
        {outer_up_x1, outer_up_y1, r2, r2, r2, a2},

        {outer_down_x2, outer_down_y2, r2, r2, r2, a2},
        {inner_down_x2, inner_down_y2, r1, r1, r1, a1},
        {x2, y2, r1, r1, r1, 2},
        {inner_up_x2, inner_up_y2, r1, r1, r1, a1},
        {outer_up_x2, outer_up_y2, r2, r2, r2, a2},
    }

    if _mesh == nil then
        _mesh = love.graphics.newMesh({
            {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"},
            {location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4"},
        }, data,
            rt.MeshDrawMode.TRIANGLES,
            rt.GraphicsBufferUsage.DYNAMIC
        )
        _mesh:setVertexMap(
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
        _mesh:setVertices(data)
    end

    if _circle_mesh == nil then
        _circle_mesh = rt.MeshCircle(0, 0, inner_width + outer_width)
        for i = 2, _circle_mesh:get_n_vertices() do
            _circle_mesh:set_vertex_color(i, r2, r2, r2, a2)
        end
        _circle_mesh = _circle_mesh:get_native()
    end

    local centroid_x, centroid_y = x2, y2

    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.MAX)
    love.graphics.setColor(self._r, self._g, self._b, 1)
    love.graphics.draw(_circle_mesh, x1, y1)
    love.graphics.draw(_mesh)
    love.graphics.draw(_circle_mesh, x2, y2)
    rt.graphics.set_blend_mode(nil)
    love.graphics.setColor(1, 1, 1, 1)
end

local _glow_texture, _glow_shader, _glow_offset_x, _glow_offset_y

function rt.PlayerTrail:_draw_glow(x, y, intensity)
    if _glow_shader == nil then
        _glow_shader = rt.Shader("common/player_trail_glow.glsl")
    end

    if _glow_texture == nil then
        local radius = rt.settings.player.radius * 10
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
        _glow_offset_x = -0.5 * width
        _glow_offset_y = _glow_offset_x
    end

    love.graphics.setBlendState(
        rt.BlendOperation.ADD,         -- rgb_operation
        rt.BlendOperation.ADD,         -- alpha_operation
        rt.BlendFactor.SOURCE_ALPHA,            -- rgb_source_factor (premultiplied alpha)
        rt.BlendFactor.ZERO,           -- alpha_source_factor (commonly ONE or ZERO)
        rt.BlendFactor.ONE,            -- rgb_destination_factor
        rt.BlendFactor.ZERO             -- alpha_destination_factor (commonly ONE or ZERO)
    )

    love.graphics.setColor(self._r, self._g, self._b, intensity)
    love.graphics.draw(_glow_texture, x + _glow_offset_x, y + _glow_offset_y)
end


