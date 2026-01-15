rt.settings.fluid_projectiles = {
    threshold = 0.6,
    smoothness = 0.0,
    density_factor = 1,
    radius = 15 * 3,
    n_particles = 128,
    min_mass = 2,
    max_mass = 4,
    min_scale = 1,
    max_scale = 1,
    core_scale = 0.8,

    follow_alpha = 0.13,         -- target attraction
    core_follow_alpha = 0.007,
    cohesion_alpha = 0.16,       -- particle-to-particle attraction
    collision_alpha = 0.05,      -- prevents overlap
    damping = 0.7,               -- overall velocity damping
    n_substeps = 10
}

--- @class
ow.FluidProjectiles = meta.class("FluidProjectiles")

local _particle_texture_shader = rt.Shader("overworld/fluid_projectiles_particle_texture.glsl")
local _threshold_shader = rt.Shader("overworld/fluid_projectiles.glsl", { MODE = 0})
local _outline_shader = rt.Shader("overworld/fluid_projectiles.glsl", { MODE = 1 })

local _texture_format = rt.TextureFormat.RGBA8

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
    if n_particles == nil then n_particles = rt.settings.fluid_projectiles.n_particles end
    if radius == nil then radius = rt.settings.fluid_projectiles.radius end

    meta.assert(x, "Number", y, "Number", n_particles, "Number", radius, "Number")

    if self._radius_to_particle_texture[radius] == nil then
        local padding = 3 -- px
        local ratio = 0
        local w, h = (radius + padding) * 2, (radius + padding) * 2

        local texture = rt.RenderTexture(w, h, 0, _texture_format)

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
        particle_texture = self._radius_to_particle_texture[radius],
        spatial_hash = rt.Matrix(),
        spatial_hash_cell_size = 2 * radius,
        particles = {},
        center_of_mass_x = x,
        center_of_mass_y = y,
        core_particles = {},
        center_body_radius = 0.5 * radius,
        canvas = nil,
        canvas_width = 0,
        canvas_height = 0,
        centroid_x = x,
        centroid_y = y,
    }

    local hue = (batch.id % 8) / 8
    batch.core_r, batch.core_g, batch.core_b = rt.lcha_to_rgba(0.8, 1, hue, 1)

    local settings = rt.settings.fluid_projectiles

    local id = 1
    local add_particle = function(to_insert, x, y, radius)
        local angle = rt.random.number(0, 2 * math.pi)
        local length = rt.random.number(0, radius)
        x, y = x + math.cos(angle) * length, y + math.sin(angle) * length
        local mass = rt.random.number(settings.min_mass, settings.max_mass)
        local particle = {
            id = id,
            x = x,
            y = y,
            velocity_x = 0,
            velocity_y = 0,
            previous_x = x,
            previous_y = y,
            mass = mass,
            radius = radius,
            scale = rt.random.number(settings.min_scale, settings.max_scale),
            collided = {} -- Set<Particle>
        }

        id = id + 1
        table.insert(to_insert, particle)
    end

    for inner_i = 1, n_particles do
        add_particle(batch.particles, x, y, radius)
    end

    for outer_i = 1, 1 do
        add_particle(batch.core_particles, x, y, radius * settings.core_scale)
    end

    for particle in values(batch.core_particles) do
        particle.mass = 0.5 * particle.mass
    end

    for particles in range(batch.particles, batch.core_particles) do
        for particle in values(particles) do
            particle.inverse_mass = 1 / (particle.mass * particle.scale)
        end
    end

    self._batch_id_to_batch[batch.id] = batch
    self._current_batch_id = self._current_batch_id + 1

    return batch.id
end

