rt.settings.overworld.swing_tether = {
    default_range = 200,
    n_sub_steps = 3,
    n_constraint_iterations = 4,
    compliance = 0.0001,
    bend_compliance = 0.001,
    damping = 0.998,
    gravity = 100,
    n_rope_segments = 20, -- Number of constraint segments
    rope_node_mass = 0.5  -- Mass for intermediate simulated rope nodes
}

--- @class ow.SwingTether
ow.SwingTether = meta.class("SwingTether", ow.MovableObject)

--- @brief
function ow.SwingTether:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.POINT, "In ow.SwingTether: object `", object:get_id(), "` is not a point")

    self._scene = scene

    self._body = b2.Body(
        stage:get_physics_world(),
        object:get_physics_body_type(),
        object.x, object.y,
        b2.Circle(0, 0, 2)
    )

    self._range = object:get_number("range") or rt.settings.overworld.swing_tether.default_range

    self._other = nil
    self._tether = ow.Tether()

    self._rope_pos = {}
    self._rope_vel = {}
    self._rope_prev_pos = {}
    self._lambdas = {}
    self._bend_lambdas = {}
    self._segment_length = 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP then
            local player = self._scene:get_player()
            local px, py = player:get_position()
            local tx, ty = self._body:get_position()
            local dist = self._range

            if not player:get_is_grounded() and dist <= self._range then
                self._is_active = true

                local vx, vy = player:get_velocity()
                self._other = {
                    position_x = px,
                    position_y = py,
                    velocity_x = vx,
                    velocity_y = vy,
                    mass = player:get_mass(),
                    radius = player:get_radius()
                }

                -- Initialize the inline array of flat numbers for rope nodes
                local N = rt.settings.overworld.swing_tether.n_rope_segments
                self._segment_length = self._range / N

                self._rope_pos = {}
                self._rope_vel = {}
                self._rope_prev_pos = {}
                self._lambdas = {}
                self._bend_lambdas = {}

                -- We spawn N-1 intermediate rope nodes between tether and player
                for i = 1, N - 1 do
                    local t = i / N
                    local idx_x = i * 2 - 1
                    local idx_y = i * 2

                    self._rope_pos[idx_x] = tx + (px - tx) * t
                    self._rope_pos[idx_y] = ty + (py - ty) * t

                    -- Interpolate velocity for initial realistic swing momentum
                    self._rope_vel[idx_x] = vx * t
                    self._rope_vel[idx_y] = vy * t
                end

                for i = 1, N do
                    self._lambdas[i] = 0
                    self._bend_lambdas[i] = 0
                end
            end
        end
    end)
end

local _enforce_rope_constraint = function(
    p1x, p1y, p1_inverse_mass,
    p2x, p2y, p2_inverse_mass,
    target_distance,
    old_lambda,
    alpha
)
    local delta_x = p2x - p1x
    local delta_y = p2y - p1y

    local distance = math.max(math.magnitude(delta_x, delta_y), math.eps)
    local constraint = distance - target_distance

    -- Unilateral constraint: ropes don't resist compression
    if constraint <= 0 then
        return 0, 0, 0, 0, 0
    end

    local normal_x = delta_x / distance
    local normal_y = delta_y / distance
    local combined_inverse_mass = p1_inverse_mass + p2_inverse_mass

    local delta_lambda = (-constraint - alpha * old_lambda) / (combined_inverse_mass + alpha)
    local impulse_x = delta_lambda * normal_x
    local impulse_y = delta_lambda * normal_y

    return
    -p1_inverse_mass * impulse_x,
    -p1_inverse_mass * impulse_y,
    p2_inverse_mass * impulse_x,
    p2_inverse_mass * impulse_y,
    old_lambda + delta_lambda
end

