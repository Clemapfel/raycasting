require "overworld.coin_particle"

--- @class CoinParticleTextureAtlas
ow.CoinParticleTextureAtlas = meta.class("CoinParticleTextureAtlas")

--- @brief
function ow.CoinParticleTextureAtlas:instantiate(hues)
    meta.assert(hues, "Table")

    table.sort(hues)

    self._canvas_scale = 1
    local radius = self._canvas_scale * rt.settings.overworld.coin.radius
    local particle = ow.CoinParticle(radius)
    local n_rows = math.ceil(math.sqrt(#hues))
    local n_columns = math.ceil(#hues / n_rows)

    local padding = math.ceil(0.25 * radius)
    local quad_w = 2 * radius + 2 * padding
    local quad_h = quad_w

    local hue_to_quad = {}

    local canvas = rt.RenderTexture(
        quad_w * n_columns,
        quad_h * n_rows,
        rt.GameState:get_msaa_quality()
    )

    love.graphics.push("all")
    love.graphics.reset()
    canvas:bind()

    local hue_i = 1
    for row_i = 1, n_rows do
        for col_i = 1, n_columns do
            if hue_i > #hues then goto exit end

            local hue = hues[hue_i]
            particle:set_hue(hue)
            particle:set_elapsed(rt.random.number(0, 60 * 60))

            local quad_x = (col_i - 1) * quad_w
            local quad_y = (row_i - 1) * quad_h

            local particle_x = quad_x + 0.5 * quad_w
            local particle_y = quad_y + 0.5 * quad_h

            particle:draw(particle_x, particle_y)
            particle:draw_bloom(particle_x, particle_y)

            hue_to_quad[hue] = love.graphics.newQuad(
                quad_x, quad_y, quad_w, quad_h,
                canvas:get_native()
            )

            hue_i = hue_i + 1
        end
    end

    ::exit::

    canvas:unbind()
    love.graphics.pop()

    self._texture_atlas = canvas
    self._hue_to_quad = hue_to_quad
end

--- @brief
function ow.CoinParticleTextureAtlas:draw(hue, x, y, scale)
    if DEBUG then meta.assert(hue, "Number", x, "Number", y, "Number") end
    scale = scale or 1
    scale = scale * (1 / self._canvas_scale)

    local native = self._texture_atlas:get_native()
    local quad = self._hue_to_quad[hue]
    local _, _, w, h = quad:getViewport()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        native, quad,
        x, y,
        0,
        scale, scale,
        0.5 * w, 0.5 * h
    )
end