rt.settings.overworld.decelerator_body = {
    n_arms = 16,
    arm_radius = 10,
    arm_length = 32,
    arm_n_segments = 32,
    extend_velocity_factor = 1 / 200,

    min_radius = 1,
    max_radius = 2,
    min_mass = 1,
    max_mass = 1,

    n_sub_steps = 2,
    n_constraint_iterations = 2,
    damping = 1 - 0.2,

    distance_compliance = 0.0,
    bending_compliance = 0.0001,
    retract_compliance = 0.0025,
    extend_compliance = 0.00025,
    collision_compliance = 0.0001
}

--- @class ow.DeceleratorBody
ow.DeceleratorBody = meta.class("DeceleratorSurface")

--- @brief
function ow.DeceleratorBody:instantiate(contour)
    self._target_x, self._target_y = math.huge, math.huge
    self._target_radius, self._target_t = 0, 0
    self._is_active = false

    self._contour = contour
    self:_initialize()
end

local _x_offset = 0
local _y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _previous_x_offset = 4
local _previous_y_offset = 5
local _radius_offset = 6
local _mass_offset = 7
local _inverse_mass_offset = 8
local _distance_lambda_offset = 9
local _bending_lambda_offset = 10
local _collision_lambda_offset = 11
local _target_lambda_offset = 12

local _stride = _target_lambda_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end

local _extend, _retract = true, false

--- @brief
function ow.DeceleratorBody:_initialize()
    local settings = rt.settings.overworld.decelerator_body

    self._path = rt.Path()
    self._path:create_from_and_resample(rt.contour.close(self._contour))

    self._data = {} -- Table<Number>, properties inline
    self._n_particles = 0
    self._arms = {} -- Table<Table<ParticleIndex>>

    local add_particle = function(x, y, mass, radius)
        local i = #self._data + 1
        self._data[i + _x_offset] = x
        self._data[i + _y_offset] = y
        self._data[i + _velocity_x_offset] = 0
        self._data[i + _velocity_y_offset] = 0
        self._data[i + _previous_x_offset] = x
        self._data[i + _previous_y_offset] = y
        self._data[i + _radius_offset] = radius
        self._data[i + _mass_offset] = mass
        self._data[i + _inverse_mass_offset] = 1 / mass
        self._data[i + _distance_lambda_offset] = 0
        self._data[i + _bending_lambda_offset] = 0
        self._data[i + _collision_lambda_offset] = 0
        self._data[i + _target_lambda_offset] = 0

        assert(#self._data - i == _stride - 1)
    end

    local mass_easing = function(i, n)
        return 1
    end

    local radius_easing = function(i, n)
        return 1
    end

    local arm_length_easing = function(i, n)
        return 1
    end

    local start_x, start_y = self._path:at(0)
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius

    local n_arms = settings.n_arms
    if n_arms % 2 == 0 then n_arms = n_arms + 1 end

    local particle_i = 1
    for arm_i = 1, n_arms do
        local arm_length = settings.arm_length * arm_length_easing(arm_i, n_arms)
        local n_segments = settings.arm_n_segments

        local start_i = particle_i
        for segment_i = 1, n_segments do
            add_particle(
                start_x, start_y,
                math.mix(min_mass, max_mass, mass_easing(segment_i, n_segments)),
                math.mix(min_radius, max_radius, radius_easing(segment_i, n_segments))
            )

            particle_i = particle_i + 1
        end

        table.insert(self._arms, {
            start_i = start_i,
            end_i = particle_i - 1,
            anchor_x = start_x,
            anchor_y = start_y,
            anchor_lambda = 0,

            target_x = start_x,
            target_y = start_y,
            target_lambda = 0,

            n_segments = n_segments,
            motion = rt.SmoothedMotion1D(0, settings.extend_velocity_factor),
            length = settings.arm_length,
            segment_length = settings.arm_length / n_segments,

            slot_i = nil,
            extend_or_retract = _retract
        })
    end

    self._n_particles = particle_i - 1

    -- initialize t offsets, symmetric around midpoint arm
    local num_slots = math.floor(self._path:get_length() / settings.arm_radius)
    local t_step = 1 / num_slots

    self._arm_slot_t_step = t_step
    self._slots = {} -- static slots
    self._free_arms = {} -- indices of arms

    local n_arms_left = n_arms
    for i = 1, num_slots do
        local t = (i - 1) * t_step
        local anchor_x, anchor_y = self._path:at(t)

        local arm_slot = {
            arm_i = nil,
            anchor_x = anchor_x,
            anchor_y = anchor_y,
            target_x = anchor_x,
            target_y = anchor_y,
            t = t
        }

        self._slots[i] = arm_slot

        if n_arms_left > 0 then
            self._free_arms[n_arms_left] = true
            n_arms_left = n_arms_left - 1
        end
    end
end

--- @brief
function ow.DeceleratorBody:set_target(x, y, radius)
    self._is_active = true
    self._target_x, self._target_y, self._target_radius = x, y, radius
    local _, _, closest_t = self._path:get_closest_point(x, y)
    self._target_t = closest_t
end

--- @brief
function ow.DeceleratorBody:_add_to_slot(slot_i, arm_i)
    local slot = self._slots[slot_i]
    if slot.arm_i ~= nil then
        self._remove_from_slot(slot_i)
    end

    slot.arm_i = arm_i

    local arm = self._arms[arm_i]
    arm.slot_i = slot_i

    self._free_arms[arm_i] = nil

    arm.anchor_x = slot.anchor_x
    arm.anchor_y = slot.anchor_y
    arm.target_x = slot.anchor_x
    arm.target_y = slot.anchor_y

    local data = self._data
    for particle_i = arm.start_i, arm.end_i do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _x_offset] = arm.anchor_x
        data[i + _y_offset] = arm.anchor_y
    end
