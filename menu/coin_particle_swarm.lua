require "overworld.coin_particle"
require "overworld.objects.coin"
require "common.matrix"

--- @class mn.CoinParticleSwarm
mn.CoinParticleSwarm = meta.class("CoinParticleSwarm")

local _round = function(x)
    return x
end

--- @brief
function mn.CoinParticleSwarm:instantiate()
    self._target_x, self._target_y = 0, 0
    self._target_velocity_x, self._target_velocity_y = 0, 0
    self._spatial_hash = rt.Matrix()
    self._spatial_hash_cell_size = rt.settings.overworld.coin.radius * 2

    self._canvas_scale = 1

    -- collect all possible hue
    self._hue_to_quad = {}
    local stage_ids = rt.GameState:list_stage_ids()
    for id in values(stage_ids) do
        local n_coins = rt.GameState:get_stage_n_coins(id)
        for i = 1, n_coins do
            self._hue_to_quad[_round(ow.Coin.index_to_hue(i, n_coins))] = true
        end
    end

    -- TODO
    for hue in range(0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9) do
        self._hue_to_quad[hue] = true
    end
    -- TODO

    local hues = {}
    for hue in keys(self._hue_to_quad) do table.insert(hues, hue) end
    table.sort(hues)

    -- build texture atlas
    local radius = self._canvas_scale * rt.settings.overworld.coin.radius
    self._particle_radius = radius
    local particle = ow.CoinParticle(radius)
    local n_rows = math.ceil(math.sqrt(#hues))
    local n_columns = math.ceil(#hues / n_rows)

    self._padding = math.ceil(0.25 * radius)
    local quad_w = 2 * radius + 2 * self._padding
    local quad_h = quad_w

    self._texture_atlas = rt.RenderTexture(
        quad_w * n_columns,
        quad_h * n_rows,
        rt.GameState:get_msaa_quality()
    )

    love.graphics.push("all")
    love.graphics.reset()
    self._texture_atlas:bind()

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

            self._hue_to_quad[hue] = love.graphics.newQuad(
                quad_x, quad_y, quad_w, quad_h,
                self._texture_atlas:get_native()
            )

            hue_i = hue_i + 1
        end
    end

    ::exit::

    self._texture_atlas:unbind()
    love.graphics.pop()

    self._particles = {}
    self:create_from_state()

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then self:create_from_state() end
    end)
end

--- @brief
function mn.CoinParticleSwarm:create_from_state()
    self._particles = {}

    local add = function(x, y, hue, quad)
        local hx, hy
        if rt.random.toss_coin() then
            hx = rt.random.number(-2, -1)
        else
            hx = rt.random.number(1, 2)
        end

        if rt.random.toss_coin() then
            hy = rt.random.number(-2, -1)
        else
            hy = rt.random.number(1, 2)
        end

        local to_insert = {
            x = x + hx * love.graphics.getWidth(),
            y = y + hy * love.graphics.getHeight(),
            velocity_x = self._target_velocity_x,
            velocity_y = self._target_velocity_y,
            home_x = 0,
            home_y = 0,
            collided = {},
            hue = hue,
            quad = quad,
            radius = self._particle_radius,
            mass = 1
        }

        to_insert.previous_x = x
        to_insert.previous_y = y
        to_insert.inverse_mass = 1 / to_insert.mass
        table.insert(self._particles, to_insert)
    end

    local stage_ids = rt.GameState:list_stage_ids()
    for id in values(stage_ids) do
        local n_coins = rt.GameState:get_stage_n_coins(id)
        for coin_i = 1, n_coins do
            if rt.GameState:get_stage_is_coin_collected(id, coin_i) then
                local hue = ow.Coin.index_to_hue(coin_i, n_coins)
                local quad = self._hue_to_quad[hue]
                assert(quad ~= nil)
                add(0, 0, hue, quad)
            end
        end
    end

    local hues = {}
    for hue in keys(self._hue_to_quad) do table.insert(hues, hue) end
    for i = 1, 400 do
        local w, h = love.graphics.getDimensions()
        local hue = rt.random.choose(hues)
        add(
            rt.random.number(-0.5 * w, 0.5 * w),
            rt.random.number(-0.5 * h, 0.5 * h),
            hue,
            self._hue_to_quad[hue]
        )
    end
end

local function _enforce_min_distance(particle_a, particle_b, target_distance, alpha)
    local ax, ay = particle_a.x, particle_a.y
    local bx, by = particle_b.x, particle_b.y

    local dx = bx - ax
    local dy = by - ay
    local dist_sq = dx*dx + dy*dy

    -- Optimization: Check squared distance first to avoid sqrt
    if dist_sq >= target_distance^2 then
        return
    end

    local current_distance = math.sqrt(dist_sq)

    -- Constraint Violation (C < 0 means penetration)
    local C = current_distance - target_distance

    -- Normalize direction (safe handle for zero distance)
    if current_distance < 1e-6 then
        dx, dy = 1, 0
        current_distance = 1e-6
    else
        dx = dx / current_distance
        dy = dy / current_distance
    end

    local inverse_mass_a = particle_a.inverse_mass or (particle_a.mass > 0 and 1/particle_a.mass or 0)
    local inverse_mass_b = particle_b.inverse_mass or (particle_b.mass > 0 and 1/particle_b.mass or 0)
    local w_sum = inverse_mass_a + inverse_mass_b

    if w_sum < 1e-6 then return end

    -- XPBD Correction: lambda = -C / (w_sum + alpha)
    -- We apply the correction directly to position
    local correction = -C / (w_sum + alpha)

    -- Apply corrections
    -- weighted by inverse mass (heavier objects move less)
    particle_a.x = ax - dx * correction * inverse_mass_a
    particle_a.y = ay - dy * correction * inverse_mass_a

    particle_b.x = bx + dx * correction * inverse_mass_b
    particle_b.y = by + dy * correction * inverse_mass_b
end

local function _enforce_position_constraint(particle, px, py, alpha)
    local ax, ay = particle.x, particle.y

    local dx = px - ax
    local dy = py - ay
    local dist_sq = dx*dx + dy*dy

    -- If effectively at target, skip
    if dist_sq < 1e-6 then return end

    local current_distance = math.sqrt(dist_sq)

    -- Normalize
    local nx = dx / current_distance
    local ny = dy / current_distance

    local inverse_mass = particle.inverse_mass or (particle.mass > 0 and 1/particle.mass or 0)
    if inverse_mass < 1e-6 then return end

    -- We want distance to be 0, so C = current_distance
    local C = current_distance

    -- XPBD Correction
    local correction = C / (inverse_mass + alpha)

    -- Move particle towards target
    particle.x = ax + nx * correction * inverse_mass
    particle.y = ay + ny * correction * inverse_mass
end

function mn.CoinParticleSwarm:update(delta)
    local particles = self._particles
    if not particles or #particles == 0 then return end
 
    local n_substeps = debugger.get("n_substeps") or 4
    local collision_compliance = debugger.get("collision_compliance") or 0
    local collision_radius_offset = debugger.get("collision_radius_offset") or 0
    local follow_compliance = debugger.get("follow_compliace") or 0.5
    local damping = debugger.get("damping") or 2.0

    local function compliance_per_step(compliance, dt)
        if not compliance or compliance < 1e-9 then return 0 end
        return compliance / (dt * dt)
    end

    local sub_delta = delta / n_substeps
    local collision_compliance_per_step = compliance_per_step(collision_compliance, sub_delta)
    local follow_compliance_per_step = compliance_per_step(follow_compliance, sub_delta)

    for step = 1, n_substeps do
        for particle in values(particles) do
            local x, y = particle.x, particle.y

            table.clear(particle.collided)

            -- store previous position
            particle.previous_x = x
            particle.previous_y = y

            -- apply damping
            particle.velocity_x = particle.velocity_x * (1 - damping * sub_delta)
            particle.velocity_y = particle.velocity_y * (1 - damping * sub_delta)

            -- predicted position
            particle.x = x + sub_delta * particle.velocity_x
            particle.y = y + sub_delta * particle.velocity_y
        end

        -- rebuild spatial hash
        local cell_r = self._spatial_hash_cell_size
        self._spatial_hash:clear(true) -- keep allocated
        for particle in values(particles) do
            local cell_x = math.floor(particle.x / cell_r)
            local cell_y = math.floor(particle.y / cell_r)

            local entry = self._spatial_hash:get(cell_x, cell_y)
            if entry == nil then
                entry = {}
                self._spatial_hash:set(cell_x, cell_y, entry)
            end
            table.insert(entry, particle)
        end

        -- solve collision
        for current in values(particles) do
            local cell_x = math.floor(current.x / cell_r)
            local cell_y = math.floor(current.y / cell_r)

            for y_offset = -1, 1 do
                for x_offset = -1, 1 do
                    local entry = self._spatial_hash:get(cell_x + x_offset, cell_y + y_offset)
                    if entry then
                        for other in values(entry) do
                            if current ~= other then
                                local target_distance = collision_radius_offset + (current.radius + other.radius)
                                _enforce_min_distance(current, other, target_distance, collision_compliance_per_step)
                            end
                        end
                    end
                end
            end
        end

        -- move to home
        for current in values(particles) do
            _enforce_position_constraint(
                current,
                current.home_x, current.home_y,
                follow_compliance_per_step
            )
        end

        -- update velocity
        for particle in values(particles) do
            particle.velocity_x = (particle.x - particle.previous_x) / sub_delta
            particle.velocity_y = (particle.y - particle.previous_y) / sub_delta
        end
    end
end

--- @brief
function mn.CoinParticleSwarm:draw()
    local scale = 1 / self._canvas_scale
    local native = self._texture_atlas:get_native()
    love.graphics.setColor(1, 1, 1, 1)
    for particle in values(self._particles) do
        local _, _, w, h = particle.quad:getViewport()
        love.graphics.draw(
            native, particle.quad,
            particle.x + self._target_x, particle.y + self._target_y,
            --particle.x, particle.y,
            0,
            scale, scale,
            0.5 * w, 0.5 * h
        )
    end
end

--- @brief
function mn.CoinParticleSwarm:set_target(x, y, velocity_x, velocity_y)
    self._target_x, self._target_y = x, y
    self._target_velocity_x, self._target_velocity_y = velocity_x, velocity_y
end