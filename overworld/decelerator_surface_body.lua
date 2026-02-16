rt.settings.overworld.decelerator_body = {
    n_arms = 32,
    arm_radius = rt.settings.player.radius,
    arm_length = 64,
    arm_n_segments = 32,

    n_arms_for_full_force = 1,

    min_radius = 1,
    max_radius = 3,
    min_mass = 1,
    max_mass = 1,

    slot_min_scale = 1 / 3,
    slot_max_scale = 2,

    particle_texture_r = 20,
    texture_scale = 2,

    n_sub_steps = 2,
    n_constraint_iterations = 2,
    damping = 1 - 0.2,

    distance_compliance = 0.0,
    bending_compliance = 0.001,
    retract_compliance = 0.02,
    extend_compliance = 0.00075,
    collision_compliance = 0.0001,

    threshold = 0.5,
    smoothness = 0.05,
    outline_thickness = 1 / 4
}

rt.settings.overworld.decelerator_body.retract_threshold = rt.settings.overworld.decelerator_body.slot_max_scale * rt.settings.overworld.decelerator_body.max_radius

--- @class ow.DeceleratorSurfaceBody
ow.DeceleratorSurfaceBody = meta.class("DeceleratorSurfaceBody")

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

local _particle_texture_shader = rt.Shader("overworld/decelerator_surface_body_particle_texture.glsl") -- sic
local _threshold_shader = rt.Shader("overworld/decelerator_surface_body_threshold.glsl")
local _instance_draw_shader = rt.Shader("overworld/decelerator_surface_body_instanced_draw.glsl")

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then
        for s in range(_particle_texture_shader, _threshold_shader, _instance_draw_shader) do
            s:recompile()
        end
    end
end)

--- @brief
function ow.DeceleratorSurfaceBody:instantiate(scene, contour, mesh)
    self._scene = scene

    self._target_x, self._target_y = math.huge, math.huge
    self._offset_x, self._offset_y = 0, 0
    self._target_radius = 0
    self._is_active = false

    self._n_connected = 0

    local settings = rt.settings.overworld.decelerator_body
    self._particle_texture_radius = settings.particle_texture_r
    do -- init particle texture
        local w = (self._particle_texture_radius + 2) * 2
        local h = w
        self._particle_texture = rt.RenderTexture(w, h)

        love.graphics.push("all")
        love.graphics.reset()
        self._particle_texture:bind()
        _particle_texture_shader:bind()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill",
            0, 0, w, h
        )

        _particle_texture_shader:unbind()
        self._particle_texture:unbind()
        love.graphics.pop()
    end

    self._contour = contour
    self._mesh = mesh

    local arm_length = settings.arm_length
    self._arm_length = arm_length
    self._arm_length_extension = 0

    self._aabb = rt.contour.get_aabb(self._contour)

    local padding = arm_length + 5 -- safety
    self._aabb.x = self._aabb.x - padding
    self._aabb.y = self._aabb.y - padding
    self._aabb.width = self._aabb.width + 2 * padding
    self._aabb.height = self._aabb.height + 2 * padding

    self._canvas = rt.RenderTexture(
        self._aabb.width, self._aabb.height,
        rt.TextureFormat.RG16F
    )
    self._canvas_needs_update = true

    self._path = rt.Path()
    self._path:create_from_and_reparameterize(rt.contour.close(self._contour))

    self._data = {} -- Table<Number>, properties inline
    self._n_particles = 0

    self._arms = {}
    self._slots = {}
    self._free_arms = {} -- Set<ArmIndex>

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
        local t = (i - 1) / n
        return 1 - t
    end

    local start_x, start_y = self._path:at(0)
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius

    local n_arms = settings.n_arms
    local n_segments = settings.arm_n_segments

    local particle_i = 1
    for arm_i = 1, n_arms do
        local start_i = particle_i
        for segment_i = 1, n_segments do
            add_particle(
                start_x, start_y,
                math.mix(min_mass, max_mass, mass_easing(segment_i, n_segments)),
                math.max(1, math.mix(min_radius, max_radius, radius_easing(segment_i, n_segments)))
            )

            particle_i = particle_i + 1
        end

        table.insert(self._arms, {
            start_i = start_i,
            end_i = particle_i - 1,
            slot_i = nil,
            n_segments = n_segments,

            is_extending = false
        })
    end

    self._n_particles = particle_i - 1

    -- initialize t offsets, symmetric around midpoint arm
    local n_slots = math.floor(self._path:get_length() / settings.arm_radius)
    local n_arms_left = n_arms
    for i = 1, n_slots do
        local t = (i - 1) / n_slots
        local anchor_x, anchor_y = self._path:at(t)

        local normal_x, normal_y = self._path:get_normal_at(t)
        local arm_slot = {
            arm_i = nil,
            origin_x = anchor_x,
            origin_y = anchor_y,
            anchor_x = anchor_x,
            anchor_y = anchor_y,
            target_x = anchor_x,
            target_y = anchor_y,
            t = t,
            normal_x = normal_x,
            normal_y = normal_y
        }

        self._slots[i] = arm_slot

        if n_arms_left > 0 then
            self._free_arms[n_arms_left] = true
            n_arms_left = n_arms_left - 1
        end
    end