end

--- @brief
function ow.DeceleratorBody:_remove_from_slot(slot_i)
    local slot = self._slots[slot_i]
    if slot.arm_i == nil then return end

    local arm_i = slot.arm_i

    slot.arm_i = nil
    local arm = self._arms[arm_i]
    arm.slot_i = nil

    self._free_arms[arm_i] = true
end

--- @brief
function ow.DeceleratorBody:update(delta)
    if not self._is_active then return end
    local n_slots, n_arms = #self._slots, #self._arms

    -- get anchor point
    local final_x, final_y = self._path:at(self._target_t)

    -- vector from center to target
    local dx, dy = math.subtract(self._target_x, self._target_y, final_x, final_y)

    -- get angle, line along dx, dy bisects the circle
    local angle = math.angle(dx, dy)

    -- get closest slot
    local mid_t = self._target_t
    local right_t = self._target_t + math.floor(0.5 * n_arms) * self._arm_slot_t_step
    local left_t = self._target_t - math.ceil(0.5 * n_arms) * self._arm_slot_t_step

    local function is_in_interval(value, left, right)
        value = math.fract(value)
        left = math.fract(left)
        right = math.fract(right)

        if left <= right then
            return value >= left and value <= right
        else
            return value >= left or value <= right
        end
    end

    local range = math.pi
    local mid_point = math.pi + math.angle(dx, dy)

    for slot_i = 1, n_slots do
        local slot = self._slots[slot_i]
        local slot_t = slot.t

        if not is_in_interval(slot_t, left_t, right_t) then
            slot.target_x = slot.anchor_x
            slot.target_y = slot.anchor_y
        else
            local attachment_angle = math.mix(
                mid_point - 0.5 * math.pi,
                mid_point + 0.5 * math.pi,
                (slot_t - left_t) / (right_t - left_t)
            )

            -- closest point on circle
            slot.target_x = self._target_x + math.cos(attachment_angle) * self._target_radius
            slot.target_y = self._target_y + math.sin(attachment_angle) * self._target_radius

            if slot.arm_i == nil then
                local next_arm_i = select(1, next(self._free_arms))
                if next_arm_i ~= nil then
                    self:_add_to_slot(slot_i, next_arm_i)
                end
            end
        end

        if slot.arm_i ~= nil then
            local arm = self._arms[slot.arm_i]
            arm.anchor_x = slot.anchor_x
            arm.anchor_y = slot.anchor_y
            arm.target_x = slot.target_x
            arm.target_y = slot.target_y
        end
    end

    for arm in values(self._arms) do
        arm.extend_or_retract = ternary(math.distance(
            arm.anchor_x, arm.anchor_y,
            arm.target_x, arm.target_y
        ) >= arm.length, _extend, _retract)
    end

    self:_step(delta)
