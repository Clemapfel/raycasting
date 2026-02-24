require "overworld.firefly_particle"

--- @class FireflyParticleTextureAtlas
ow.FireflyParticleTextureAtlas = meta.class("FireflyParticleTextureAtlas")

--- @brief
function ow.FireflyParticleTextureAtlas:instantiate(hues, radii)
    meta.assert(hues, "Table", radii, "Table")

    self._hues, self._radii = hues, radii

    table.sort(hues)
    table.sort(radii)

    self._canvas_scale = 2
    local max_radius = self._canvas_scale * radii[#radii]

    local n_hues = #hues
    local n_radii = #radii
    local n_total = n_hues * n_radii

    local n_rows = math.ceil(math.sqrt(n_total))
    local n_columns = math.ceil(n_total / n_rows)

    local padding = math.ceil(0.25 * max_radius)
    local quad_width = 2 * max_radius + 2 * padding
    local quad_height = quad_width

    local hue_to_radius_to_quad = {}
    local hue_to_radius_to_bloom_quad = {}

    for _, hue in ipairs(hues) do
        hue_to_radius_to_quad[hue] = {}
        hue_to_radius_to_bloom_quad[hue] = {}
    end

    local canvas = rt.RenderTexture(
        quad_width * n_columns * 2,
        quad_height * n_rows,
        rt.GameState:get_msaa_quality()
    )
    canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

    love.graphics.push("all")
    love.graphics.reset()
    canvas:bind()

    local index = 1
    for row_index = 1, n_rows do
        for column_index = 1, n_columns do
            if index > n_total then goto exit end

            local hue_index = ((index - 1) % n_hues) + 1
            local radius_index = math.floor((index - 1) / n_hues) + 1

            local hue = hues[hue_index]
            local radius = self._canvas_scale * radii[radius_index]

            local particle = ow.FireflyParticle(hue, radius)

            local quad_x = (column_index - 1) * quad_width
            local quad_y = (row_index - 1) * quad_height
            local particle_x = quad_x + 0.5 * quad_width
            local particle_y = quad_y + 0.5 * quad_height

            particle:draw(particle_x, particle_y)

            hue_to_radius_to_quad[hue][radii[radius_index]] = love.graphics.newQuad(
                quad_x, quad_y, quad_width, quad_height,
                canvas:get_native()
            )

            local bloom_quad_x = n_columns * quad_width + quad_x
            local bloom_particle_x = bloom_quad_x + 0.5 * quad_width

            particle:draw_bloom(bloom_particle_x, particle_y)

            hue_to_radius_to_bloom_quad[hue][radii[radius_index]] = love.graphics.newQuad(
                bloom_quad_x, quad_y, quad_width, quad_height,
                canvas:get_native()
            )

            index = index + 1
        end
    end

    ::exit::

    canvas:unbind()
    love.graphics.pop()

    self._texture_atlas = canvas
    self._hue_to_radius_to_quad = hue_to_radius_to_quad
    self._hue_to_radius_to_bloom_quad = hue_to_radius_to_bloom_quad
end

--- @brief
function ow.FireflyParticleTextureAtlas:draw(hue, radius, x, y, scale)
    if DEBUG then meta.assert(hue, "Number", radius, "Number", x, "Number", y, "Number") end
    scale = scale or 1
    scale = scale * (1 / self._canvas_scale)

    local native = self._texture_atlas:get_native()
    local quad = self._hue_to_radius_to_quad[hue][radius]

    if quad == nil then
        rt.error("In ow.FireflyParticleTextureAtlas.draw: no particle with hue `", hue, "` and radius `", radius, "`")
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
function ow.FireflyParticleTextureAtlas:draw_bloom(hue, radius, x, y, scale)
    if DEBUG then meta.assert(hue, "Number", radius, "Number", x, "Number", y, "Number") end
    scale = scale or 1
    scale = scale * (1 / self._canvas_scale)

    local native = self._texture_atlas:get_native()
    local quad = self._hue_to_radius_to_bloom_quad[hue][radius]

    if quad == nil then
        rt.error("In ow.FireflyParticleTextureAtlas.draw_bloom: no particle with hue `", hue, "` and radius `", radius, "`")
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