--- @class
ow.FluidProjectiles = meta.class("FluidProjectiles")

local _particle_texture_shader = rt.Shader("overworld/fluid_projectiles_particle_texture.glsl")

--- @brief
function ow.FluidProjectiles:instantiate()
    self._radius_to_particle_texture = {}
    self._batch_id_to_batch = {}
    self._current_batch_id = 1

    self._inner_color = rt.Palette.ORANGE
    self._outer_color = rt.Palette.GRAY_2
end

--- @brief
function ow.FluidProjectiles:add(x, y, n_particles, radius)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if n_particles == nil then n_particles = 32 end
    if radius == nil then radius = 16 end

    meta.assert(x, "Number", y, "Number", n_particles, "Number", radius, "Number")

    if self._radius_to_particle_texture[radius] == nil then
        local padding = 3 -- px
        local ratio = 0
        local w, h = (radius + padding) * 2, (radius + padding) * 2

        local texture = rt.RenderTexture(w, h)

        love.graphics.push("all")
        love.graphics.reset()
        _particle_texture_shader:bind()
        texture:bind()
        love.graphics.rectangle("fill", 0, 0, w, h)
        texture:unbind()
        _particle_texture_shader:unbind()
        love.graphics.pop()

        self._radius_to_particle_texture[radius] = texture
    end

    local batch = {
        id = self._current_batch_id,
        target_x = x,
        target_y = y,
        texture = self._radius_to_particle_texture[radius],
        spatial_hash = rt.Matrix(),
        spatial_hash_cell_size = 2 * radius,
        outer_particles = {},
        particles = {},
        rest_density = n_particles / (math.pi * (radius * 3)^2) -- approximate initial density
    }

    local id = 1
    local add_particle = function(to_insert, x, y)
        local angle = rt.random.number(0, 2 * math.pi)
        local length = rt.random.number(0, radius)
        x, y = x + math.cos(angle) * length, y + math.sin(angle) * length
        local max_mass = 4
        local mass_step = 16
        local mass = math.mix(1 / max_mass, max_mass, (id % mass_step) / mass_step)
        local particle = {
            id = id,
            x = x,
            y = y,
            velocity_x = -1 * math.cos(angle),
            velocity_y = -1 * math.sin(angle),
            previous_x = x,
            previous_y = y,
            mass = mass,
            radius = radius,
            scale = rt.random.number(1, 2),
            collided = {} -- Set<Particle>
        }

        id = id + 1
        particle.inverse_mass = 1 / particle.mass
        table.insert(to_insert, particle)
    end

    for inner_i = 1, n_particles do
        add_particle(batch.particles, x, y)
    end

    self._batch_id_to_batch[batch.id] = batch
    self._current_batch_id = self._current_batch_id + 1

    return batch.id
end

-- XPBD constraint solver: enforce distance between particles to be larger than minimum
local function _enforce_min_distance(
    ax, ay, bx, by,
    inverse_mass_a, inverse_mass_b,
    target_distance,
    compliance
)
    local dx = bx - ax
    local dy = by - ay

    local current_distance = math.magnitude(dx, dy)
    if current_distance >= target_distance then
        return
    end

    dx, dy = math.normalize(dx, dy)

    -- constraint violation
    local C = current_distance - target_distance

    local mass_sum = inverse_mass_a + inverse_mass_b
    if mass_sum <= math.eps then return end

    -- apply correction
    local correction = -C / (mass_sum + compliance)

    local a_correction_x = -1 * dx * correction * inverse_mass_a
    local a_correction_y = -1 * dy * correction * inverse_mass_a

    local b_correction_x =  1 * dx * correction * inverse_mass_b
    local b_correction_y =  1 * dy * correction * inverse_mass_b

    return a_correction_x, a_correction_y, b_correction_x, b_correction_y
end

-- XPBD constraint solver: enforce distance between particles to be smaller than maximum
local function _enforce_max_distance(
    ax, ay, bx, by,
    inverse_mass_a, inverse_mass_b,
    target_distance,
    compliance
)
    local dx = bx - ax
    local dy = by - ay

    local current_distance = math.magnitude(dx, dy)
    if current_distance <= target_distance then
        return
    end

    dx, dy = math.normalize(dx, dy)

    -- constraint violation
    local C = current_distance - target_distance

    local mass_sum = inverse_mass_a + inverse_mass_b
    if mass_sum <= math.eps then return end

    -- apply correction
    local correction = -C / (mass_sum + compliance)

    local a_correction_x = -1 * dx * correction * inverse_mass_a
    local a_correction_y = -1 * dy * correction * inverse_mass_a

    local b_correction_x = 1 * dx * correction * inverse_mass_b
    local b_correction_y = 1 * dy * correction * inverse_mass_b

    return a_correction_x, a_correction_y, b_correction_x, b_correction_y