end

--- @brief
function ow.DeceleratorSurfaceBody:_add_to_slot(slot_i, arm_i)
    local slot = self._slots[slot_i]
    assert(slot.arm_i == nil)
    slot.arm_i = arm_i

    -- reset to fully retracted
    local arm = self._arms[arm_i]
    arm.slot_i = slot_i
    arm.is_extending = false
    local data = self._data
    for particle_i = arm.start_i, arm.end_i do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _x_offset] = slot.anchor_x
        data[i + _y_offset] = slot.anchor_y
    end

    self._free_arms[arm_i] = nil
end

--- @brief
function ow.DeceleratorSurfaceBody:_remove_from_slot(slot_i)
    local slot = self._slots[slot_i]
    local arm_i = slot.arm_i
    assert(arm_i ~= nil)

    slot.arm_i = nil

    local arm = self._arms[arm_i]
    arm.slot_i = nil

    self._free_arms[arm_i] = true
end

--- @brief
function ow.DeceleratorSurfaceBody:set_target(x, y, radius)
    self._is_active = true
    self._target_x, self._target_y, self._target_radius = x, y, radius
    local final_x, final_y, closest_t = self._path:get_closest_point(x, y)
    self._closest_x, self._closest_y = final_x, final_y
    self._closest_normal_x, self._closest_normal_y = self._path:get_normal_at(closest_t)
    self._target_t = closest_t

    -- update slot targets
    local n_slots, n_arms = #self._slots, #self._arms
    local dx, dy = math.subtract(self._target_x, self._target_y, final_x, final_y)
    local t_step = 1 / #self._slots

    local mid_t = self._target_t
    local right_t = self._target_t + math.floor(0.5 * n_arms) * t_step
    local left_t = self._target_t - math.ceil(0.5 * n_arms) * t_step

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

    local inlay = rt.settings.overworld.decelerator_body.retract_threshold

    local range = 2 * math.pi
    local mid_point = math.angle(dx, dy)

    for slot_i = 1, n_slots do
        local slot = self._slots[slot_i]
        local slot_t = slot.t

        if is_in_interval(slot_t, left_t, right_t) then
            local attachment_angle = math.mix(
                mid_point - 0.5 * math.pi,
                mid_point + 0.5 * math.pi,
                (slot_t - left_t) / (right_t - left_t)
            )

            slot.target_x = self._target_x + math.cos(attachment_angle) * self._target_radius
            slot.target_y = self._target_y + math.sin(attachment_angle) * self._target_radius

            slot.anchor_x = slot.origin_x + slot.normal_x * inlay
            slot.anchor_y = slot.origin_y + slot.normal_y * inlay

            -- add first free arm
            if slot.arm_i == nil then
                local next_arm_i = select(1, next(self._free_arms))
                if next_arm_i ~= nil then
                    self:_add_to_slot(slot_i, next_arm_i)
                end
            end
        else
            slot.anchor_x = slot.origin_x
            slot.anchor_y = slot.origin_y
            slot.target_x = slot.anchor_x
            slot.target_y = slot.anchor_y

            -- removal done in _step when arm is retracted
        end
    end

    for arm_i = 1, #self._arms do
        if self._free_arms[arm_i] == nil then
            local arm = self._arms[arm_i]
            local slot = self._slots[arm.slot_i]

            if slot ~= nil and is_in_interval(slot.t, left_t, right_t) then
                arm.is_extending = math.distance(
                    slot.anchor_x, slot.anchor_y,
                    slot.target_x, slot.target_y
                ) <= (self._arm_length + self._arm_length_extension)
            else
                arm.is_extending = false
            end
        end
    end

    self:_update_instance_mesh()
