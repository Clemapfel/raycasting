require "common.render_texture"
require "common.blend_mode"

--- @class ow.PlayerTrail
ow.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

--- @brief
function ow.PlayerTrail:instantiate(scene)
    self._scene = scene
    self._width, self._height = 2 * love.graphics.getWidth(), 2 * love.graphics.getHeight()
    self._canvas_a = rt.RenderTexture(self._width, self._height)
    self._canvas_b = rt.RenderTexture(self._width, self._height)
    self._a_or_b = true

    self._mesh = rt.MeshCircle(0, 0, self._scene:get_player():get_radius())
    for i = 2, self._mesh:get_n_vertices() do
        self._mesh:set_vertex_color(i, 1, 1, 1, 0)
    end
end

--- @brief
function ow.PlayerTrail:bind()
    self._canvas:bind()
end

--- @brief
function ow.PlayerTrail:unbind()
    self._canvas:unbind()
end

--- @brief
function ow.PlayerTrail:clear()
    self._canvas_a:bind()
    love.graphics.clear(0, 0, 0, 0)
    self._canvas_b:bind()
    love.graphics.clear(0, 0, 0, 0)
    self._canvas_b:unbind()
end

--- @brief
function ow.PlayerTrail:get_size()
    return self._width, self._height
end

local _previous_x, _previous_y = nil, nil
local _shader = nil

--- @brief
function ow.PlayerTrail:update(delta)
    local x, y = self._scene:get_camera():get_position()
    local w, h = self._width, self._height
    x = x - 0.5 * w
    y = y - 0.5 * h

    if _shader == nil then _shader = rt.Shader("overworld/player_trail.glsl") end
    if _previous_x == nil and _previous_y == nil then
        _previous_x, _previous_y = x, y
    end

    local dx, dy = _previous_x - x, _previous_y - y

    local a, b
    if self._a_or_b then
        a = self._canvas_a
        b = self._canvas_b
    else
        a = self._canvas_b
        b = self._canvas_a
    end
    self._a_or_b = not self._a_or_b

    local decay_rate = 0.4 -- seconds until clear
    local dalpha = (1 / decay_rate) * delta
    for canvas in range(a, b) do
        canvas:bind()
        love.graphics.origin()
        rt.graphics.set_blend_mode(rt.BlendMode.SUBTRACT, rt.BlendMode.SUBTRACT)
        love.graphics.setColor(0, 0, 0, dalpha)
        love.graphics.rectangle("fill", 0, 0, self._width, self._height)
        rt.graphics.set_blend_mode(nil)
        canvas:unbind()
    end

    love.graphics.push()
    a:bind()

    local diff = 1
    rt.graphics.set_blend_mode(rt.BlendMode.SUBTRACT, rt.BlendMode.SUBTRACT)
    love.graphics.setColor(0, 0, 0, diff)
    love.graphics.rectangle("fill", 0, 0, self._width, self._height)
    rt.graphics.set_blend_mode(nil)

    love.graphics.origin()
    love.graphics.translate(dx, dy)
    b:draw()
    love.graphics.origin()
    love.graphics.translate(-x, -y)
    rt.Palette.MINT_1:bind()
    love.graphics.draw(self._mesh:get_native(), self._scene:get_player():get_position())
    rt.graphics.set_blend_mode()
    b:unbind()
    love.graphics.pop()

    _previous_x, _previous_y = x, y
end


--- @brief
function ow.PlayerTrail:draw()

    local x, y = self._scene:get_camera():get_position()
    local w, h = self._width, self._height
    x = x - 0.5 * w
    y = y - 0.5 * h

    love.graphics.push()
    love.graphics.translate(x, y)
    if self._a_or_b then
        self._canvas_b:draw()
    else
        self._canvas_a:draw()
    end
    love.graphics.pop()
end