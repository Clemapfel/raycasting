rt.settings.overworld.firefly_particle = {
    core_radius_factor = 1.5 / 10
}

--- @class ow.FireflyParticle
ow.FireflyParticle = meta.class("FireflyParticle")

--- @brief
function ow.FireflyParticle:instantiate(hue, radius)
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, hue, 1))
    self._radius = radius
    self._core_radius =  rt.settings.overworld.firefly_particle.core_radius_factor * radius

    local texture_r = radius
    local padding = 2
    local texture_w = 2 * (texture_r + padding)
    self._texture = rt.RenderTexture(texture_w, texture_w)

    local x, y = 0.5 * texture_w, 0.5 * texture_w

    local inner_inner_r, inner_outer_r = 0.15, 0.25
    local outer_inner_r, outer_outer_r = 0.15, 1
    local inner_inner_color = rt.RGBA(1, 1, 1, 1)
    local inner_outer_color = rt.RGBA(1, 1, 1, 0.0)
    local outer_inner_color = rt.RGBA(1, 1, 1, 0.5)
    local outer_outer_color = rt.RGBA(1, 1, 1, 0.0)

    local inner_glow = rt.MeshRing(
        x, y,
        math.max(self._core_radius, inner_inner_r * texture_r),
        inner_outer_r * texture_r,
        true,     -- fill center
        nil, -- n_outer_vertices
        inner_inner_color, inner_outer_color
    )

    local outer_glow = rt.MeshRing(
        x, y,
        math.max(self._core_radius, outer_inner_r * texture_r),
        outer_outer_r * texture_r,
        true,
        nil,
        outer_inner_color, outer_outer_color
    )

    love.graphics.push("all")
    love.graphics.reset()
    love.graphics.setColor(1, 1, 1, 1)
    self._texture:bind()
    inner_glow:draw()
    outer_glow:draw()
    self._texture:unbind()
    love.graphics.pop()
end

--- @brief
function ow.FireflyParticle:draw(x, y)
    local texture_w, texture_h = self._texture:get_size()

    local r, g, b = self._color:unpack()
    local _, _, _, a = love.graphics.getColor()

    love.graphics.push("all")

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.translate(-0.5 * texture_w, -0.5 * texture_h)

    love.graphics.setBlendMode("alpha", "premultiplied")

    love.graphics.setColor(
        r * a,
        g * a,
        b * a,
        a
    )
    self._texture:draw()
    love.graphics.pop()

    love.graphics.setBlendMode("alpha", "alphamultiply")

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(2)

    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()

    local under = 0.4
    love.graphics.setColor(
        under * r,
        under * g,
        under * b,
        a
    )

    love.graphics.circle("line",
        x, y,
        self._core_radius
    )

    love.graphics.setColor(r, g, b, a)
    love.graphics.circle("fill",
        x, y, self._core_radius
    )

    love.graphics.pop()
end

--- @brief
function ow.FireflyParticle:draw_bloom(x, y)
    self._color:bind()
    love.graphics.circle("fill",
        x, y, self._core_radius
    )
end