function ow.SwingTether:update(delta)
    if not self._is_active or self._other == nil then return end

    local settings = rt.settings.overworld.swing_tether
    local gravity = settings.gravity

    local player = self._other

    local substep_delta = delta / settings.n_sub_steps
    local alpha = settings.compliance / (substep_delta * substep_delta)
    local bend_alpha = settings.bend_compliance / (substep_delta * substep_delta)

    local self_inverse_mass = 0
    local self_x, self_y = self._body:get_position()

    local player_x, player_y = player.position_x, player.position_y
    local player_velocity_x, player_velocity_y = player.velocity_x, player.velocity_y
    local player_inverse_mass = 1 / player.mass

    local N = settings.n_rope_segments
    local M = N - 1
    local node_inverse_mass = 1 / settings.rope_node_mass

    local pos = self._rope_pos
    local vel = self._rope_vel
    local prev_pos = self._rope_prev_pos

    for _ = 1, settings.n_sub_steps do
        -- 1. Apply external forces and integrate positions
        player_velocity_x = player_velocity_x * settings.damping
        player_velocity_y = player_velocity_y * settings.damping + gravity * substep_delta

        local player_previous_x, player_previous_y = player_x, player_y
        player_x = player_x + player_velocity_x * substep_delta
        player_y = player_y + player_velocity_y * substep_delta

        for i = 1, M do
            local idx_x = i * 2 - 1
            local idx_y = i * 2

            vel[idx_x] = vel[idx_x] * settings.damping
            vel[idx_y] = vel[idx_y] * settings.damping + gravity * substep_delta

            prev_pos[idx_x] = pos[idx_x]
            prev_pos[idx_y] = pos[idx_y]

            pos[idx_x] = pos[idx_x] + vel[idx_x] * substep_delta
            pos[idx_y] = pos[idx_y] + vel[idx_y] * substep_delta
        end

        -- Reset lambdas for this substep iteration
        for i = 1, N do
            self._lambdas[i] = 0
            self._bend_lambdas[i] = 0
        end

        -- 2. Solve Distance Constraints
        for __ = 1, settings.n_constraint_iterations do
            for i = 1, N do
                local p1x, p1y, w1
                if i == 1 then
                    p1x, p1y = self_x, self_y
                    w1 = 0
                else
                    local node_idx = i - 1
                    p1x = pos[node_idx * 2 - 1]
                    p1y = pos[node_idx * 2]
                    w1 = node_inverse_mass
                end

                local p2x, p2y, w2
                if i == N then
                    p2x, p2y = player_x, player_y
                    w2 = player_inverse_mass
                else
                    local node_idx = i
                    p2x = pos[node_idx * 2 - 1]
                    p2y = pos[node_idx * 2]
                    w2 = node_inverse_mass
                end

                local corr1x, corr1y, corr2x, corr2y, new_lambda = _enforce_rope_constraint(
                    p1x, p1y, w1,
                    p2x, p2y, w2,
                    self._segment_length,
                    self._lambdas[i],
                    alpha
                )

                self._lambdas[i] = new_lambda

                -- Apply Constraint Corrections
                if i ~= 1 then
                    local node_idx = i - 1
                    pos[node_idx * 2 - 1] = pos[node_idx * 2 - 1] + corr1x
                    pos[node_idx * 2] = pos[node_idx * 2] + corr1y
                end

                if i == N then
                    player_x = player_x + corr2x
                    player_y = player_y + corr2y
                else
                    local node_idx = i
                    pos[node_idx * 2 - 1] = pos[node_idx * 2 - 1] + corr2x
                    pos[node_idx * 2] = pos[node_idx * 2] + corr2y
                end
            end

            for i = 1, N - 1 do
                local ax, ay, inverse_mass_a
                if i == 1 then
                    ax, ay = self_x, self_y
                    inverse_mass_a = 0
                else
                    ax = pos[(i - 1) * 2 - 1]
                    ay = pos[(i - 1) * 2]
                    inverse_mass_a = node_inverse_mass
                end

                local bx, by, inverse_mass_b
                if i == N - 1 then
                    bx, by = player_x, player_y
                    inverse_mass_b = player_inverse_mass
                else
                    bx = pos[i * 2 - 1]
                    by = pos[i * 2]
                    inverse_mass_b = node_inverse_mass
                end

                local cx, cy, inverse_mass_c
                if i + 1 == N then
                    cx, cy = player_x, player_y
                    inverse_mass_c = player_inverse_mass
                else
                    cx = pos[(i + 1) * 2 - 1]
                    cy = pos[(i + 1) * 2]
                    inverse_mass_c = node_inverse_mass
                end

                local t_x = cx - ax
                local t_y = cy - ay
                local t_len = math.magnitude(t_x, t_y)
                if t_len >= math.eps then
                    t_x, t_y = math.normalize(t_x, t_y)
                    local normal_x = -t_y
                    local normal_y =  t_x
                    local midpoint_x = 0.5 * (ax + cx)
                    local midpoint_y = 0.5 * (ay + cy)
                    local constraint = (midpoint_x - bx) * normal_x + (midpoint_y - by) * normal_y
                    local weight_sum =
                    inverse_mass_a * 0.25 +
                        inverse_mass_b * 1.0 +
                        inverse_mass_c * 0.25
                    local delta_lambda = -(constraint + bend_alpha * self._bend_lambdas[i]) / (weight_sum + bend_alpha)
                    self._bend_lambdas[i] = self._bend_lambdas[i] + delta_lambda

                    local corr_ax = inverse_mass_a * delta_lambda *  0.5 * normal_x
                    local corr_ay = inverse_mass_a * delta_lambda *  0.5 * normal_y
                    local corr_bx = inverse_mass_b * delta_lambda * -1.0 * normal_x
                    local corr_by = inverse_mass_b * delta_lambda * -1.0 * normal_y
                    local corr_cx = inverse_mass_c * delta_lambda *  0.5 * normal_x
                    local corr_cy = inverse_mass_c * delta_lambda *  0.5 * normal_y

                    if i == 1 then
                        -- anchor is static, no correction
                    else
                        pos[(i - 1) * 2 - 1] = pos[(i - 1) * 2 - 1] + corr_ax
                        pos[(i - 1) * 2]     = pos[(i - 1) * 2]     + corr_ay
                    end

                    if i == N - 1 then
                        player_x = player_x + corr_bx
                        player_y = player_y + corr_by
                    else
                        pos[i * 2 - 1] = pos[i * 2 - 1] + corr_bx
                        pos[i * 2]     = pos[i * 2]     + corr_by
                    end

                    if i + 1 == N then
                        player_x = player_x + corr_cx
                        player_y = player_y + corr_cy
                    else
                        pos[(i + 1) * 2 - 1] = pos[(i + 1) * 2 - 1] + corr_cx
                        pos[(i + 1) * 2]     = pos[(i + 1) * 2]     + corr_cy
                    end
                end
            end
        end

        -- 3. Derive Velocities
        player_velocity_x = (player_x - player_previous_x) / substep_delta
        player_velocity_y = (player_y - player_previous_y) / substep_delta

        for i = 1, M do
            local idx_x = i * 2 - 1
            local idx_y = i * 2
            vel[idx_x] = (pos[idx_x] - prev_pos[idx_x]) / substep_delta
            vel[idx_y] = (pos[idx_y] - prev_pos[idx_y]) / substep_delta
        end
    end

    -- Write states back to our caching mechanism
    player.position_x = player_x
    player.position_y = player_y
    player.velocity_x = player_velocity_x
    player.velocity_y = player_velocity_y
end

--- @brief
function ow.SwingTether:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._body:draw()

    love.graphics.setLineWidth(1)
    local x, y = self._body:get_position()
    love.graphics.circle("line", x, y, self._range)

    if self._is_active then
        local pos = self._rope_pos
        local N = rt.settings.overworld.swing_tether.n_rope_segments
        local prev_x, prev_y = x, y

        -- Draw the intermediate segments and rope node circles
        for i = 1, N - 1 do
            local curr_x = pos[i * 2 - 1]
            local curr_y = pos[i * 2]

            love.graphics.line(prev_x, prev_y, curr_x, curr_y)
            love.graphics.circle("fill", curr_x, curr_y, 2)

            prev_x, prev_y = curr_x, curr_y
        end

        -- Draw connection to the player
        love.graphics.line(prev_x, prev_y, self._other.position_x, self._other.position_y)

        -- Draw the player
        love.graphics.circle("line",
            self._other.position_x,
            self._other.position_y,
            self._other.radius
        )
    end
end