end

--- @brief
function ow.DeceleratorSurfaceBody:_update_instance_mesh()
    if self._instance_mesh == nil then
        local x, y, r = 0, 0, 1
        local mesh = rt.Mesh({
            { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
            { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
            { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
            { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
            { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
        }, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)

        mesh:set_vertex_map(
            1, 2, 3,
            1, 3, 4,
            1, 4, 5,
            1, 5, 2
        )
        mesh:set_texture(self._particle_texture)
        self._instance_mesh = mesh
    end


    local is_initialized = self._data_mesh_data ~= nil
    if self._data_mesh_data == nil then self._data_mesh_data = {} end

    local data_i = 1
    local get_data = function()
        local data
        if is_initialized then
            data = self._data_mesh_data[data_i]
        else
            data = {}
            self._data_mesh_data[data_i] = data
        end

        data_i = data_i + 1
        return data
    end

    local particle_w, particle_h = self._particle_texture:get_size()
    assert(particle_w == particle_h)

    -- slot particles
    local settings = rt.settings.overworld.decelerator_body
    local min_slot_scale, max_slot_scale = settings.slot_min_scale, settings.slot_max_scale
    local slot_n_steps = math.ceil(self._path:get_length() / (settings.max_radius * max_slot_scale))

    for i = 1, slot_n_steps, 1 do
        local data = get_data()
        data[1], data[2] = self._path:at((i - 1) / slot_n_steps)
        data[3] = settings.max_radius * math.mix(min_slot_scale, max_slot_scale, rt.random.noise(meta.hash(self) + i + rt.SceneManager:get_elapsed()))
    end

    -- arm particles
    local particle_data = self._data
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local data = get_data()
        data[1] = particle_data[i + _x_offset]
        data[2] = particle_data[i + _y_offset]
        data[3] = particle_data[i + _radius_offset]
    end

    if not is_initialized then
        self._n_instances = data_i - 1

        self._data_mesh_format = {
            { location = 3, name = "position", format = "floatvec2" },
            { location = 4, name = "radius", format = "float" },
        }

        self._data_mesh = rt.Mesh(
            self._data_mesh_data,
            rt.MeshDrawMode.POINTS,
            self._data_mesh_format,
            rt.GraphicsBufferUsage.STREAM
        )

        for entry in values(self._data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._data_mesh,
                entry.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end
    else
        local first_i = #self._data_mesh_data - self._n_particles
        self._data_mesh:replace_data(self._data_mesh_data)
    end
end

--- @brief
function ow.DeceleratorSurfaceBody:update(delta)
    self._arm_length_extension = ternary(
        self._scene:get_player():get_is_bubble(),
        rt.settings.player.radius * (rt.settings.player.bubble_radius_factor - 1),
        0
    )

    self:_step(delta)
    self:_update_instance_mesh()
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
    function ow.DeceleratorSurfaceBody:_step(delta)
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

            -- Gauss-Seidel style iterations over constraints
            for __ = 1, n_constraint_iterations do
                for arm in values(self._arms) do
                    if arm.slot_i == nil then goto next_arm end

                    local slot = self._slots[arm.slot_i]
                    local is_extending = arm.is_extending
                    local segment_length = (self._arm_length + self._arm_length_extension) / arm.n_segments
                    local start_i, end_i = arm.start_i, arm.end_i
                    local anchor_x, anchor_y = slot.anchor_x, slot.anchor_y

                    do
                        local retraction_sum = 0
                        local target_start_i, target_end_i, target_x, target_y, alpha
                        if is_extending then
                            alpha = extend_alpha
                            target_start_i = start_i + 1
                            target_end_i = end_i
                            target_x, target_y = slot.target_x, slot.target_y
                        else
                            alpha = retract_alpha
                            target_start_i = start_i + 1 -- first is anchor
                            target_end_i = end_i
                            target_x, target_y = slot.anchor_x, slot.anchor_y
                        end

                        -- end node target
                        for node_i = target_start_i, target_end_i do
                            local i = _particle_i_to_data_offset(node_i)
                            local x, y = data[i + _x_offset], data[i + _y_offset]
                            local correction_x, correction_y, lambda_new = _enforce_anchor(
                                x, y,
                                target_x, target_y,
                                data[i + _inverse_mass_offset],
                                alpha,
                                data[i + _target_lambda_offset]
                            )

                            local new_x = x + correction_x
                            local new_y = y + correction_y
                            data[i + _x_offset] = new_x
                            data[i + _y_offset] = new_y
                            data[i + _target_lambda_offset] = lambda_new
                        end

                        -- if retracting, check if fully done, if yes, free and add to buffer
                        if not is_extending then
                            local i = _particle_i_to_data_offset(end_i)
                            if math.distance(
                                data[i + _x_offset],
                                data[i + _y_offset],
                                anchor_x,
                                anchor_y
                            ) < settings.retract_threshold then
                                self:_remove_from_slot(arm.slot_i)
                            end
                        end
                    end

                    -- segment distance constraints
                    for node_i = start_i, end_i - 1 do
                        local a_i = _particle_i_to_data_offset(node_i + 0)
                        local b_i = _particle_i_to_data_offset(node_i + 1)

                        local ax, ay = data[a_i + _x_offset], data[a_i + _y_offset]
                        local bx, by = data[b_i + _x_offset], data[b_i + _y_offset]

                        local inverse_mass_a = data[a_i + _inverse_mass_offset]
                        local inverse_mass_b = data[b_i + _inverse_mass_offset]

                        local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_distance(
                            ax, ay, bx, by,
                            inverse_mass_a, inverse_mass_b,
                            segment_length,
                            distance_alpha,
                            data[a_i + _distance_lambda_offset]
                        )

                        data[a_i + _x_offset] = ax + correction_ax
                        data[a_i + _y_offset] = ay + correction_ay
                        data[b_i + _x_offset] = bx + correction_bx
                        data[b_i + _y_offset] = by + correction_by
                        data[a_i + _distance_lambda_offset] = lambda_new
                    end

                    if is_extending then
                        -- bending constraints (XPBD)
                        for node_i = start_i, end_i - 2 do
                            local a_i = _particle_i_to_data_offset(node_i + 0)
                            local b_i = _particle_i_to_data_offset(node_i + 1)
                            local c_i = _particle_i_to_data_offset(node_i + 2)

                            local ax, ay = data[a_i + _x_offset], data[a_i + _y_offset]
                            local bx, by = data[b_i + _x_offset], data[b_i + _y_offset]
                            local particle_c_x, particle_c_y = data[c_i + _x_offset], data[c_i + _y_offset]

                            local inverse_mass_a = data[a_i + _inverse_mass_offset]
                            local inverse_mass_b = data[b_i + _inverse_mass_offset]
                            local inverse_mass_c = data[c_i + _inverse_mass_offset]

                            local segment_length_ab = segment_length
                            local segment_length_bc = segment_length
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
                    end

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

                    do -- pin anchor
                        local i = _particle_i_to_data_offset(start_i)
                        data[i + _x_offset] = anchor_x
                        data[i + _y_offset] = anchor_y
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

            self._n_connected = 0
            for arm_i = 1, #self._arms do
                local arm = self._arms[arm_i]
                if self._free_arms[arm_i] == nil and arm.is_extending == true then
                    local i = _particle_i_to_data_offset(arm.end_i)
                    local slot = self._slots[arm.slot_i]
                    if math.distance(
                        data[i + _x_offset],
                        data[i + _y_offset],
                        slot.target_x,
                        slot.target_y
                    ) < max_radius then
                        self._n_connected = self._n_connected + 1
                    end
                end
            end
        end

        self._canvas_needs_update = true
    end
end

--- @brief
function ow.DeceleratorSurfaceBody:draw()
    local mean_x = math.mix(self._aabb.x, self._aabb.x + self._aabb.width, 0.5)
    local mean_y = math.mix(self._aabb.y, self._aabb.y + self._aabb.height, 0.5)
    local w, h = self._canvas:get_size()

    if self._canvas_needs_update then
        love.graphics.push("all")
        love.graphics.reset()

        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setBlendMode("add", "premultiplied")

        love.graphics.translate(
            -mean_x + 0.5 * w, -mean_y + 0.5 * h
        )

        local data = self._data

        -- draw to .r: density
        love.graphics.setColor(1, 0, 0, 1)

        self._mesh:draw()

        _instance_draw_shader:bind()
        _instance_draw_shader:send("texture_scale", rt.settings.overworld.decelerator_body.texture_scale)
        self._instance_mesh:draw_instanced(self._n_instances)
        _instance_draw_shader:unbind()

        -- draw to .g: mask
        love.graphics.setColor(0, 1, 1, 1)

        self._mesh:draw()

        love.graphics.setLineWidth(5)
        love.graphics.setLineStyle("smooth")
        love.graphics.line(self._contour)

        self._canvas:unbind()
        love.graphics.pop()

        self._canvas_needs_update = true
    end

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.translate(mean_x - 0.5 * w, mean_y - 0.5 * h)
    love.graphics.setColor(1, 1, 1, 1)

    local transform = self._scene:get_camera():get_transform()
    transform = transform:inverse()

    local settings = rt.settings.overworld.decelerator_body
    _threshold_shader:bind()
    _threshold_shader:send("threshold", settings.threshold)
    _threshold_shader:send("smoothness", settings.smoothness)
    _threshold_shader:send("outline_thickness", settings.outline_thickness)
    _threshold_shader:send("outline_color", { rt.Palette.MINT:unpack() })
    _threshold_shader:send("body_color", { rt.Palette.BLACK:unpack() })
    _threshold_shader:send("screen_to_world_transform", transform)
    _threshold_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))

    love.graphics.draw(self._canvas:get_native())
    _threshold_shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.DeceleratorSurfaceBody:get_penetration()
    if self._target_t == nil then return nil end
    local normal_x, normal_y = self._closest_normal_x, self._closest_normal_y

    local to_target_x = self._target_x - self._closest_x
    local to_target_y = self._target_y - self._closest_y

    local signed_dist = -1 * math.dot(to_target_x, to_target_y, normal_x, normal_y)

    if signed_dist < 0 then
        -- fully inside body
        return 1, -self._closest_normal_x, -self._closest_normal_y
    else
        -- grabbed by arms
        local penetration = math.min(1, 1 - math.min(1, (signed_dist - self._target_radius) / (rt.settings.overworld.decelerator_body.arm_length)))
        penetration = penetration * math.min(1, self._n_connected / rt.settings.overworld.decelerator_body.n_arms_for_full_force)
        return penetration, -self._closest_normal_x, -self._closest_normal_y
    end
end

--- @brief
function ow.DeceleratorSurfaceBody:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end