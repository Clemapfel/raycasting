require "common.timed_animation"
require "common.player"
require "common.label"

--- @class ow.CoinParticle
ow.CoinParticle = meta.class("CoinParticle")

local _shader = nil
local _font = rt.Font("assets/fonts/Baloo2/Baloo2-Bold.ttf")

--- @brief
function ow.CoinParticle:instantiate(radius, is_outline)
    if _shader == nil then _shader = rt.Shader("common/player_body_core.glsl") end
    if is_outline == nil then is_outline = false end

    self._elapsed_offset = rt.random.number(0, 100)
    self._radius = radius * (1 / rt.settings.player.bubble_radius_factor)
    self._body_radius = radius
    self._hue = 0
    self._color = { 0, 0, 0, 0 }
    self._outline_color = { 0, 0, 0, 0 }
    self._opacity = 1

    self._core_outline = {}
    self._body_outline = {}
    self._dotted_outlines = {}
    self._is_outline = is_outline
    
    self._index = 0
    self._index_label = rt.Glyph("", {
        font = _font,
        font_size = rt.FontSize.TINY,
        is_outlined = true,
        is_mono = true,
        style = rt.FontStyle.REGULAR
    })

    local n_points = math.max(16, 16 * radius / 16)
    self._line_width = math.max(radius / 32, 0.5)

    local floor = math.floor

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
    love.graphics.setColor(1, 1, 1, self._opacity)
    love.graphics.circle("fill", 0, 0, self._radius)
    _shader:unbind()

    local r, g, b, a = table.unpack(self._outline_color)
    love.graphics.setColor(r, g, b, a * self._opacity)
    love.graphics.line(self._core_outline)
end

function ow.CoinParticle:draw(x, y)
    love.graphics.push()
    love.graphics.translate(x, y)

    local black_r, black_g, black_b, black_a = rt.Palette.BLACK:unpack()
    local white_r, white_g, white_b, white_a = rt.Palette.FOREGROUND:unpack()
    if self._is_outline then
        love.graphics.setLineWidth(self._line_width + 2)
        love.graphics.setColor(black_r, black_g, black_b, self._opacity)
        for outline in values(self._dotted_outlines) do
            love.graphics.line(outline)
        end

        love.graphics.setLineWidth(self._line_width)
        love.graphics.setColor(white_r, white_g, white_b, self._opacity)
        for outline in values(self._dotted_outlines) do
            love.graphics.line(outline)
        end
    else
        love.graphics.setLineWidth(self._line_width)
        love.graphics.setColor(black_r, black_g, black_b, self._opacity)
        love.graphics.circle("fill", 0, 0, self._body_radius)

        local r, g, b, a = table.unpack(self._color)
        love.graphics.setColor(r, g, b, a * self._opacity)

        love.graphics.line(self._body_outline)

        self:_draw_core()
    end

    if rt.GameState:get_is_color_blind_mode_enabled() then
        self._index_label:draw()
    end

    love.graphics.pop()
end

function ow.CoinParticle:draw_bloom(x, y)
    if self._is_outline then return end

    love.graphics.setLineWidth(0.5)

    love.graphics.push()
    love.graphics.translate(x, y)

    local r, g, b, a = table.unpack(self._color)
    love.graphics.setColor(r, g, b, a * self._opacity)
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

--- @brief
function ow.CoinParticle:set_index(index)
    self._index = index
    self._index_label:set_text(tostring(index))

    if self._index_label:get_is_realized() == false then
        self._index_label:realize()
        local w, h = self._index_label:measure()
        self._index_label:reformat(0.5 * self._radius + 0.25 * w, 0.5 * self._radius, math.huge)
    end
end

--- @brief
function ow.CoinParticle:set_opacity(opacity)
    self._opacity = opacity
end