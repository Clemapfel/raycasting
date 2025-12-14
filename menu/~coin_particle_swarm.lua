require "overworld.coin_particle"
require "overworld.objects.coin"
require "common.matrix"

--- @class mn.CoinParticleSwarm
mn.CoinParticleSwarm = meta.class("CoinParticleSwarm")

local _round = function(x)
    return math.floor(x * 10e6) / 10e6
end

-- =================
-- Local Math Helpers
-- =================
local function dot(ax, ay, bx, by)
    return ax * bx + ay * by
end

local function sub(ax, ay, bx, by)
    return ax - bx, ay - by
end

local function add(ax, ay, bx, by)
    return ax + bx, ay + by
end

local function mul(ax, ay, s)
    return ax * s, ay * s
end

local function len(x, y)
    return math.magnitude(x, y)
end

local function normalize(x, y)
    local mx = math.magnitude(x, y)
    if mx > math.eps then
        return x / mx, y / mx, mx
    else
        return 0, 0, 0
    end
end

local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

-- =======================
-- XPBD Constraint Registry
-- =======================
local function ensure_xpbd_state(self)
    self._xpbd = self._xpbd or {
        lambda_pair = {},
        lambda_player = {},
        lambda_velocity = {}, -- NEW
    }
    return self._xpbd
end

local function velocity_key(i)
    return "V:" .. tostring(i)
end

local function pair_key(i, j)
    if i < j then
        return tostring(i) .. ":" .. tostring(j)
    else
        return tostring(j) .. ":" .. tostring(i)
    end
end

local function player_key(i)
    return "P:" .. tostring(i)
end

-- =======================
-- Broad-phase (grid hash)
-- =======================
local function hash_index(x, y, inv_cell)
    local cx = math.floor(x * inv_cell)
    local cy = math.floor(y * inv_cell)
    return cx, cy, tostring(cx) .. ":" .. tostring(cy)
end

