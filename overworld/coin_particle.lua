require "common.timed_animation"

--- @class ow.CoinParticle
ow.CoinParticle = meta.class("CoinParticle")

local _shader = nil

--- @brief
function ow.CoinParticle:instantiate(radius)
    if _shader == nil then _shader = rt.Shader("common/player_body_core.glsl") end

    self._elapsed_offset = rt.random.number(0, 100)
    self._radius = radius * (1 / rt.settings.player.bubble_radius_factor)
    self._body_radius = radius
    self._hue = 0
    self._color = { 0, 0, 0, 0 }
    self._outline_color = { 0, 0, 0, 0 }

    self._core_outline = {}
    self._body_outline = {}
    for angle = 0, 2 * math.pi, 2 * math.pi / 16 do
        table.insert(self._core_outline, math.cos(angle) * self._radius)
        table.insert(self._core_outline, math.sin(angle) * self._radius)

        table.insert(self._body_outline, math.cos(angle) * self._body_radius)
        table.insert(self._body_outline, math.sin(angle) * self._body_radius)
    end

    for outline in range(self._core_outline, self._body_outline) do
        table.insert(outline, outline[1])
        table.insert(outline, outline[2])
    end

end

--- @brief
function ow.CoinParticle:update(delta)
    -- noop
end

function ow.CoinParticle:_draw_core()
    _shader:bind()
    _shader:send("hue", self._hue)
    _shader:send("elapsed", rt.SceneManager:get_elapsed() + self._elapsed_offset)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, self._radius)
    _shader:unbind()

    love.graphics.setColor(table.unpack(self._outline_color))
    love.graphics.line(self._core_outline)
end

function ow.CoinParticle:draw(x, y)
    local r, g, b, a = love.graphics.getColor()

    love.graphics.setLineWidth(0.5)

    love.graphics.push()
    love.graphics.translate(x, y)

    rt.Palette.BLACK:bind()
    love.graphics.circle("fill", 0, 0, self._body_radius)

    love.graphics.setColor(table.unpack(self._color))
    love.graphics.line(self._body_outline)

    self:_draw_core()

    love.graphics.pop()
end

function ow.CoinParticle:draw_bloom(x, y)
    local r, g, b, a = love.graphics.getColor()

    love.graphics.setLineWidth(0.5)

    love.graphics.push()
    love.graphics.translate(x, y)

    love.graphics.setColor(table.unpack(self._color))
    love.graphics.line(self._body_outline)

    self:_draw_core()

    love.graphics.pop()
end

--- @brief
function ow.CoinParticle:set_hue(hue)
    meta.assert(hue, "Number")
    self._hue = hue
    self._color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }
    self._outline_color = table.deepcopy(self._color)
    for i = 1, 3 do
        self._outline_color[i] = self._outline_color[i] - rt.settings.player_body.outline_value_offset
    end
end