require "common.timed_animation"
require "common.player"

--- @class ow.CoinParticle
ow.CoinParticle = meta.class("CoinParticle")

local _shader = nil

--- @brief
function ow.CoinParticle:instantiate(radius, is_outline)
    if _shader == nil then _shader = rt.Shader("common/player_body_core.glsl") end

    self._elapsed_offset = rt.random.number(0, 100)
    self._radius = radius * (1 / rt.settings.player.bubble_radius_factor)
    self._body_radius = radius
    self._hue = 0
    self._color = { 0, 0, 0, 0 }
    self._outline_color = { 0, 0, 0, 0 }

    self._core_outline = {}
    self._body_outline = {}
    self._dotted_outlines = {}
    self._is_outline = is_outline

    local n_points = 16 * rt.get_pixel_scale()
    for angle = 0, 2 * math.pi, 2 * math.pi / n_points do
        table.insert(self._core_outline, math.cos(angle) * self._radius)
        table.insert(self._core_outline, math.sin(angle) * self._radius)

        table.insert(self._body_outline, math.cos(angle) * self._body_radius)
        table.insert(self._body_outline, math.sin(angle) * self._body_radius)
    end

    local n_steps = 32
    local step = (2 * math.pi) / n_steps
    for i = 1, n_steps + 1, 2 do
        table.insert(self._dotted_outlines, {
            math.cos((i - 1) * step) * self._body_radius,
            math.sin((i - 1) * step) * self._body_radius,
            math.cos((i - 0) * step) * self._body_radius,
            math.sin((i - 0) * step) * self._body_radius
        })
    end

    for outline in range(self._core_outline, self._body_outline) do
        table.insert(outline, outline[1])
        table.insert(outline, outline[2])
    end
end

function ow.CoinParticle:set_is_outline(b)
    self._is_outline = b
end

function ow.CoinParticle:_draw_core()
    _shader:bind()
    _shader:send("hue", self._hue)
    _shader:send("elapsed", rt.SceneManager:get_elapsed() + self._elapsed_offset)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, self._radius)
    _shader:unbind()

    love.graphics.setColor(self._outline_color)
    love.graphics.line(self._core_outline)
end

function ow.CoinParticle:draw(x, y)
    love.graphics.push()
    love.graphics.translate(x, y)

    if self._is_outline then
        love.graphics.setLineWidth(2)
        rt.Palette.BLACK:bind()
        for outline in values(self._dotted_outlines) do
            love.graphics.line(outline)
        end

        love.graphics.setLineWidth(1)
        rt.Palette.FOREGROUND:bind()
        for outline in values(self._dotted_outlines) do
            love.graphics.line(outline)
        end
    else
        love.graphics.setLineWidth(0.5)
        rt.Palette.BLACK:bind()
        love.graphics.circle("fill", 0, 0, self._body_radius)

        love.graphics.setColor(self._color)
        love.graphics.line(self._body_outline)

        self:_draw_core()
    end

    love.graphics.pop()
end

function ow.CoinParticle:draw_bloom(x, y)
    if self._is_outline then return end

    love.graphics.setLineWidth(0.5)

    love.graphics.push()
    love.graphics.translate(x, y)

    love.graphics.setColor(self._color)
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