-- XPBD constraint solver: enforce distance between particles to be larger than minimum
-- XPBD constraint solver: enforce distance between particles to be larger than minimum
-- Modified to prevent erratic position swapping
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

    -- Prevent division by zero when particles are at same position
    if current_distance < math.eps then
        -- Add small random offset to separate overlapping particles
        dx = (math.random() - 0.5) * 0.01
        dy = (math.random() - 0.5) * 0.01
        current_distance = math.magnitude(dx, dy)
    end

    dx, dy = math.normalize(dx, dy)

    -- constraint violation
    local C = current_distance - target_distance

    local mass_sum = inverse_mass_a + inverse_mass_b
    if mass_sum <= math.eps then return end

    -- apply correction with clamping to prevent overshooting
    local correction = -C / (mass_sum + compliance)

    -- CRITICAL: Clamp the correction to prevent overcorrection
    -- This prevents particles from being pushed too far in a single substep
    local max_correction = math.abs(C) * 0.8  -- Only correct 80% of violation per step
    correction = math.clamp(correction, -max_correction, max_correction)

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
    local settings = rt.settings.fluid_projectiles

    local n_substeps = settings.n_substeps
    local sub_delta = delta / n_substeps
    local function compliance_per_step(compliance)
        if not compliance or compliance < 1e-9 then return 0 end
        return compliance / (sub_delta^2)
    end

    local follow_compliance = compliance_per_step(settings.follow_alpha)
    local cohesion_compliance = compliance_per_step(settings.cohesion_alpha)
    local collision_compliance = compliance_per_step(settings.collision_alpha)

    local a = settings.core_follow_alpha
    if love.keyboard.isDown("p") then a = a / 100 end
    local core_follow_compliance = compliance_per_step(a)

    local damping = settings.damping
    local viscosity = settings.viscosity

    local pre_solve = function(particles)
        for particle in values(particles) do
            table.clear(particle.collided)

            particle.previous_x = particle.x
            particle.previous_y = particle.y

            particle.velocity_x = particle.velocity_x * (1 - damping * sub_delta)
            particle.velocity_y = particle.velocity_y * (1 - damping * sub_delta)

            particle.x = particle.x + sub_delta * particle.velocity_x
            particle.y = particle.y + sub_delta * particle.velocity_y
        end
    end

    local enforce_distance = function(particles, target_x, target_y, compliance)
        for particle in values(particles) do
            local x_correction, y_correction = _enforce_position(
                particle.x, particle.y,
                particle.inverse_mass,
                target_x, target_y,
                compliance
            )

            particle.x = particle.x + x_correction
            particle.y = particle.y + y_correction
        end
    end

    local post_solve = function(particles)
        for particle in values(particles) do
            particle.velocity_x = (particle.x - particle.previous_x) / sub_delta
            particle.velocity_y = (particle.y - particle.previous_y) / sub_delta
        end
    end

    for _, batch in pairs(self._batch_id_to_batch) do
        local cell_r = batch.spatial_hash_cell_size
        local interaction_distance = cell_r * math.sqrt(2)

        for step = 1, n_substeps do
            pre_solve(batch.particles)

            -- Move towards target
            enforce_distance(batch.particles, batch.target_x, batch.target_y, follow_compliance)

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
                                    local factor = ternary(love.keyboard.isDown("space"), 0.75, 0.15)
                                    local min_distance = factor * current.scale * current.radius + other.scale * other.radius

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

            post_solve(batch.particles)

            -- core particles, move towards center of mass
            pre_solve(batch.core_particles)
            enforce_distance(batch.core_particles, batch.center_of_mass_x, batch.center_of_mass_y, core_follow_compliance)
            post_solve(batch.core_particles)

            -- update boundaries
            local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
            local centroid_x, centroid_y, n = 0, 0, 0
            local center_of_mass_x, center_of_mass_y, total_mass = 0, 0, 0

            -- update velocity, measure bounds
            for particle in values(batch.particles) do
                local r = 2 * particle.radius * particle.scale
                min_x = math.min(min_x, particle.x - r)
                max_x = math.max(max_x, particle.x + r)
                min_y = math.min(min_y, particle.y - r)
                max_y = math.max(max_y, particle.y + r)

                centroid_x = centroid_x + particle.x
                centroid_y = centroid_y + particle.y
                n = n + 1

                center_of_mass_x = center_of_mass_x + particle.x * particle.mass * particle.scale
                center_of_mass_y = center_of_mass_y + particle.y * particle.mass * particle.scale
                total_mass = total_mass + particle.mass
            end

            batch.center_of_mass_x = center_of_mass_x / total_mass
            batch.center_of_mass_y = center_of_mass_y / total_mass
            batch.centroid_x = centroid_x / n
            batch.centroid_y = centroid_y / n

            local padding = 2 * cell_r
            local canvas_w = math.ceil((max_x - min_x) + 2 * padding)
            local canvas_h = math.ceil((max_y - min_y) + 2 * padding)

            -- only grow
            if batch.canvas_width < canvas_w
                or batch.canvas_height < canvas_h
            then
                local new_w = math.max(batch.canvas_width, canvas_w)
                local new_h = math.max(batch.canvas_height, canvas_h)
                batch.canvas = rt.RenderTexture(
                    new_w, new_h,
                    0,
                    rt.TextureFormat.RGBA8
                )
                batch.canvas_width, batch.canvas_height = batch.canvas:get_size()
            end
        end
    end
