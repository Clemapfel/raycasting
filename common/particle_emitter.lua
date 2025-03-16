require "common.widget"

rt.settings.particle_emitter = {
    default_emission_rate = 10,
    default_count = 100,
    default_particle_lifetime = 1,
    default_speed = 100
}

--- @class rt.ParticleEmissionAreaShape
rt.ParticleEmissionAreaShape = meta.enum("ParticleEmissionAreaShape", {
    UNIFORM = "uniform",
    ROUND = "normal"
})

--- @class rt.ParticleEmitter
rt.ParticleEmitter = meta.class("ParticleEmitter", rt.Widget)

function rt.ParticleEmitter:instantiate(particle)
    meta.install(self, {
        _particle = particle,
        _native = love.graphics.newParticleSystem(particle._native),
        _bounds = rt.AABB(0, 0, 1, 1),
        _speed = rt.settings.particle_emitter.default_speed,
        _color = rt.RGBA(1, 1, 1, 1),
        _emission_area_shape = rt.ParticleEmissionAreaShape.ROUND,
        _opacity = 1
    })
end

--- @override
function rt.ParticleEmitter:realize()
    if self:already_realized() then return end

    self._native:setEmissionRate(rt.settings.particle_emitter.default_emission_rate)
    self._native:setParticleLifetime(rt.settings.particle_emitter.default_particle_lifetime)
    self._native:setSpeed(0, 0)
    self._native:setSpread(0)
    self._native:setDirection(-0.5 * math.pi)

    self._native:setSizes(1, 1)
    self._native:setInsertMode("bottom")

    self:set_opacity(self._opacity)
    if self._particle ~= nil then self._native:setTexture(self._particle._native) end

    self._native:start()
end

--- @override
function rt.ParticleEmitter:size_allocate(x, y, width, height)
    self._native:setPosition(x + 0.5 * width, y + 0.5 * height)
    self._native:setEmissionArea(self._emission_area_shape, width / 2, height / 2)
end

--- @override
function rt.ParticleEmitter:update(delta)
    self._native:update(delta)
end

--- @override
function rt.ParticleEmitter:draw()
    love.graphics.setColor(self._color.r, self._color.g, self._color.b, 1) -- opacity set in setColors
    love.graphics.draw(self._native)
end

--- @brief
function rt.ParticleEmitter:set_particle(texture)
    meta.assert_isa(texture, rt.Texture)
    self._particle = texture
    self._native:setTexture(texture._native)
end

--- @brief
function rt.ParticleEmitter:set_opacity(alpha)
    self._opacity = alpha
    local r, g, b, a = 1, 1, 1, self._opacity
    self._native:setColors(
        r, g, b, 0, -- 1 : 5 : 1, ratio determines how long the particle will stay at given opacity
        r, g, b, a,
        r, g, b, a,
        r, g, b, a,
        r, g, b, a,
        r, g, b, a,
        r, g, b, 0
    )
end

--- @brief
function rt.ParticleEmitter:set_rotation(min, max)
    self._native:setRotation(min, max)
end

--- @brief
function rt.ParticleEmitter:set_sizes(min, max)
    self._native:setSizes(min, max)
end

--- @brief
function rt.ParticleEmitter:set_emission_rate(n_per_second)
    self._native:setEmissionRate(n_per_second)
end

--- @brief
function rt.ParticleEmitter:set_particle_lifetime(min, max)
    self._native:setParticleLifetime(min, max)
end

--- @brief
function rt.ParticleEmitter:set_emission_area(area)
    self._emission_area_shape = area
    if self._is_realized then self:reformat() end
end

--- @brief
function rt.ParticleEmitter:set_linear_velocity(x, y)
    self._native:setLinearAcceleration(x, y, x, y)
end

--- @brief
function rt.ParticleEmitter:set_radial_velocity(x)
    self._native:setRadialAcceleration(x, x)
end

--- @brief
function rt.ParticleEmitter:set_particle_lifetime(seconds)
    self._native:setParticleLifetime(seconds)
end

--- @brief
function rt.ParticleEmitter:set_spin(min, max)
    if max == nil then max = min end
    self._native:setSpin(min, max)
end

--- @brief
function rt.ParticleEmitter:emit(n)
    self._native:emit(n)
end

--- @brief
function rt.ParticleEmitter:set_color(color)
    if meta.is_hsva(color) then
        self._color = rt.hsva_to_rgba(color)
    elseif meta.is_lcha(color) then
        self._color = rt.lcha_to_rgba(color)
    else
        meta.assert_rgba(color)
        self._color = color
    end
end