end

-- XPBD constraint solver: enforce distance between particle and target position to be 0
local function _enforce_position(ax, ay, a_inverse_mass, px, py, alpha)
    local current_distance = math.distance(ax, ay, px, py)
    if current_distance < math.eps then return 0, 0 end

    local dx, dy = math.normalize(px - ax, py - ay)

    if a_inverse_mass < math.eps then return 0, 0 end

    -- constraint violation
    local C = current_distance - 0
    local correction = C / (a_inverse_mass + alpha)

    local x_correction = dx * correction * a_inverse_mass
    local y_correction = dy * correction * a_inverse_mass

    return x_correction, y_correction
end

-- XPBD constraint solver: cohesion force (attracts particles within interaction range)
local function _enforce_cohesion(
    ax, ay, bx, by,
    inverse_mass_a, inverse_mass_b,
    rest_distance,
    compliance
)
    local dx = bx - ax
    local dy = by - ay

    local current_distance = math.magnitude(dx, dy)

    dx, dy = math.normalize(dx, dy)

    -- attraction force that increases as distance increases (spring-like)
    local C = current_distance - rest_distance

    local mass_sum = inverse_mass_a + inverse_mass_b
    if mass_sum <= math.eps then return end

    -- apply correction
    local correction = -C / (mass_sum + compliance)

    local a_correction_x = -1 * dx * correction * inverse_mass_a
    local a_correction_y = -1 * dy * correction * inverse_mass_a

    local b_correction_x = 1 * dx * correction * inverse_mass_b
    local b_correction_y = 1 * dy * correction * inverse_mass_b

    return a_correction_x, a_correction_y, b_correction_x, b_correction_y
end

