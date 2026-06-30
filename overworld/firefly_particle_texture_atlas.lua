require "overworld.firefly_particle"

--- @class FireflyParticleTextureAtlas
ow.FireflyParticleTextureAtlas = meta.class("FireflyParticleTextureAtlas")

local _hue_step = 1 / 32
local _radius_step = 1

function _round(r, step)
    local inv = 1 / step;
    return math.round(r * inv) / inv;
end

--- @brief
function ow.FireflyParticleTextureAtlas:instantiate(hues, radii)
    meta.assert(hues, mt.Table, radii, mt.Table)

    local process = function(to_process, step, min_value)
        for i, r in ipairs(to_process) do
            to_process[i] = math.max(min_value or 0, _round(r, step))
        end

        table.sort(to_process)

        local deduped = {}
        local previous = nil
        for _, v in ipairs(to_process) do
            if v ~= previous then
                table.insert(deduped, v)
                previous = v
            end
        end

        return deduped
    end

    hues = process(hues, _hue_step)
    radii = process(radii, _radius_step)
    self._hues, self._radii = hues, radii

    self._canvas_scale = 2.5
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

    for _, hue in ipairs(hues) do
        hue_to_radius_to_quad[hue] = {}
    end

    local canvas_width = quad_width * n_columns
    local canvas_height = quad_height * n_rows

    local canvas = rt.RenderTexture(
        math.max(1, canvas_width),
        math.max(1, canvas_height),
        rt.GameState:get_msaa_quality()
    )
    canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

    love.graphics.push("all")
    love.graphics.reset()
    canvas:bind()

    local index = 1
    for row_index = 1, n_rows do
        local should_break = false
        for column_index = 1, n_columns do
            if index > n_total then
                should_break = true
                break
            end

            local hue_index = ((index - 1) % n_hues) + 1
            local radius_index = math.floor((index - 1) / n_hues) + 1

            local hue = hues[hue_index]
            local base_radius = radii[radius_index]
            local radius = self._canvas_scale * base_radius

            local particle = ow.FireflyParticle(hue, radius)

            local quad_x = (column_index - 1) * quad_width
            local quad_y = (row_index - 1) * quad_height
            local particle_x = quad_x + 0.5 * quad_width
            local particle_y = quad_y + 0.5 * quad_height

            particle:draw(particle_x, particle_y)

            hue_to_radius_to_quad[hue][base_radius] = love.graphics.newQuad(
                quad_x,
                quad_y,
                quad_width,
                quad_height,
                canvas_width,
                canvas_height
            )

            index = index + 1
        end

        if should_break then break end
    end

    canvas:unbind()
    love.graphics.pop()

    self._texture_atlas = canvas
    self._hue_to_radius_to_quad = hue_to_radius_to_quad
end

--- @brief
function ow.FireflyParticleTextureAtlas:draw(hue, radius, x, y, scale)
    if DEBUG then meta.assert(hue, mt.Number, radius, mt.Number, x, mt.Number, y, mt.Number) end
    scale = scale or 1
    scale = scale * (1 / self._canvas_scale)

    hue = _round(hue, _hue_step)
    radius = _round(radius, _radius_step)

    local native = self._texture_atlas:get_native()
    local quad = self._hue_to_radius_to_quad[hue][radius]

    if quad == nil then
        rt.error("In ow.FireflyParticleTextureAtlas.draw: no particle with hue `", hue, "` and radius `", radius, "`")
    end

    local _, _, width, height = quad:getViewport()
    local r, g, b, alpha = love.graphics.getColor()
    local v = math.max(r, g, b)
    love.graphics.setColor(v, v, v, alpha)
    love.graphics.draw(
        native, quad,
        x, y,
        0,
        scale, scale,
        0.5 * width, 0.5 * height
    )
end
