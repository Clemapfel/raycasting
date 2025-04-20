require "common.render_texture"
require "common.blend_mode"

--- @class ow.PlayerTrail
ow.PlayerTrail = meta.class("PlayerTrail", rt.Drawable)

local _canvas_a, _canvas_b = nil, nil

--- @brief
function ow.PlayerTrail:instantiate(scene, radius)
    meta.assert(scene, "OverworldScene")
    self._scene = scene
    self._width, self._height = love.graphics.getWidth(), love.graphics.getHeight()
    
    _canvas_a = rt.RenderTexture(self._width, self._height)
    _canvas_b = rt.RenderTexture(self._width, self._height)
    self._a_or_b = true
    self._should_pulse = false

    self._mesh = rt.MeshCircle(0, 0, radius)
    for i = 2, self._mesh:get_n_vertices() do
        self._mesh:set_vertex_color(i, 1, 1, 1, 0)
    end
end

--- @brief
function ow.PlayerTrail:clear()
    _canvas_a:bind()
    love.graphics.clear(0, 0, 0, 0)
    _canvas_b:bind()
    love.graphics.clear(0, 0, 0, 0)
    _canvas_b:unbind()
end

--- @brief
function ow.PlayerTrail:get_size()
    return self._width, self._height
end

local _mesh = nil
local _circle_mesh = nil

--- @brief
function ow.PlayerTrail:_draw_trail(x1, y1, x2, y2)
    local dx, dy = math.normalize(x2 - x1, y2 - y1)

    local inner_width = 3
    local outer_width = 2

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

    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.MAX)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(_circle_mesh, x1, y1)
    love.graphics.draw(_mesh)
    love.graphics.draw(_circle_mesh, x2, y2)
    rt.graphics.set_blend_mode(nil)
end

local _pulse_mesh = nil

function ow.PlayerTrail:_draw_pulse(x, y)
    if _pulse_mesh == nil then
        _pulse_mesh = rt.MeshCircle(0, 0, rt.settings.overworld.player.radius * 2)
        _pulse_mesh:set_vertex_color(1, 0, 0, 0, 0)
        _pulse_mesh = _pulse_mesh:get_native()
    end

    love.graphics.draw(_pulse_mesh, x, y)
end

local _previous_x, _previous_y = nil, nil
local _previous_player_x, _previous_player_y = nil, nil

--- @brief
function ow.PlayerTrail:update(delta)
    local x, y = self._scene:get_camera():get_position()
    local w, h = self._width, self._height
    x = x - 0.5 * w
    y = y - 0.5 * h

    if _previous_x == nil and _previous_y == nil then
        _previous_x, _previous_y = x, y
    end

    local dx, dy = _previous_x - x, _previous_y - y

    local a, b
    if self._a_or_b then
        a = _canvas_a
        b = _canvas_b
    else
        a = _canvas_b
        b = _canvas_a
    end
    self._a_or_b = not self._a_or_b

    local _dim = function(delta)
        rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.SUBTRACT)
        love.graphics.setColor(0, 0, 0, delta)
        love.graphics.rectangle("fill", 0, 0, self._width, self._height)
        rt.graphics.set_blend_mode(nil)
    end

    local decay_rate = 0.4 -- seconds until clear
    local dalpha = (1 / decay_rate) * delta
    for canvas in range(a, b) do
        canvas:bind()
        love.graphics.origin()
        _dim(dalpha)
        canvas:unbind()
    end

    love.graphics.push()
    a:bind()

    local player_x, player_y = self._scene:get_player():get_physics_body():get_predicted_position()
    if _previous_player_x == nil or _previous_player_y == nil then
        _previous_player_x, _previous_player_y = player_x, player_y
    end

    _dim(1)

    love.graphics.origin()
    love.graphics.translate(dx, dy)
    rt.graphics.set_blend_mode(rt.BlendMode.MAX)
    b:draw()
    love.graphics.origin()
    love.graphics.translate(-x, -y)
    rt.Palette.PLAYER:bind()
    self:_draw_trail(_previous_player_x, _previous_player_y, player_x, player_y)

    if self._should_pulse then
        self:_draw_pulse(self._pulse_x or player_x, self._pulse_y or player_y)
        self._should_pulse = false
    end

    rt.graphics.set_blend_mode()
    b:unbind()
    love.graphics.pop()

    _previous_x, _previous_y = x, y
    _previous_player_x, _previous_player_y = player_x, player_y
end

--- @brief
function ow.PlayerTrail:draw()
    local x, y = self._scene:get_camera():get_position()
    local w, h = self._width, self._height
    x = x - 0.5 * w
    y = y - 0.5 * h

    if self._a_or_b then
        love.graphics.draw(_canvas_b:get_native(), x, y)
    else
        love.graphics.draw(_canvas_a:get_native(), x, y)
    end
end

--- @brief
function ow.PlayerTrail:pulse(x, y)
    self._should_pulse = true
    self._pulse_x = x -- may be nil
    self._pulse_y = y
end