end

do -- step helpers
    local function _pre_solve(
        position_x, position_y,
        velocity_x, velocity_y,
        mass,
        damping, delta
    )
        -- store previous world positions for velocity update in post-solve
        local previous_x = position_x
        local previous_y = position_y

        -- world velocity from previous step
        local new_velocity_x = velocity_x * damping
        local new_velocity_y = velocity_y * damping

        -- predict positions in world space (advected by frame)
        local position_new_x = position_x + new_velocity_x * delta
        local position_new_y = position_y + new_velocity_y * delta

        return position_new_x, position_new_y,
        new_velocity_x, new_velocity_y,
        previous_x, previous_y
    end

    -- XPBD distance constraint between two particles (A,B)
    -- C = |b - a| - d0 = 0
    local function _enforce_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,         -- compliance (already scaled by sub_delta^2)
        lambda_before    -- accumulated lambda for this constraint
    )
        local delta_x = bx - ax
        local delta_y = by - ay
        local length = math.magnitude(delta_x, delta_y)
        if length < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        local constraint = length - target_distance
        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- x_i += w_i * d_lambda * gradC_i
        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x) -- grad_a = -n
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_bx = inverse_mass_b * delta_lambda * ( normal_x) -- grad_b = +n
        local correction_by = inverse_mass_b * delta_lambda * ( normal_y)

        return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
    end

    -- XPBD bending as end-to-end AC distance equals target (sum of adjacent segment lengths)
    -- C = |c - a| - target_ac = 0
    local function _enforce_bending(
        ax, ay, bx, by, cx, cy,
        inverse_mass_a, inverse_mass_b, inverse_mass_c,
        target_ac_distance,
        alpha,
        lambda_before
    )
        local delta_x = cx - ax
        local delta_y = cy - ay
        local length = math.magnitude(delta_x, delta_y)
        if length < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda_before
        end
        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        local constraint = length - target_ac_distance
        local weight_sum = inverse_mass_a + inverse_mass_c
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- a += w_a * dλ * (-n); c += w_c * dλ * (n)
        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x)
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_cx = inverse_mass_c * delta_lambda * ( normal_x)
        local correction_cy = inverse_mass_c * delta_lambda * ( normal_y)

        -- B gets no direct correction in this simplified bending constraint
        return correction_ax, correction_ay, 0.0, 0.0, correction_cx, correction_cy, lambda_new
    end

    -- XPBD distance constraint between a particle (A) and a fixed point (P)
    -- C = |a - p| - d0 = 0
    local function _enforce_anchor(
        ax, ay,               -- particle position
        px, py,               -- fixed point position
        inverse_mass_a,       -- only particle has mass
        alpha,                -- compliance (already scaled by sub_delta^2)
        lambda_before         -- accumulated lambda for this constraint
    )
        local delta_x = ax - px
        local delta_y = ay - py
        local length = math.magnitude(delta_x, delta_y)

        if length < math.eps then
            return 0, 0, lambda_before
        end

        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        local target_distance = 0
        local constraint = length - target_distance

        local weight_sum = inverse_mass_a
        local denominator = weight_sum + alpha

        if denominator < math.eps then
            return 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- grad_a = +n  (because C = |a - p|)
        local correction_ax = inverse_mass_a * delta_lambda * normal_x
        local correction_ay = inverse_mass_a * delta_lambda * normal_y

        return correction_ax, correction_ay, lambda_new
    end

    -- XPBD inequality constraint for sphere collision
    -- C = |x - c| - (r_player + r_particle) >= 0
    -- If C < 0 (penetration), we project out.
    local function _enforce_sphere_collision(
        ax, ay,               -- particle position
        cx, cy,               -- sphere center
        min_distance,         -- combined radius (player_r + particle_r)
        inverse_mass_a,       -- particle inverse mass
        alpha,                -- compliance
        lambda_before         -- accumulated lambda
    )
        local delta_x = ax - cx
        local delta_y = ay - cy
        local length = math.magnitude(delta_x, delta_y)

        -- If we are outside the sphere (length > min_distance), the constraint is satisfied.
        -- We return 0 correction and reset lambda to 0 (inactive constraint).
        if length >= min_distance or length < math.eps then
            return 0, 0, 0
        end

        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        -- The constraint value C is negative (depth of penetration)
        local constraint = length - min_distance

        local weight_sum = inverse_mass_a -- collider has infinite mass (w=0)
        local denominator = weight_sum + alpha

        if denominator < math.eps then
            return 0, 0, lambda_before
        end

        -- Calculate Lagrange multiplier update
        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- Gradient is the normal pointing OUT of the sphere (towards the particle)
        -- x += w * d_lambda * n
        local correction_x = inverse_mass_a * delta_lambda * normal_x
        local correction_y = inverse_mass_a * delta_lambda * normal_y

        return correction_x, correction_y, lambda_new
    end

    local function _post_solve(
        position_x, position_y,
        previous_x, previous_y,
        delta
    )
        local velocity_x = (position_x - previous_x) / delta
        local velocity_y = (position_y - previous_y) / delta

        return velocity_x, velocity_y
    end

    --- @brief
    function ow.DeceleratorBody:_step(delta)
        local settings = rt.settings.overworld.decelerator_body
        local sub_delta = delta / settings.n_sub_steps

        local damping = settings.damping
        local n_sub_steps = settings.n_sub_steps
        local n_constraint_iterations = settings.n_constraint_iterations
        local max_radius = settings.max_radius

        local distance_alpha = settings.distance_compliance / (sub_delta^2)
        local bending_alpha = settings.bending_compliance / (sub_delta^2)
        local extend_alpha = settings.extend_compliance / (sub_delta^2)
        local retract_alpha = settings.retract_compliance / (sub_delta^2)
        local collision_alpha = settings.collision_compliance / (sub_delta^2)

        local data = self._data

        local player_x, player_y, player_r = self._target_x, self._target_y, self._target_radius

        for _ = 1, n_sub_steps do
            -- pre solve
            for particle_i = 1, self._n_particles do
                local offset = _particle_i_to_data_offset(particle_i)
                local new_position_x, new_position_y,
                new_velocity_x, new_velocity_y,
                previous_x, previous_y
                = _pre_solve(
                    data[offset + _x_offset],
                    data[offset + _y_offset],
                    data[offset + _velocity_x_offset],
                    data[offset + _velocity_y_offset],
                    data[offset + _mass_offset],
                    damping, sub_delta
                )

                data[offset + _x_offset] = new_position_x
                data[offset + _y_offset] = new_position_y
                data[offset + _velocity_x_offset] = new_velocity_x
                data[offset + _velocity_y_offset] = new_velocity_y
                data[offset + _previous_x_offset] = previous_x
                data[offset + _previous_y_offset] = previous_y
                data[offset + _distance_lambda_offset] = 0
                data[offset + _bending_lambda_offset] = 0
                data[offset + _collision_lambda_offset] = 0
                data[offset + _target_lambda_offset] = 0
            end

            -- reset per-arm lambdas
            for arm in values(self._arms) do
                arm.anchor_lambda = 0
            end

            -- Gauss-Seidel style iterations over constraints
            for __ = 1, n_constraint_iterations do
                for arm in values(self._arms) do
                    if arm.slot_i == nil then goto next_arm end

                    -- segment distance constraints
                    for node_i = arm.start_i, arm.end_i - 1, 1 do
                        local a_i = _particle_i_to_data_offset(node_i + 0)
                        local b_i = _particle_i_to_data_offset(node_i + 1)

                        local ax, ay = data[a_i + _x_offset], data[a_i + _y_offset]
                        local bx, by = data[b_i + _x_offset], data[b_i + _y_offset]

                        local inverse_mass_a = data[a_i + _inverse_mass_offset]
                        local inverse_mass_b = data[b_i + _inverse_mass_offset]

                        local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_distance(
                            ax, ay, bx, by,
                            inverse_mass_a, inverse_mass_b,
                            arm.segment_length,
                            distance_alpha,
                            data[a_i + _distance_lambda_offset]
                        )

                        data[a_i + _x_offset] = ax + correction_ax
                        data[a_i + _y_offset] = ay + correction_ay
                        data[b_i + _x_offset] = bx + correction_bx
                        data[b_i + _y_offset] = by + correction_by
                        data[a_i + _distance_lambda_offset] = lambda_new
                    end

                    -- bending constraints (XPBD)
                    for node_i = arm.start_i, arm.end_i - 2, 1 do
                        local a_i = _particle_i_to_data_offset(node_i + 0)
                        local b_i = _particle_i_to_data_offset(node_i + 1)
                        local c_i = _particle_i_to_data_offset(node_i + 2)

                        local ax, ay = data[a_i + _x_offset], data[a_i + _y_offset]
                        local bx, by = data[b_i + _x_offset], data[b_i + _y_offset]
                        local particle_c_x, particle_c_y = data[c_i + _x_offset], data[c_i + _y_offset]

                        local inverse_mass_a = data[a_i + _inverse_mass_offset]
                        local inverse_mass_b = data[b_i + _inverse_mass_offset]
                        local inverse_mass_c = data[c_i + _inverse_mass_offset]

                        local segment_length_ab = arm.segment_length
                        local segment_length_bc = arm.segment_length
                        local target_length = segment_length_ab + segment_length_bc

                        local correction_ax, correction_ay, _, _, correction_cxx, correction_cxy, lambda_new = _enforce_bending(
                            ax, ay, bx, by, particle_c_x, particle_c_y,
                            inverse_mass_a, inverse_mass_b, inverse_mass_c,
                            target_length,
                            bending_alpha,
                            data[a_i + _bending_lambda_offset]
                        )

                        data[a_i + _x_offset] = ax + correction_ax
                        data[a_i + _y_offset] = ay + correction_ay
                        data[c_i + _x_offset] = particle_c_x + correction_cxx
                        data[c_i + _y_offset] = particle_c_y + correction_cxy
                        data[a_i + _bending_lambda_offset] = lambda_new
                    end

                    -- player collision
                    for node_i = arm.start_i, arm.end_i, 1 do
                        local i = _particle_i_to_data_offset(node_i)
                        local x, y = data[i + _x_offset], data[i + _y_offset]

                        -- If your particles have their own radius, add it to player_r here.
                        local min_dist = player_r

                        local correction_x, correction_y, lambda_new = _enforce_sphere_collision(
                            x, y,
                            player_x, player_y,
                            min_dist,
                            data[i + _inverse_mass_offset],
                            collision_alpha,
                            data[i + _collision_lambda_offset]
                        )

                        -- Apply position correction
                        data[i + _x_offset] = x + correction_x
                        data[i + _y_offset] = y + correction_y

                        -- Store updated lambda
                        data[i + _collision_lambda_offset] = lambda_new
                    end

                    -- pin anchor
                    do
                        local i = _particle_i_to_data_offset(arm.start_i)
                        data[i + _x_offset] = arm.anchor_x
                        data[i + _y_offset] = arm.anchor_y
                    end

                    local is_retracting = arm.extend_or_retract == _retract

                    local target_start_i, target_end_i, target_alpha
                    if not is_retracting then
                        target_start_i, target_end_i = arm.start_i + 1, arm.end_i
                        target_alpha = extend_alpha
                    else
                        target_start_i, target_end_i = arm.start_i + 1, arm.end_i
                        target_alpha = retract_alpha
                    end

                    -- end node target
                    local retraction_sum = 0
                    for node_i = target_start_i, target_end_i do
                        local i = _particle_i_to_data_offset(node_i)
                        local x, y = data[i + _x_offset], data[i + _y_offset]
                        local correction_x, correction_y, lambda_new = _enforce_anchor(
                            x, y,
                            arm.target_x, arm.target_y,
                            data[i + _inverse_mass_offset],
                            target_alpha,
                            data[i + _target_lambda_offset]
                        )

                        local new_x = x + correction_x
                        local new_y = y + correction_y
                        data[i + _x_offset] = new_x
                        data[i + _y_offset] = new_y
                        data[i + _target_lambda_offset] = lambda_new

                        if is_retracting then
                            retraction_sum = retraction_sum + math.distance(
                                new_x, new_y,
                                arm.target_x, arm.target_y
                            )
                        end
                    end

                    -- if retracting, check if fully done, then free and add to buffer
                    if is_retracting and (retraction_sum / (arm.n_segments - 1)) < max_radius then
                        self:_remove_from_slot(arm.slot_i)
                    end

                    ::next_arm::
                end
            end

            -- post solve
            for particle_i = 1, self._n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local new_velocity_x, new_velocity_y = _post_solve(
                    data[i + _x_offset],
                    data[i + _y_offset],
                    data[i + _previous_x_offset],
                    data[i + _previous_y_offset],
                    sub_delta
                )

                data[i + _velocity_x_offset] = new_velocity_x
                data[i + _velocity_y_offset] = new_velocity_y
            end
        end
    end