end

--- @brief
function ow.FluidProjectiles:draw()
    local n_batches = table.sizeof(self._batch_id_to_batch)

    local darken = 0.8

    for i, batch in ipairs(self._batch_id_to_batch) do
        if batch.canvas == nil then goto skip end

        love.graphics.push("all")
        batch.canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(
            -batch.centroid_x + batch.canvas_width / 2,
            -batch.centroid_y + batch.canvas_height / 2
        )

        local w, h = batch.particle_texture:get_size()

        rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
        local t = rt.settings.fluid_projectiles.density_factor
        love.graphics.setColor(t, t, t, t)

        for particle in values(batch.particles) do
            local scale = particle.scale
            love.graphics.draw(batch.particle_texture:get_native(),
                particle.x, particle.y,
                0,
                scale, scale,
                0.5 * w, 0.5 * h
            )
        end

        batch.canvas:unbind()
        love.graphics.pop()

        love.graphics.setColor(darken * batch.core_r, darken * batch.core_g, darken * batch.core_b, 1)
        love.graphics.line(batch.centroid_x, batch.centroid_y, batch.target_x, batch.target_y)

        local r = batch.spatial_hash_cell_size / 6
        love.graphics.setColor(batch.core_r, batch.core_g, batch.core_b, 1)
        love.graphics.circle("fill", batch.target_x, batch.target_y, r)

        love.graphics.setColor(darken * batch.core_r, darken * batch.core_g, darken * batch.core_b, 1)
        love.graphics.circle("line", batch.target_x, batch.target_y, r)

        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)

        local draw_canvas = function()
            love.graphics.draw(batch.canvas:get_native(),
                batch.centroid_x - 0.5 * batch.canvas_width,
                batch.centroid_y - 0.5 * batch.canvas_height
            )
        end

        local fill_r, fill_g, fill_b = rt.Palette.BLACK:unpack()
        local alpha = 1
        love.graphics.setColor(alpha * fill_r, alpha * fill_g, alpha * fill_b, alpha)
        _threshold_shader:bind()
        _threshold_shader:send("threshold", rt.settings.fluid_projectiles.threshold)
        _threshold_shader:send("smoothness", rt.settings.fluid_projectiles.smoothness)
        draw_canvas()
        _threshold_shader:unbind()


        love.graphics.setColor(batch.core_r, batch.core_g, batch.core_b, 1)
        _outline_shader:bind()
        draw_canvas()
        _outline_shader:unbind()

        love.graphics.setBlendMode("alpha")

        love.graphics.setColor(batch.core_r, batch.core_g, batch.core_b, 1)
        for particle in values(batch.core_particles) do
            love.graphics.circle("fill",
                particle.x, particle.y, particle.radius * particle.scale
            )
        end

        love.graphics.setColor(darken * batch.core_r, darken * batch.core_g, darken * batch.core_b, 1)
        for particle in values(batch.core_particles) do
            love.graphics.circle("line",
                particle.x, particle.y, particle.radius * particle.scale
            )
        end

        ::skip::
    end

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