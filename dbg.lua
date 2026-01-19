return {
    collision_strength = 1,
    collision_overlap_factor = 2,

    cohesion_strength = 1 - 0.0006,
    cohesion_interaction_distance_factor = 3,

    follow_strength = 0.996,

    damping = 0.095,
    n_sub_steps = 2,
    n_collision_steps = 4,
    step_delta = 1 / 120,

    mass_distribution_variance = 4,

    threshold_shader_threshold = 0.3,
    composite_alpha = 1,
    texture_scale = 20,
    threshold_shader_smoothness = 0.02,

    motion_blur_multiplier = 0.0005,
}

--[[
Here’s a focused review of the simulation’s performance and stability, followed by a concrete fix for the missing render texture padding and a couple of small robustness tweaks.

High-impact performance and stability observations and recommendations

Neighbor search and collision loop
Spatial hash rebuild: You rebuild the grid for both phases and for each collision iteration, then clear the tables each pass. This creates allocation pressure. Use an epoch-marking scheme for collided pairs and spatial hash buckets to avoid table.clear and re-allocations, or reuse arrays with per-bucket size counters.
Cell size: env.spatial_hash_cell_radius is set to 2 * max_radius * max_factor, and you check a 3x3 neighborhood. If collision_overlap_factor is large (egg white = 10), cells become huge and neighbors per cell explode. Use cell_size ≈ max_interaction_radius (not 2x) where max_interaction_radius = max(collision_min_distance, cohesion_distance). For your constraints:
collision_min_distance ≈ overlap_factor * (r_i + r_j)
cohesion_distance = cohesion_interaction_distance_factor * (r_i + r_j)
With r_i ≈ _max_radius, a good cell size is max(overlap_factor, cohesion_factor) * 2 * _max_radius, and query 3x3 cells. If overlap_factor is > 1 (repulsion beyond contact), consider reducing it (see below), otherwise the grid degenerates.
Pair tracking: collided uses a pairing function per pair per pass. Instead, store for each particle the last-processed epoch of the partner to avoid hashing huge numbers and reduce memory.
Constraint parameters and physical behavior
collision_overlap_factor is 10 for egg white which enforces a minimum separation of 10*(r1 + r2). That will blast particles apart, create jitter, and flood the neighbor list. This parameter should usually be ≤ 1 for soft-sphere-like repulsion (1.0 ≈ contact at r1 + r2). Start with 0.9–1.1 and tune compliance for softness.
n_collision_steps is read but not defined in settings. Default to something reasonable (2–4) to reduce tunneling and improve constraint convergence.
Sub-stepping: n_sub_steps = 1 will limit XPBD convergence when constraints are stiff. 2–4 sub-steps often give a big stability win for fluids/pseudos-fluids with modest perf impact.
damping interpretation: Your mapping env.damping = 1 - clamp(damping) means damping=0.7 => keep 30% of velocity per substep. That’s extremely strong damping; ensure that’s intentional.
Follow (anchor) constraint: Right now it snaps each particle towards target independently. Consider blending target distance with a max step or spring approach to avoid “teleport” feel when the target jumps.
Data layout and instancing
Mesh attribute uploads: You reallocate the per-instance data Mesh when the size changes, which is fine, but add a capacity strategy (grow by 1.5–2x) to avoid frequent reallocations around thresholds.
Instancing toggle: Overriding _use_instancing via love.keyboard.isDown("space") every update defeats your initial device support test and can cause inconsistent setup and perf. Use a static choice (with an explicit debug key to toggle once) and avoid per-frame switch.
pcall in hot paths: _safe_send wraps shader.send in pcall each frame. That’s costly. Do it only when you first send a uniform, and when values change. For per-frame values, avoid pcall and rely on testing in dev.
Micro-optimizations
Use local references for math.* functions in hot loops (normalize, magnitude, squared_distance) to reduce global table lookups.
Avoid table.insert in tight loops; you already use index writes in some places—do that everywhere in the hash buckets and mesh_data.
_assert has a logic bug: if not type(instance) == instance_type is always false. It should be if type(instance) ~= instance_type then ...
Visual quality and antialiasing
The canvas content is thresholded later; motion smear and texture scaling can exceed the geometric min/max (which uses just r). You must include this in the canvas padding (see fix below), otherwise you’ll see clipped blobs when velocity spikes or texture_scale > 1.
Correct padding for resize_canvas_maybe

Why padding is currently wrong:

env.min_x/max_x include particle radii r (you subtract/add r when creating the AABB).
You draw each particle with a scaled kernel. The half-extent of the quad (in world px) is base_scale in y and base_scale * smear_amount in x, then rotated by velocity angle. base_scale = r * texture_scale, smear_amount = 1 + |v| * motion_blur_multiplier.
Because the quad rotates, the maximum axis-aligned half-extent is sqrt(scale_x^2 + scale_y^2).
You also predict particle positions by v * elapsed when drawing, but keep the centroid at the last-sim centroid, so positions shift relative to the canvas origin. You must pad for that drift too.
Putting this together, per phase (white/yolk) you need a padding of: padding = (r_max * texture_scale) * sqrt((1 + v_max * m)^2 + 1) - r_max + v_max * step_delta + safety_margin

Where:

r_max is the maximum particle radius in the env (per-phase).
v_max is the maximum |velocity| in the env (per-phase).
m is motion_blur_multiplier (default 0 if missing).
step_delta is the fixed sim step (upper bound for frame interpolation between steps).
safety_margin is a small constant (e.g., 2 px) to compensate for numeric error and filtering.
Implementation details:

Track r_max and v_max in _post_solve (cheap to compute in the same loop).
Use that padding in resize_canvas_maybe.
If you also translate by predicted centroid in _update_canvases (centroid + v̄ * elapsed), you can drop the drift term v_max * step_delta or reduce it significantly.
I’ve provided a drop-in code update that:

Computes v_max and r_max in _post_solve.
Uses the padding formula in resize_canvas_maybe.
Defaults n_collision_steps and motion_blur_multiplier safely when missing.
-- Replace the existing _post_solve with this version.
local function _post_solve(particles, n_particles, delta)
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    local centroid_x, centroid_y = 0, 0

    local v_max = 0
    local r_max = 0

    for particle_i = 1, n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local x_i = i + _x_offset
        local y_i = i + _y_offset
        local previous_x_i = i + _previous_x_offset
        local previous_y_i = i + _previous_y_offset
        local velocity_x_i = i + _velocity_x_offset
        local velocity_y_i = i + _velocity_y_offset
        local radius_i = i + _radius_offset

        local x = particles[x_i]
        local y = particles[y_i]

        -- update velocity from displacement
        local vx = (x - particles[previous_x_i]) / delta
        local vy = (y - particles[previous_y_i]) / delta
        particles[velocity_x_i] = vx
        particles[velocity_y_i] = vy

        local vmag = math.magnitude(vx, vy)
        if vmag > v_max then v_max = vmag end

        centroid_x = centroid_x + x
        centroid_y = centroid_y + y

        -- log AABB including particle radius
        local r = particles[radius_i]
        if r > r_max then r_max = r end
        min_x = math.min(min_x, x - r)
        min_y = math.min(min_y, y - r)
        max_x = math.max(max_x, x + r)
        max_y = math.max(max_y, y + r)
    end

    if n_particles > 0 then
        centroid_x = centroid_x / n_particles
        centroid_y = centroid_y / n_particles
    end

    -- Also return r_max and v_max for correct render padding later.
    return min_x, min_y, max_x, max_y, centroid_x, centroid_y, r_max, v_max
end

-- In _step, make sure n_collision_steps has a safe default
-- Replace the line:
--   local n_collision_steps = self._settings.n_collision_steps
-- With:
local n_collision_steps = self._settings.n_collision_steps or 2

-- In _step, where _post_solve is called, capture r_max and v_max as well.
-- Replace these two assignments:

-- white
white_env.min_x, white_env.min_y,
white_env.max_x, white_env.max_y,
white_env.centroid_x, white_env.centroid_y = _post_solve(
    white_env.particles,
    white_env.n_particles,
    sub_delta
)

-- yolk
yolk_env.min_x, yolk_env.min_y,
yolk_env.max_x, yolk_env.max_y,
yolk_env.centroid_x, yolk_env.centroid_y = _post_solve(
    yolk_env.particles,
    yolk_env.n_particles,
    sub_delta
)

-- With these:

-- white
white_env.min_x, white_env.min_y,
white_env.max_x, white_env.max_y,
white_env.centroid_x, white_env.centroid_y,
white_env.r_max, white_env.v_max = _post_solve(
    white_env.particles,
    white_env.n_particles,
    sub_delta
)

-- yolk
yolk_env.min_x, yolk_env.min_y,
yolk_env.max_x, yolk_env.max_y,
yolk_env.centroid_x, yolk_env.centroid_y,
yolk_env.r_max, yolk_env.v_max = _post_solve(
    yolk_env.particles,
    yolk_env.n_particles,
    sub_delta
)

-- Now replace the local function resize_canvas_maybe in _step with this version:
local function resize_canvas_maybe(canvas, env)
    if env.n_particles == 0 then
        return canvas
    end

    local current_w, current_h = 0, 0
    if canvas ~= nil then
        current_w, current_h = canvas:getDimensions()
    end

    -- Compute conservative padding to ensure the draw pass never clips.
    -- Components:
    --  1) scale from texture_scale inflates half-extent from r to base_scale = r * texture_scale
    --  2) motion smear inflates X half-extent by (1 + v * m), rotation => axis-aligned half-extent = sqrt(sx^2 + sy^2)
    --  3) frame interpolation drift (predicted pose vs centroid of last sim step)
    --  4) small safety margin for filtering / numeric error
    local m = (self._settings.motion_blur_multiplier or 0)
    local step_delta = self._settings.step_delta or (1 / 60)
    local texture_scale = self._settings.texture_scale or 1

    local r_max = env.r_max or 0
    local v_max = env.v_max or 0

    -- Half-extent of drawn quad (worst-case orientation)
    local base = r_max * texture_scale
    local sx = base * (1 + v_max * m)
    local sy = base
    local half_extent_draw = math.sqrt(sx * sx + sy * sy)

    -- AABB already includes ±r; we need the extra beyond r
    local extra_beyond_aabb = math.max(0, half_extent_draw - r_max)

    -- Drift between sim and draw (since centroid isn't predicted here)
    local drift = v_max * step_delta

    local safety_margin = 2 -- px

    local padding = extra_beyond_aabb + drift + safety_margin

    -- Required canvas size (ceil to integers)
    local new_w = math.ceil((env.max_x - env.min_x) + 2 * padding)
    local new_h = math.ceil((env.max_y - env.min_y) + 2 * padding)

    if new_w > current_w or new_h > current_h then
        local new_canvas = love.graphics.newCanvas(
            math.max(new_w, current_w),
            math.max(new_h, current_h),
            {
                msaa = self._settings.canvas_msaa,
                format = self._render_texture_format
            }
        )
        new_canvas:setFilter("linear", "linear")

        if canvas ~= nil then
            canvas:release() -- free old as early as possible, uses vram
        end
        return new_canvas
    else
        return canvas
    end
end
Copy
Insert

Optional improvement: reduce padding by predicting the centroid during draw

In _update_canvases, translate by predicted centroid:
Compute elapsed = love.timer.getTime() - self._last_update_timestamp
Compute env.mean_vx and env.mean_vy in _post_solve (cheap: accumulate vx, vy and divide by n).
Translate by -(env.centroid_x + mean_vx * elapsed, env.centroid_y + mean_vy * elapsed) instead of -(env.centroid_x, env.centroid_y).
Then you can drop or greatly reduce the drift term in the padding formula.
Quick fixes you should apply regardless

Fix _assert:
Change if not type(instance) == instance_type then to if type(instance) ~= instance_type then.
Provide sensible defaults in settings for missing keys used elsewhere:
motion_blur_multiplier (e.g., 0.002–0.006 depending on taste).
n_collision_steps (2–4).
If you want, I can follow up with a patch to predict the centroid in the draw path and convert the spatial hash to an epoch-based clearing model to minimize GC in collision iterations.
]]