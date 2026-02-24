require "overworld.coin_particle"

--- @class CoinParticleTextureAtlas
ow.CoinParticleTextureAtlas = meta.class("CoinParticleTextureAtlas")

--- @brief
function ow.CoinParticleTextureAtlas:instantiate(hues)
    meta.assert(hues, "Table")

    table.sort(hues)

    self._canvas_scale = 2
    local radius = self._canvas_scale * rt.settings.overworld.coin.radius
    local particle = ow.CoinParticle(radius)
    local n_rows = math.ceil(math.sqrt(#hues))
    local n_columns = math.ceil(#hues / n_rows)

    local padding = math.ceil(0.25 * radius)
    local quad_width = 2 * radius + 2 * padding
    local quad_height = quad_width

    local hue_to_quad = {}
    local hue_to_bloom_quad = {}

    local canvas = rt.RenderTexture(
        quad_width * n_columns * 2,
        quad_height * n_rows,
        rt.GameState:get_msaa_quality()
    )
    canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

    love.graphics.push("all")
    love.graphics.reset()
    canvas:bind()

    local hue_index = 1
    for row_index = 1, n_rows do
        for column_index = 1, n_columns do
            if hue_index > #hues then goto exit end

            local hue = hues[hue_index]
            particle:set_hue(hue)
            particle:set_elapsed(rt.random.number(0, 60 * 60))

            local quad_x = (column_index - 1) * quad_width
            local quad_y = (row_index - 1) * quad_height
            local particle_x = quad_x + 0.5 * quad_width
            local particle_y = quad_y + 0.5 * quad_height

            particle:draw(particle_x, particle_y)

            hue_to_quad[hue] = love.graphics.newQuad(
                quad_x, quad_y, quad_width, quad_height,
                canvas:get_native()
            )

            local bloom_quad_x = n_columns * quad_width + quad_x
            local bloom_particle_x = bloom_quad_x + 0.5 * quad_width

            particle:draw_bloom(bloom_particle_x, particle_y)

            hue_to_bloom_quad[hue] = love.graphics.newQuad(
                bloom_quad_x, quad_y, quad_width, quad_height,
                canvas:get_native()
            )

            hue_index = hue_index + 1
        end
    end

    ::exit::

    canvas:unbind()
    love.graphics.pop()

    self._texture_atlas = canvas
    self._hue_to_quad = hue_to_quad
    self._hue_to_bloom_quad = hue_to_bloom_quad
end

--- @brief
function ow.CoinParticleTextureAtlas:draw(hue, x, y, scale)
    if DEBUG then meta.assert(hue, "Number", x, "Number", y, "Number") end
    scale = scale or 1
    scale = scale * (1 / self._canvas_scale)

    local native = self._texture_atlas:get_native()
    local quad = self._hue_to_quad[hue]

    if quad == nil then
        rt.error("In ow.CoinParticleTextureAtlas.draw: no entry with hue `", hue, "`")
    end

    local _, _, width, height = quad:getViewport()

    local _, _, _, alpha = love.graphics.getColor()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        native, quad,
        x, y,
        0,
        scale, scale,
        0.5 * width, 0.5 * height
    )
end

--- @brief
function ow.CoinParticleTextureAtlas:draw_bloom(hue, x, y, scale)
    if DEBUG then meta.assert(hue, "Number", x, "Number", y, "Number") end
    scale = scale or 1
    scale = scale * (1 / self._canvas_scale)

    local native = self._texture_atlas:get_native()
    local quad = self._hue_to_bloom_quad[hue]

    if quad == nil then
        rt.error("In ow.CoinParticleTextureAtlas.draw_bloom: no entry with hue `", hue, "`")
    end

    local _, _, width, height = quad:getViewport()

    local _, _, _, alpha = love.graphics.getColor()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        native, quad,
        x, y,
        0,
        scale, scale,
        0.5 * width, 0.5 * height
    )
end