end

--- @brief
function ow.DeceleratorBody:draw()
    rt.Palette.WHITE:bind()
    love.graphics.line(self._path:get_points())

    love.graphics.setLineJoin("none")
    love.graphics.setLineStyle("smooth")

    local max_radius = rt.settings.overworld.decelerator_body.max_radius
    love.graphics.setLineWidth(max_radius)

    local data = self._data
    local arms = self._arms

    for _, arm in ipairs(arms) do
        local is_first = true
        for particle_i = arm.start_i, arm.end_i do
            local i = _particle_i_to_data_offset(particle_i)
            love.graphics.circle("fill",
                data[i + _x_offset],
                data[i + _y_offset],
                max_radius / 2
            )

            if is_first then
                love.graphics.circle("line",
                    data[i + _x_offset],
                    data[i + _y_offset],
                    max_radius
                )
                is_first = false
            end
        end
    end

    love.graphics.setPointSize(3)

    for _, arm in ipairs(arms) do
        for particle_i = arm.start_i, arm.end_i - 1 do
            local a_i = _particle_i_to_data_offset(particle_i + 0)
            local b_i = _particle_i_to_data_offset(particle_i + 1)

            love.graphics.line(
                data[a_i + _x_offset],
                data[a_i + _y_offset],
                data[b_i + _x_offset],
                data[b_i + _y_offset]
            )
        end
    end
end

--- @brief
function ow.DeceleratorBody:get_player_damping()
    local n_attached = 0
    for arm in values(self._arms) do
        if arm.is_attached then n_attached = n_attached + 1 end
    end

    return 1 - n_attached / #self._arms
end