local function build_grid(particles, cell_size)
    local inv_cell = 1.0 / cell_size
    local grid = {}
    local coords = {}
    for i = 1, #particles do
        local p = particles[i]
        local cx, cy, key = hash_index(p.x, p.y, inv_cell)
        coords[i] = { cx, cy }
        local bucket = grid[key]
        if bucket == nil then
            bucket = {}
            grid[key] = bucket
        end
        bucket[#bucket + 1] = i
    end
    return grid, coords, inv_cell
end

-- =====================
-- Broad-phase using self._spatial_hash
-- =====================
local function gather_neighbors_spatial(self, i)
    local particles = self._particles
    local p = particles[i]
    if not p then return {} end

    local r = self._spatial_hash_cell_size
    local cx = math.floor(p.x / r)
    local cy = math.floor(p.y / r)

    local neighbors = {}
    local n = 1

    for oy = -1, 1 do
        for ox = -1, 1 do
            local bucket = self._spatial_hash:get(cx + ox, cy + oy)
            if bucket then
                for _, other in ipairs(bucket) do
                    if other ~= p then
                        -- resolve particle index (pointer → index)
                        local j = other._index
                        if j then
                            neighbors[n] = j
                            n = n + 1
                        end
                    end
                end
            end
        end
    end

    return neighbors
end


-- =====================
-- Core XPBD Solve Steps
-- =====================
local function solve_distance_constraint_xpbd(
    particle_i,
    particle_j,
    inverse_mass_i,
    inverse_mass_j,
    rest_distance,
    compliance_alpha,
    delta_time,
    lambda_accumulator_table,
    constraint_lookup_key
)
    -- Calculate vector from particle j to particle i
    local delta_x, delta_y = math.subtract2(particle_i.x, particle_i.y, particle_j.x, particle_j.y)

    -- Normalize to get direction and current distance
    local direction_x, direction_y, current_distance = normalize(delta_x, delta_y)

    -- Handle degenerate case where particles are at same position
    if current_distance <= 1e-8 then
        direction_x, direction_y = 1.0, 0.0
        current_distance = 0.0
    end

    -- Calculate constraint violation (negative = overlapping, positive = separated enough)
    local constraint_violation = current_distance - rest_distance

    -- If particles are already separated enough, decay the stored lambda and exit early
    if constraint_violation >= 0 then
        local previous_lambda = lambda_accumulator_table[constraint_lookup_key]
        if previous_lambda then
            lambda_accumulator_table[constraint_lookup_key] = previous_lambda * 0.9
        end
        return
    end

    -- Calculate compliance term (makes constraint soft/elastic)
    local compliance_scaled = compliance_alpha / (delta_time * delta_time)

    -- Calculate denominator for constraint solve
    local constraint_denominator = inverse_mass_i + inverse_mass_j + compliance_scaled
    if constraint_denominator <= 0 then return end

    -- Retrieve accumulated lambda from previous frames (or 0 if first time)
    local lambda_previous_frame = lambda_accumulator_table[constraint_lookup_key] or 0.0

    -- Calculate this frame's lambda correction
    local delta_lambda = (-constraint_violation - compliance_scaled * lambda_previous_frame) / constraint_denominator

    -- Calculate position correction vector
    local correction_x, correction_y = math.multiply2(direction_x, direction_y, delta_lambda)

    -- Apply correction to particle i (if it's movable)
    if inverse_mass_i > 0 then
        particle_i.x, particle_i.y = math.add2(
            particle_i.x, particle_i.y,
            math.multiply2(correction_x, correction_y, inverse_mass_i)
        )
    end

    -- Apply opposite correction to particle j (if it's movable)
    if inverse_mass_j > 0 then
        particle_j.x, particle_j.y = math.add2(
            particle_j.x, particle_j.y,
            math.multiply2(-correction_x, -correction_y, inverse_mass_j)
        )
    end

    -- Store accumulated lambda for next frame
    lambda_accumulator_table[constraint_lookup_key] = lambda_previous_frame + delta_lambda
end

-- ================================
-- Velocity Direction "Soft" Constraint
-- ================================
local function apply_velocity_direction_constraint(
    particle,
    target_position_x,
    target_position_y,
    alignment_strength_gain,
    delta_time
)
    -- Exit early if no alignment should occur
    if alignment_strength_gain <= 0 then return end

    -- Calculate vector from particle to target
    local vector_to_target_x, vector_to_target_y = math.subtract(
        target_position_x, target_position_y,
        particle.x, particle.y
    )

    -- Normalize to get direction and distance
    local direction_to_target_x, direction_to_target_y, distance_to_target = normalize(
        vector_to_target_x, vector_to_target_y
    )

    -- Exit if particle is already at target
    if distance_to_target <= 1e-10 then return end

    -- Get current velocity
    local velocity_x = particle.velocity_x or 0.0
    local velocity_y = particle.velocity_y or 0.0

    -- Calculate velocity component parallel to target direction (forward speed)
    local velocity_parallel_magnitude = math.dot(
        velocity_x, velocity_y,
        direction_to_target_x, direction_to_target_y
    )

    -- Convert parallel magnitude back to vector
    local velocity_parallel_x, velocity_parallel_y = math.multiply2(
        direction_to_target_x, direction_to_target_y,
        velocity_parallel_magnitude
    )

    -- Calculate velocity component perpendicular to target direction (sideways drift)
    local velocity_perpendicular_x, velocity_perpendicular_y = math.subtract2(
        velocity_x, velocity_y,
        velocity_parallel_x, velocity_parallel_y
    )

    -- Calculate damping factor (clamped to prevent overshoot)
    local perpendicular_damping_factor = math.clamp(alignment_strength_gain * delta_time, 0.0, 1.0)

    -- Preserve only forward motion (remove backward motion)
    if velocity_parallel_magnitude < 0 then
        velocity_parallel_magnitude = 0
    end

    -- Reconstruct aligned forward velocity
    local velocity_aligned_forward_x, velocity_aligned_forward_y = math.multiply2(
        direction_to_target_x, direction_to_target_y,
        velocity_parallel_magnitude
    )

    -- Blend: keep aligned forward velocity, gradually reduce perpendicular drift
    local new_velocity_x = velocity_aligned_forward_x + (1.0 - perpendicular_damping_factor) * velocity_perpendicular_x
    local new_velocity_y = velocity_aligned_forward_y + (1.0 - perpendicular_damping_factor) * velocity_perpendicular_y

    -- Update particle velocity
    particle.velocity_x, particle.velocity_y = new_velocity_x, new_velocity_y
end

-- ==========================
-- XPBD Velocity Alignment Constraint
-- ==========================
local function solve_velocity_alignment_xpbd(
    particle,
    player_vx,
    player_vy,
    inverse_mass_particle,
    compliance_alpha,
    delta_time,
    lambda_table,
    key
)
    if inverse_mass_particle <= 0 then return end

    local compliance_scaled = compliance_alpha / (delta_time * delta_time)

    -- Initialize lambda storage
    local lambda = lambda_table[key]
    if lambda == nil then
        lambda = { x = 0.0, y = 0.0 }
        lambda_table[key] = lambda
    end

    -- Constraint violation
    local cx = particle.velocity_x - player_vx
    local cy = particle.velocity_y - player_vy

    -- Denominator
    local denom = inverse_mass_particle + compliance_scaled
    if denom <= 0 then return end

    -- XPBD delta lambda (per axis)
    local dlx = (-cx - compliance_scaled * lambda.x) / denom
    local dly = (-cy - compliance_scaled * lambda.y) / denom

    -- Apply velocity correction
    particle.velocity_x = particle.velocity_x + inverse_mass_particle * dlx
    particle.velocity_y = particle.velocity_y + inverse_mass_particle * dly

    -- Accumulate
    lambda.x = lambda.x + dlx
    lambda.y = lambda.y + dly
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
            self._target_x + rt.random.number(-0.5 * w, 0.5 * w),
            self._target_y + rt.random.number(-0.5 * h, 0.5 * h),
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

-- ==========================
-- Main XPBD Update
-- ==========================
function mn.CoinParticleSwarm:update(delta)
    local particles = self._particles
    if not particles or #particles == 0 then return end

    -- Tunables
    local follow_force = 1000.0
    local velocity_alignment_gain = 6.0
    local separation_radius_factor = 1.0
    local damping = 1.5
    local solver_iterations = 6
    local nonoverlap_compliance = 1e-7
    local velocity_match_compliance = 1 - 0.8

    -- Player
    local player_x, player_y = 0, 0--self._target_x, self._target_y
    local player_vx, player_vy = self._target_velocity_x, self._target_velocity_y
    local player_r = rt.settings.player.radius
    local radius = rt.settings.overworld.coin.radius

    -- Assign stable indices for broad-phase
    for i = 1, #particles do
        particles[i]._index = i
    end

    -- 1) External guidance
    for i = 1, #particles do
        local p = particles[i]
        local to_px, to_py = sub(player_x, player_y, p.x, p.y)
        local nx, ny = normalize(to_px, to_py)

        local ax, ay = mul(nx, ny, follow_force)
        p.velocity_x = (p.velocity_x or 0.0) + ax * delta
        p.velocity_y = (p.velocity_y or 0.0) + ay * delta
    end

    -- 2) Predict positions
    for i = 1, #particles do
        local p = particles[i]
        p._px = p.x + (p.velocity_x or 0.0) * delta
        p._py = p.y + (p.velocity_y or 0.0) * delta
    end

    -- Rebuild spatial hash from predicted positions
    self._spatial_hash:clear()
    local cell_size = self._spatial_hash_cell_size

    for i = 1, #particles do
        local p = particles[i]
        local cx = math.floor(p._px / cell_size)
        local cy = math.floor(p._py / cell_size)

        local bucket = self._spatial_hash:get(cx, cy)
        if not bucket then
            bucket = {}
            self._spatial_hash:set(cx, cy, bucket)
        end
        bucket[#bucket + 1] = p
    end

    local xpbd_state = ensure_xpbd_state(self)

    -- 3) XPBD position solve
    for iter = 1, solver_iterations do
        -- Particle–particle
        for i = 1, #particles do
            local pi = particles[i]
            local tmp_pi = { x = pi._px, y = pi._py }

            local neighbors = gather_neighbors_spatial(self, i)
            for _, j in ipairs(neighbors) do
                if j > i then
                    local pj = particles[j]
                    local tmp_pj = { x = pj._px, y = pj._py }

                    local rest = separation_radius_factor * (radius + radius)
                    local key = pair_key(i, j)

                    solve_distance_constraint_xpbd(
                        tmp_pi, tmp_pj,
                        1.0, 1.0,
                        rest,
                        nonoverlap_compliance,
                        delta,
                        xpbd_state.lambda_pair,
                        key
                    )

                    pi._px, pi._py = tmp_pi.x, tmp_pi.y
                    pj._px, pj._py = tmp_pj.x, tmp_pj.y
                end
            end
        end

        -- Particle–player
        for i = 1, #particles do
            local pi = particles[i]
            local tmp_pi = { x = pi._px, y = pi._py }

            local rest = separation_radius_factor * (radius + player_r)
            local key = player_key(i)

            solve_distance_constraint_xpbd(
                tmp_pi,
                { x = player_x, y = player_y },
                1.0, 0.0,
                rest,
                nonoverlap_compliance,
                delta,
                xpbd_state.lambda_player,
                key
            )

            pi._px, pi._py = tmp_pi.x, tmp_pi.y
        end
    end

    -- 4) Velocity update
    local damping_factor = math.exp(-damping * delta)
    for i = 1, #particles do
        local p = particles[i]
        local vx = (p._px - p.x) / delta
        local vy = (p._py - p.y) / delta

        p.velocity_x = vx * damping_factor
        p.velocity_y = vy * damping_factor
    end

    -- 4.5) Velocity XPBD alignment
    for i = 1, #particles do
        solve_velocity_alignment_xpbd(
            particles[i],
            player_vx, player_vy,
            1.0,
            velocity_match_compliance,
            delta,
            xpbd_state.lambda_velocity,
            "V:" .. i
        )
    end

    -- 5) Soft directional constraint
    for i = 1, #particles do
        apply_velocity_direction_constraint(
            particles[i],
            player_x, player_y,
            velocity_alignment_gain,
            delta
        )
    end

    -- 6) Commit
    for i = 1, #particles do
        local p = particles[i]
        p.x, p.y = p._px, p._py
        p._px, p._py = nil, nil
    end
end



--- @brief
function mn.CoinParticleSwarm:draw()
    local scale = 1 / self._canvas_scale
    local native = self._texture_atlas:get_native()
    love.graphics.setColor(1, 1, 1, 1)
    for particle in values(self._particles) do
        local _, _, w, h = particle.quad:getViewport()
        dbg(math.distance(particle.x, particle.y, self._target_x, self._target_y))
        love.graphics.draw(
            native, particle.quad,
            particle.x + self._target_x, particle.y + self._target_y,
        --particle.x, particle.y,
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