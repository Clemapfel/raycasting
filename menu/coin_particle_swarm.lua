require "overworld.coin_particle"
require "overworld.objects.coin"
require "common.matrix"

rt.settings.menu.coin_particle_swarm = {
    n_sub_steps = 1,
    collision_compliance = 0, --0.05,
    follow_compliance = 0.4,
    collision_radius_offset = 2, -- pc
    damping = 2,
    max_home_velocity = 1, -- radians per second
    circle_width_radius_factor = 7 -- times player radius
}

--- @class mn.CoinParticleSwarm
mn.CoinParticleSwarm = meta.class("CoinParticleSwarm")


--- @class mn.CoinParticleSwarmMode
mn.CoinParticleSwarmMode = meta.enum("CoinParticleSwarmMode", {
    FOLLOW = "FOLLOW",
    CIRCLE = "CIRCLE",
    DISPERSE = "DISPERSE",
})

--- @brief
function mn.CoinParticleSwarm:instantiate()
    self._target_x, self._target_y = 0, 0
    self._spatial_hash = rt.Matrix()
    self._spatial_hash_cell_size = rt.settings.overworld.coin.radius * 2

    self._canvas_scale = 1

    self._mode = mn.CoinParticleSwarmMode.CIRCLE

    -- collect all possible hue
    self._hue_to_quad = {}
    local stage_ids = rt.GameState:list_stage_ids()
    for id in values(stage_ids) do
        local n_coins = rt.GameState:get_stage_n_coins(id)
        for i = 1, n_coins do
            self._hue_to_quad[ow.Coin.index_to_hue(i, n_coins)] = true
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
    local radius = self._canvas_scale * 9 -- TODOrt.settings.overworld.coin.radius
    self._particle_radius = radius
    local particle = ow.CoinParticle(radius)
    local n_rows = math.ceil(math.sqrt(#hues))
    local n_columns = math.ceil(#hues / n_rows)

    self._above_player = {}
    self._below_player = {}

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
end

--- @brief
function mn.CoinParticleSwarm:create_from_state()
    self._particles = {}

    local home_angle_width = math.pi
    local add = function(hue, quad)
        local home_offset = rt.random.number(0, 2 * math.pi)
        local mass = rt.random.number(0, 1)
        local particle = {
            x = nil,
            y = nil,
            spawn_x = nil,
            spawn_y = nil, -- set below
            velocity_x = 0,
            velocity_y = 0,
            home_x = rt.random.number(-1, 1),
            home_y = rt.random.number(-1, 0), -- sic, only be above player
            home_velocity = rt.random.number(0.5, 1),
            home_offset = home_offset,
            home_offset_initial = home_offset,
            collided = {},
            hue = hue,
            quad = quad,
            radius = self._particle_radius,
            mass = 1 + math.mix(0, 1, mass)
        }

        particle.home_z = particle.home_offset / (2 * math.pi)
        particle.previous_x = particle.x
        particle.previous_y = particle.y
        particle.inverse_mass = 1 / particle.mass

        table.insert(self._particles, particle)
    end

    local w, h = self:_get_home_dimensions()

    local stage_ids = rt.GameState:list_stage_ids()
    for id in values(stage_ids) do
        local n_coins = rt.GameState:get_stage_n_coins(id)
        for coin_i = 1, n_coins do
            if rt.GameState:get_stage_is_coin_collected(id, coin_i) then
                local hue = ow.Coin.index_to_hue(coin_i, n_coins)
                add(hue, self._hue_to_quad[hue])
            end
        end
    end

    local hues = {}
    for hue in keys(self._hue_to_quad) do table.insert(hues, hue) end
    for i = 1, 1000 do
        local hue = rt.random.choose(hues)
        add(hue, self._hue_to_quad[hue])
    end

    -- distribute particles equally along both axes
    local home_x_width, home_y_width = self:_get_home_dimensions()
    for i, particle in ipairs(self._particles) do
        local t = (i - 1) / #self._particles
        particle.spawn_y = -1 -t
        particle.spawn_x = math.mix(-1, 1, t)
        particle.x = self._target_x + particle.spawn_x * home_x_width
        particle.y = self._target_y + particle.spawn_y * home_y_width
    end

    self:reset()
end

--- @brief
function mn.CoinParticleSwarm:set_mode(mode)
    meta.assert_enum_value(mode, mn.CoinParticleSwarmMode)
    self._mode = mode
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

-- XPBD constraint solver: enforce distance between particle and target position to be 0
local function _enforce_position(ax, ay, a_inverse_mass, px, py, alpha)

    local current_distance = math.distance(ax, ay, px, py)
    if current_distance < math.eps then return end

    local dx, dy = math.normalize(px - ax, py - ay)

    if a_inverse_mass < math.eps then return end

    -- constraint violation
    local C = current_distance - 0
    local correction = C / (a_inverse_mass + alpha)

    local x_correction = dx * correction * a_inverse_mass
    local y_correction = dy * correction * a_inverse_mass

    return x_correction, y_correction
end

--- @brief
function mn.CoinParticleSwarm:_get_home_dimensions()
    local alignment = rt.settings.menu_scene.stage_select.player_alignment
    local home_x_width = 0.5 * alignment * love.graphics.getWidth()
    local home_y_width = 0.5 * love.graphics.getHeight()
    return home_x_width, home_y_width
end

--- @brief
function mn.CoinParticleSwarm:update(delta)
    local particles = self._particles
    if not particles or #particles == 0 then return end

    local settings = rt.settings.menu.coin_particle_swarm

    local player_x, player_y = self._target_x, self._target_y

    local n_substeps = settings.n_sub_steps
    local collision_compliance = settings.collision_compliance
    local collision_radius_offset = settings.collision_radius_offset
    local follow_compliance = settings.follow_compliance
    local damping = settings.damping

    local function compliance_per_step(compliance, dt)
        if not compliance or compliance < 1e-9 then return 0 end
        return compliance / (dt * dt)
    end

    local sub_delta = delta / n_substeps
    local collision_compliance_per_step = compliance_per_step(collision_compliance, sub_delta)
    local follow_compliance_per_step = compliance_per_step(follow_compliance, sub_delta)

    -- update home position
    local home_x_width, home_y_width = self._get_home_dimensions()

    local elapsed = rt.SceneManager:get_elapsed()
    local home_x_offset = settings.circle_width_radius_factor * rt.settings.player.radius
    local max_home_velocity = settings.max_home_velocity

    require "table.clear"
    table.clear(self._above_player)
    table.clear(self._below_player)

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

            -- predict position
            particle.x = x + sub_delta * particle.velocity_x
            particle.y = y + sub_delta * particle.velocity_y
        end
        
        -- move towards home
        for particle in values(particles) do
            local home_x, home_y
            particle.home_z = math.sin(elapsed * particle.home_velocity * max_home_velocity + particle.home_offset)

            if self._mode == mn.CoinParticleSwarmMode.DISPERSE then
                home_x = player_x + particle.spawn_x * home_x_width * 0.5
                home_y = player_y + particle.spawn_y * home_y_width
            elseif self._mode == mn.CoinParticleSwarmMode.FOLLOW then
                home_x, home_y = player_x, player_y
            elseif self._mode == mn.CoinParticleSwarmMode.CIRCLE then
                home_x = player_x + particle.home_z * home_x_offset
                home_y = player_y + particle.home_y * home_y_width
            end

            if particle.home_z < 0 then
                table.insert(self._below_player, particle)
            else
                table.insert(self._above_player, particle)
            end
            
            local x_correction, y_correction = _enforce_position(
                particle.x, particle.y,
                particle.inverse_mass,
                home_x, home_y,
                follow_compliance_per_step
            )

            particle.x = particle.x + x_correction
            particle.y = particle.y + y_correction
        end

        -- rebuild spatial hash
        local cell_r = self._spatial_hash_cell_size
        self._spatial_hash:clear()
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
                    if entry ~= nil then
                        for other in values(entry) do
                            if current ~= other
                                and current.collided[other] ~= true
                                and other.collided[current] ~= true
                            then
                                local target_distance = collision_radius_offset + (current.radius + other.radius)
                                local a_correction_x, a_correction_y, b_correction_x, b_correction_y = _enforce_min_distance(
                                    current.x, current.y, other.x, other.y,
                                    current.inverse_mass, other.inverse_mass,
                                    target_distance,
                                    collision_compliance_per_step
                                )

                                if a_correction_x ~= nil then
                                    current.x = current.x + a_correction_x
                                    current.y = current.y + a_correction_y
                                    other.x = other.x + b_correction_x
                                    other.y = other.y + b_correction_y
                                end

                                current.collided[other] = true
                                other.collided[current] = true
                            end
                        end
                    end
                end
            end
        end

        -- update velocity
        for particle in values(particles) do
            particle.velocity_x = (particle.x - particle.previous_x) / sub_delta
            particle.velocity_y = (particle.y - particle.previous_y) / sub_delta
        end
    end
end

--- @brief
function mn.CoinParticleSwarm:_draw_particle(particle, native, scale)
    local _, _, w, h = particle.quad:getViewport()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        native, particle.quad,
        particle.x, particle.y,
        0,
        scale, scale,
        0.5 * w, 0.5 * h
    )
end

--- @brief
function mn.CoinParticleSwarm:draw_above_player()
    local scale = 1 / self._canvas_scale
    local native = self._texture_atlas:get_native()
    for particle in values(self._above_player) do
        self:_draw_particle(particle, native, scale)
    end
end

--- @brief
function mn.CoinParticleSwarm:draw_below_player()
    local scale = 1 / self._canvas_scale
    local native = self._texture_atlas:get_native()
    for particle in values(self._below_player) do
        self:_draw_particle(particle, native, scale)
    end
end

--- @brief
function mn.CoinParticleSwarm:set_target(x, y)
    self._target_x, self._target_y = x, y
end

--- @brief
function mn.CoinParticleSwarm:reset()
    local home_x_width, home_y_width = self:_get_home_dimensions()
    for particle in values(self._particles) do
        particle.x = self._target_x + particle.spawn_x * home_x_width
        particle.y = math.min(-2 * self._particle_radius, self._target_y + particle.spawn_y * home_y_width)
        -- ensure off-screen

        particle.velocity_x = 0
        particle.velocity_y = 0
        particle.home_offset = particle.home_offset_initial
    end
end