require "overworld.coin_particle"
require "overworld.objects.coin"
require "common.matrix"

--- @class mn.CoinParticleSwarm
mn.CoinParticleSwarm = meta.class("CoinParticleSwarm")

local _round = function(x)
    return math.floor(x * 10e6) / 10e6
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

    local hues = {}
    for hue in keys(self._hue_to_quad) do table.insert(hues, hue) end
    table.sort(hues)

    -- build texture atlas
    local radius = self._canvas_scale * rt.settings.overworld.coin.radius
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
end

--- @brief
function mn.CoinParticleSwarm:create_from_state()
    self._particles = {}

    local add = function(x, y, hue, quad)
        table.insert(self._particles, {
            x = x,
            y = y,
            velocity_x = self._target_velocity_x,
            velocity_y = self._target_velocity_y,
            home_x = rt.random.number(-1, 1),
            home_y = rt.random.number(0, 1),
            hue = hue,
            quad = quad
        })
    end

    local stage_ids = rt.GameState:list_stage_ids()
    for id in values(stage_ids) do
        local n_coins = rt.GameState:get_stage_n_coins(id)
        for coin_i = 1, n_coins do
            if rt.GameState:get_stage_is_coin_collected(id, coin_i) then
                local hue = ow.Coin.index_to_hue(coin_i, n_coins)
                local quad = self._hue_to_quad[hue]
                assert(quad ~= nil)
                add(self._target_x, self._target_y, hue, quad)
            end
        end
    end

    local hues = {}
    for hue in keys(self._hue_to_quad) do table.insert(hues, hue) end
    for i = 1, 400 do
        local w, h = love.graphics.getDimensions()
        local hue = rt.random.choose(hues)
        add(
            self._target_x,
            self._target_y,
            hue,
            self._hue_to_quad[hue]
        )
    end

    self:_rebuild_spatial_hash()
end

--- @brief
function mn.CoinParticleSwarm:_rebuild_spatial_hash()
    self._spatial_hash:clear()
    local r = self._spatial_hash_cell_size

    for particle in values(self._particles) do
        local cell_x = math.floor(particle.x / r)
        local cell_y = math.floor(particle.y / r)

        local entry = self._spatial_hash:get(cell_x, cell_y)
        if entry == nil then
            entry = {}
            self._spatial_hash:set(cell_x, cell_y, entry)
        end

        table.insert(entry, particle)
    end
end

function mn.CoinParticleSwarm:update(delta)
    self:_rebuild_spatial_hash()

    local player_x = self._target_x
    local player_y = self._target_y

    local cell_r = self._spatial_hash_cell_size
    local particle_r = rt.settings.overworld.coin.radius

    -- XPBD parameters
    local distance_compliance = 0.01  -- Lower = stiffer constraint (adjust to taste)
    local iterations = 6       -- More iterations = more accurate
    local collision_compliance = 0.0  -- Stiffer for collisions (hard constraint)

    for particle in values(self._particles) do
        particle.velocity_x = particle.velocity_x * 0.98
        particle.velocity_y = particle.velocity_y * 0.98

        particle.x = particle.x + particle.velocity_x * delta
        particle.y = particle.y + particle.velocity_y * delta

        for i = 1, iterations do
            -- Home position constraint
            local home_x = player_x + particle.home_x * love.graphics.getWidth()
            local home_y = player_y + particle.home_y * love.graphics.getHeight()

            local dx = particle.x - home_x
            local dy = particle.y - home_y
            local distance = math.magnitude(dx, dy)

            if distance > math.eps then
                local constraint = distance
                local alpha = distance_compliance / (delta * delta)
                local delta_lambda = -constraint / (1.0 + alpha)

                local nx, ny = math.normalize(dx, dy)
                local correction_x = nx * delta_lambda
                local correction_y = ny * delta_lambda

                particle.x = particle.x + correction_x
                particle.y = particle.y + correction_y
            end

            -- Collision constraint with neighboring particles
            local cell_x, cell_y = math.floor(particle.x / cell_r), math.floor(particle.y / cell_r)
            for xi = -1, 1 do
                for yi = -1, 1 do
                    local entry = self._spatial_hash:get(cell_x + xi, cell_y + yi)
                    if entry ~= nil then
                        for other in values(entry) do
                            if other ~= particle then
                                local dx_col = particle.x - other.x
                                local dy_col = particle.y - other.y
                                local dist = math.magnitude(dx_col, dy_col)
                                local min_dist = particle_r * 2  -- Non-overlap distance

                                if dist < min_dist and dist > math.eps then
                                    -- Constraint: distance should be at least min_dist
                                    local constraint = dist - min_dist  -- Negative when overlapping
                                    local alpha_col = collision_compliance / (delta * delta)

                                    -- We have two particles with equal mass, so each moves half
                                    local w1 = 0.5  -- weight for particle
                                    local w2 = 0.5  -- weight for other
                                    local delta_lambda = -constraint / (w1 + w2 + alpha_col)

                                    local nx_col, ny_col = math.normalize(dx_col, dy_col)

                                    -- Apply correction (move particles apart)
                                    particle.x = particle.x + nx_col * delta_lambda * w1
                                    particle.y = particle.y + ny_col * delta_lambda * w1

                                    other.x = other.x - nx_col * delta_lambda * w2
                                    other.y = other.y - ny_col * delta_lambda * w2
                                end
                            end
                        end
                    end
                end
            end
        end

        particle.velocity_x = (particle.x - (particle.x - particle.velocity_x * delta)) / delta
        particle.velocity_y = (particle.y - (particle.y - particle.velocity_y * delta)) / delta
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
            --particle.x + self._target_x, particle.y + self._target_y,
            particle.x, particle.y,
            0,
            scale, scale,
            0.5 * w, 0.5 * h
        )
    end

    local player_x = self._target_x
    local player_y = self._target_y
    love.graphics.circle("fill", player_x, player_y, 2)
end

--- @brief
function mn.CoinParticleSwarm:set_target(x, y, velocity_x, velocity_y)
    self._target_x, self._target_y = x, y
    self._target_velocity_x, self._target_velocity_y = velocity_x, velocity_y
end