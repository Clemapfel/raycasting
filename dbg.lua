return {
    collision_strength = 0.99,
    collision_overlap_factor = 10,

    cohesion_strength = 0,
    cohesion_interaction_distance_factor = 5,

    follow_strength = 1 - 0.001,

    damping = 0.2,
    n_sub_steps = 3,
    step_delta = 1 / 60,

    min_mass = 1,
    max_mass = 2,

    threshold_shader_threshold = 0.05,
    composite_alpha = 1,
    texture_scale = 2,
    threshold_shader_smoothness = 0.05
}

--[[
Here’s how to think about the spatial hash cell size and a review of the _step function with concrete issues and fixes.

How to choose the optimal spatial hash cell size

Your neighbor search only checks the 3x3 cells around each particle (offsets -1..1). For this to be correct, any two particles that can interact must lie in the same cell or one of the 8 neighbors.
Let R_ij be the maximum interaction distance between two particles i and j. In your solver you have two interactions:
Collision: distance threshold = collision_overlap_fraction * (r_i + r_j)
Cohesion: distance threshold = cohesion_interaction_distance_fraction * (r_i + r_j)
The worst-case (max) interaction distance across all pairs in an environment is: R_max = max(collision_overlap_fraction, cohesion_interaction_distance_fraction) * (2 * max_radius)
To guarantee that the 3x3 neighborhood is sufficient, the cell size must satisfy cell_size >= R_max. If you use a smaller cell size you’d need to search more than 3x3 cells.
Therefore the optimal minimal cell size (which minimizes per-cell occupancy while preserving correctness for the 3x3 neighborhood) is: cell_size = max(collision_overlap_fraction, cohesion_interaction_distance_fraction) * 2 * current_settings.max_radius
Notes:
Recompute per environment (white/yolk) and per step if the debug knobs can change at runtime.
If you want to reduce false positives further, compute cell_size from the actual max radius present in the env that step (not just settings.max_radius), but settings.max_radius is a safe and cheaper bound.
Key issues found in _step (with recommended fixes)

Velocity integration is wrong (pre-solve)
Current: particles[velocity_x] = particles[velocity_x] * damping * sub_delta particles[x] = particles[x] + sub_delta * particles[velocity_x]
Problem: you scale velocity by sub_delta and then also multiply by sub_delta when integrating, which effectively turns Δx into O(dt^2). This breaks units/dynamics.
Fix:
Apply damping to velocity only (no dt factor): v *= damping
Integrate position: x += dt * v
Since you recompute velocity in post_solve from position delta, that scheme matches common XPBD update.
Pair correction application bug (x/y swapped)
In both collision and cohesion sections you have: data[other_x] = data[other_x] + other_cy data[other_y] = data[other_y] + other_cy
The x component uses other_cy by mistake. This will deflect motion incorrectly and can destabilize the solver.
Fix: data[other_x] = data[other_x] + other_cx data[other_y] = data[other_y] + other_cy
Cohesion uses the wrong target distance variable
You correctly compute: local interaction_distance = cohesion_interaction_distance_fraction * (r_a + r_b)
But you pass min_distance (from collision) into enforce_distance for cohesion.
Fix: pass interaction_distance for cohesion.
Environment reuse doesn’t update runtime parameters
When reusing envs, spatial_hash_cell_radius and damping are not recomputed if the debugger values change. That means turning knobs won’t actually affect existing environments.
Fix: on reuse, recompute spatial_hash_cell_radius from current debug values and also refresh env.damping.
Ensure n_sub_steps is valid
If debugger returns 0 or nil you’ll divide by zero.
Fix: n_sub_steps = max(1, floor(...)) and fall back to settings.n_sub_steps if debug value is nil.
Position-to-target constraint is OK but consider clamping
enforce_position is missing the clamping you added to enforce_distance. In practice this can help avoid overshoot/oscillation when follow_strength is weak but dt is large.
Naming clarity
env.spatial_hash_cell_radius is a cell size (not a radius). This can be confusing. Consider renaming to spatial_hash_cell_size.
Minor non-_step issues worth fixing
_assert uses if not type(instance) == instance_type then, which is always false due to operator precedence; it should be if type(instance) ~= instance_type then. Also the error message uses instance_type for both expected and got.
love.graphics.setColor(0, 0, 0, 0, 1) uses 5 params; it should be setColor(0, 0, 0, 1).
Proposed code updates

I’ve prepared a corrected _step implementation that:
Recomputes cell size per env and per step.
Fixes velocity integration.
Fixes the x/y correction bug.
Fixes the cohesion target distance.
Guards n_sub_steps against invalid values.
]]