--- @brief
function ow.FluidProjectiles:update(delta)
    local settings = {
        follow_alpha = 0.15,          -- target attraction
        cohesion_alpha = 0.1,       -- particle-to-particle attraction
        collision_alpha = 0.9,      -- prevents overlap
        damping = 4                   -- overall velocity damping
    }

    local n_substeps = 10
    local sub_delta = delta / n_substeps
    local function compliance_per_step(compliance)
        if not compliance or compliance < 1e-9 then return 0 end
        return compliance / (sub_delta^2)
    end

    local follow_compliance = compliance_per_step(settings.follow_alpha)
    local cohesion_compliance = compliance_per_step(settings.cohesion_alpha)
    local collision_compliance = compliance_per_step(settings.collision_alpha)

    local damping = settings.damping
    local viscosity = settings.viscosity

    for _, batch in pairs(self._batch_id_to_batch) do
        local cell_r = batch.spatial_hash_cell_size
        local interaction_distance = cell_r * math.sqrt(2)

        for step = 1, n_substeps do
            -- Integration and damping
            for particle in values(batch.particles) do
                table.clear(particle.collided)

                particle.previous_x = particle.x
                particle.previous_y = particle.y

                particle.velocity_x = particle.velocity_x * (1 - damping * sub_delta)
                particle.velocity_y = particle.velocity_y * (1 - damping * sub_delta)

                particle.x = particle.x + sub_delta * particle.velocity_x
                particle.y = particle.y + sub_delta * particle.velocity_y
            end

            -- Move towards target
            for particle in values(batch.particles) do
                local x_correction, y_correction = _enforce_position(
                    particle.x, particle.y,
                    particle.inverse_mass,
                    batch.target_x, batch.target_y,
                    follow_compliance
                )

                particle.x = particle.x + x_correction
                particle.y = particle.y + y_correction
            end

            -- Rebuild spatial hash
            batch.spatial_hash:clear()
            for particle in values(batch.particles) do
                local cell_x = math.floor(particle.x / cell_r)
                local cell_y = math.floor(particle.y / cell_r)

                local entry = batch.spatial_hash:get(cell_x, cell_y)
                if entry == nil then
                    entry = {}
                    batch.spatial_hash:set(cell_x, cell_y, entry)
                end
                table.insert(entry, particle)
            end

            -- Solve constraints: cohesion, collision, viscosity
            for current in values(batch.particles) do
                local cell_x = math.floor(current.x / cell_r)
                local cell_y = math.floor(current.y / cell_r)

                for y_offset = -1, 1 do
                    for x_offset = -1, 1 do
                        local entry = batch.spatial_hash:get(cell_x + x_offset, cell_y + y_offset)
                        if entry ~= nil then
                            for other in values(entry) do
                                if current ~= other
                                    and current.collided[other] ~= true
                                    and other.collided[current] ~= true
                                then
                                    local dx = other.x - current.x
                                    local dy = other.y - current.y
                                    local distance = math.magnitude(dx, dy)

                                    local interaction_t = rt.InterpolationFunctions.LINEAR(math.min(1, distance / interaction_distance))
                                    interaction_t = 1 --math.mix(1 - 0.05, 1, interaction_t)

                                    -- Collision constraint (prevent overlap)
                                    local min_distance = 0.25 * current.scale * current.radius + other.scale * other.radius
                                    --local min_distance = current.radius + other.radius
                                    do
                                        local a_cx, a_cy, b_cx, b_cy = _enforce_min_distance(
                                            current.x, current.y, other.x, other.y,
                                            current.inverse_mass, other.inverse_mass,
                                            min_distance,
                                            collision_compliance * interaction_t
                                        )

                                        if a_cx ~= nil then
                                            current.x = current.x + a_cx
                                            current.y = current.y + a_cy
                                            other.x = other.x + b_cx
                                            other.y = other.y + b_cy
                                        end
                                    end

                                    -- Cohesion constraint (attraction within range)
                                    do
                                        local a_cx, a_cy, b_cx, b_cy = _enforce_cohesion(
                                            current.x, current.y, other.x, other.y,
                                            current.inverse_mass, other.inverse_mass,
                                            min_distance,
                                            cohesion_compliance * interaction_t
                                        )

                                        if a_cx ~= nil then
                                            current.x = current.x + a_cx
                                            current.y = current.y + a_cy
                                            other.x = other.x + b_cx
                                            other.y = other.y + b_cy
                                        end
                                    end

                                    current.collided[other] = true
                                    other.collided[current] = true
                                end
                            end
                        end
                    end
                end
            end

            -- Update velocity
            for particle in values(batch.particles) do
                particle.velocity_x = (particle.x - particle.previous_x) / sub_delta
                particle.velocity_y = (particle.y - particle.previous_y) / sub_delta
            end
        end
    end
end

--- @brief
function ow.FluidProjectiles:draw()
    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")

    local t = 1
    love.graphics.setColor(t, t, t, t)

    for batch in values(self._batch_id_to_batch) do
        local w, h = batch.texture:get_size()
        local draw_particle = function(particle)
            local scale = particle.scale
            love.graphics.draw(batch.texture:get_native(),
                particle.x, particle.y,
                0,
                scale, scale,
                0.5 * w, 0.5 * h
            )
        end

        love.graphics.setColor(1, 1, 1, 1)

        for particle in values(batch.particles) do
            draw_particle(particle)
        end
    end

    love.graphics.setBlendMode("alpha")
    rt.Palette.BLACK:bind()
    for batch in values(self._batch_id_to_batch) do
        love.graphics.circle("fill", batch.target_x, batch.target_y, 0.5^3 * batch.spatial_hash_cell_size)
    end
    love.graphics.pop()
end

--- @brief
function ow.FluidProjectiles:set_target_position(...)
    if select("#", ...) == 2 then
        -- called as: set_target_position(x, y), apply to first batch
        local x = select(1, ...)
        local y = select(2, ...)
        local _, batch = next(self._batch_id_to_batch)
        if batch ~= nil then
            batch.target_x, batch.target_y = x, y
        end
    else
        -- called as: set_target_position(batch_i, x, y)
        local batch_i = select(1, ...)
        local batch = self._batch_id_to_batch[batch_i]
        if batch == nil then
            rt.error("In ow.FluidProjectiles: no projectile batch with id `", batch_i, "`")
        end

        batch.target_x = select(2, ...)
        batch.target_y = select(3, ...)
    end
end