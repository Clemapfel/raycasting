#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X undefined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y undefined"
#endif

#ifndef WORK_GROUP_SIZE_Z
#error "WORK_GROUP_SIZE_Z undefined"
#endif

#ifndef LIGHT_RANGE
#error "LIGHT_RANGE undefined"
#endif

/// ### POINT LIGHTS ###

#ifndef MAX_N_POINT_LIGHTS
#error "MAX_N_POINT_LIGHTS undefined"
#endif

struct PointLight {
    vec2 position; // in screen space
    float radius;
    vec4 color;
};

layout(std430) readonly buffer point_light_source_buffer {
    PointLight point_light_sources[];
}; // size: MAX_N_POINT_LIGHTS

vec2 closest_point_on_disk(vec2 xy, vec2 circle_xy, float radius) {
    vec2 difference = xy - circle_xy;
    float length_squared = dot(difference, difference);
    float radius_squared = radius * radius;

    if (length_squared <= radius_squared) // inside disk
        return xy;

    return circle_xy + difference * (radius * inversesqrt(length_squared));
}

// ### SEGMENT LIGHTS ###

#ifndef MAX_N_SEGMENT_LIGHTS
#error "MAX_N_SEGMENT_LIGHTS undefined"
#endif

struct SegmentLight {
    vec4 segment; // screen space
    vec4 color;
};

layout(std430) readonly buffer segment_light_sources_buffer {
    SegmentLight segment_light_sources[];
}; // size: MAX_N_SEGMENT_LIGHTS

vec2 closest_point_on_segment(vec2 xy, vec4 segment) {
    vec2 a = segment.xy;
    vec2 b = segment.zw;
    vec2 ab = b - a;
    float ab_len2 = dot(ab, ab);

    if (ab_len2 <= 0.0) return a;

    vec2 ap = xy - a;
    float t = clamp(dot(ap, ab) / ab_len2, 0.0, 1.0);
    return a + t * ab;
}

// ### TILE DATA ###

#ifndef TILE_SIZE
#error "TILE_SIZE undefined"
#endif

layout(std430) readonly buffer tile_data_buffer {
    int tile_data_inline[];
};

const int TILE_DATA_STRIDE = 1 + MAX_N_POINT_LIGHTS + 1 + MAX_N_SEGMENT_LIGHTS;
const int SEGMENT_LIGHT_COUNT_OFFSET = 1 + MAX_N_POINT_LIGHTS;
const int SEGMENT_LIGHT_BASE_OFFSET  = 2 + MAX_N_POINT_LIGHTS;

int xy_to_tile_data_offset(ivec2 xy, ivec2 screen_size) {
    int tile_x = xy.x / TILE_SIZE;
    int tile_y = xy.y / TILE_SIZE;

    // equivalent to ceil(screen_size.x / TILE_SIZE)
    int n_tiles_per_row = (screen_size.x + TILE_SIZE - 1) / TILE_SIZE;
    int tile_index = tile_y * n_tiles_per_row + tile_x;

    return tile_index * TILE_DATA_STRIDE;
}

int get_n_point_lights(int tile_offset) {
    return tile_data_inline[tile_offset];
}

int get_point_light_index(int tile_offset, int i) {
    return tile_data_inline[tile_offset + 1 + i];
}

int get_n_segment_lights(int tile_offset) {
    return tile_data_inline[tile_offset + SEGMENT_LIGHT_COUNT_OFFSET];
}

int get_segment_light_index(int tile_offset, int i) {
    return tile_data_inline[tile_offset + SEGMENT_LIGHT_BASE_OFFSET + i];
}

/// ### LIGHT COMPUTATION ###

#ifndef LIGHT_INTENSITY_TEXTURE_FORMAT
#error "LIGHT_INTENSITY_TEXTURE_FORMAT undefined"
#endif

#ifndef LIGHT_DIRECTION_TEXTURE_FORMAT
#error "LIGHT_DIRECTION_TEXTURE_FORMAT undefined"
#endif

#ifndef MASK_TEXTURE_FORMAT
#error "MASK_TEXTURE_FORMAT undefined"
#endif

layout(LIGHT_INTENSITY_TEXTURE_FORMAT) uniform writeonly image2D light_intensity_texture;
// rgb: light color, a: intensity

layout(LIGHT_DIRECTION_TEXTURE_FORMAT) uniform writeonly image2D light_direction_texture;
// rg: light normal

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
// r: masked

#ifndef LIGHT_RANGE
#error "LIGHT_RANGE undefined"
#endif

// tonemap multiplie
#ifndef INTENSITY
#error "INTENSITY undefined"
#endif

// slope of 3d light plane for normal computation, in px
#ifndef LIGHT_Z_HEIGHT
#error "LIGHT_Z_HEIGHT undefined"
#endif

// rgb weights for luminance computation
const vec3 luma_coefficients = vec3(0.2126, 0.7152, 0.0722); // BT.709

float gaussian(float x) {
    return exp(-(x * x));
}

vec4 compute_light(vec4 light_color, float distance_squared) {
    const float third = 1.0 / 3.0;
    const float inverse_light_range = 1.0 / float(LIGHT_RANGE);

    float dist = sqrt(distance_squared);
    float attenuation = clamp(gaussian(dist * inverse_light_range), 0.0, 1.0);
    light_color.rgb *= light_color.a;
    return light_color * (attenuation * third);
}

vec4 tonemap(vec4 color) {
    vec3 hdr = color.rgb * INTENSITY;
    vec3 mapped = hdr / (hdr + vec3(1.0));
    return vec4(clamp(mapped, 0.0, 1.0), color.a);
}

// ### MAIN ###

#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X undefined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y undefined"
#endif

#ifndef WORK_GROUP_SIZE_Z
#error "WORK_GROUP_SIZE_Z undefined"
#endif

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain() {
    ivec2 image_size = imageSize(light_intensity_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(position, image_size))) return;

    if (imageLoad(mask_texture, position).r == 0) {
        imageStore(light_intensity_texture, position, vec4(0));
        return;
    }

    int tile_offset = xy_to_tile_data_offset(position, image_size);
    int n_point_lights = get_n_point_lights(tile_offset);
    int n_segment_lights = get_n_segment_lights(tile_offset);

    // point light rgba
    vec4 point_color = vec4(0.0);

    // segment light rgba
    vec4 segment_color = vec4(0.0);

    // slope for all lights
    vec2 light_direction = vec2(0.0);
    float light_direction_weight = 0.0;

    const float inv_height = 1.0 / LIGHT_Z_HEIGHT;

    // accumulate point lights
    for (int i = 0; i < n_point_lights; ++i) {
        PointLight light = point_light_sources[get_point_light_index(tile_offset, i)];

        vec2 closest = closest_point_on_disk(vec2(position), light.position, light.radius);
        vec2 direction = closest - vec2(position);
        float dist_squared = dot(direction, direction);

        vec4 light_contribution = compute_light(light.color, dist_squared);
        point_color += light_contribution;

        float luminance = dot(light_contribution.rgb, luma_coefficients);
        light_direction += luminance * (direction * inv_height);
        light_direction_weight += luminance;
    }

    // accumulate segment lights
    for (int i = 0; i < n_segment_lights; ++i) {
        int segment_light_index = get_segment_light_index(tile_offset, i);
        SegmentLight light = segment_light_sources[segment_light_index];

        vec2 closest_xy = closest_point_on_segment(vec2(position), light.segment);
        vec2 direction = closest_xy - vec2(position);
        float dist_squared = dot(direction, direction);

        // color
        vec4 light_contrib = compute_light(light.color, dist_squared);
        segment_color += light_contrib;

        // direction
        float luminance = dot(light_contrib.rgb, luma_coefficients);
        light_direction += luminance * (direction * inv_height);
        light_direction_weight += luminance;
    }

    // export rgba
    imageStore(light_intensity_texture,
        position,
        tonemap(point_color + segment_color) // texture is [0, 1]
    );

    // compute mean direction
    light_direction = (light_direction_weight > 0.0) ? (light_direction / light_direction_weight) : vec2(0.0);
    imageStore(light_direction_texture,
        position,
        vec4(light_direction, 1.0, 1.0)
    );
}

/*
Below are many suggestions to reduce performance drops at high window resolutions for your compute shader, grouped by category (algorithmic, memory/bandwidth, workgroup/dispatch, precision/formatting, GPU-specific, and profiling). After the recommendations I include an example optimized shader (artifact) that implements several of the highest-impact changes: early-out culling by range, workgroup-local shared caching of the per-tile light lists (when workgroup == tile size), loop structure that is friendlier to driver unrolling, and a few micro-optimizations.

High-level guidance summary

Reduce work per-pixel (skip processing when there are no lights or when a light is too far to matter).
Reduce memory traffic (avoid repeated SSBO reads; reuse data within a workgroup; use smaller index/position formats).
Reduce expensive math (avoid sqrt when possible; avoid unnecessary operations for culled lights).
Tune dispatch/workgroup sizes to map to tiles and hardware wavefront/warp sizes.
Reduce output bandwidth (choose lower-precision texture formats or pack outputs).
Consider temporal/approximate approaches if perfect per-frame accuracy isn't required.
Recommendations

Early-out / distance culling
Add an early distance cutoff using squared distances: if dist_squared > LIGHT_RANGE*LIGHT_RANGE, skip that light entirely. This avoids computing gaussian, direction accumulation and other work for distant lights that contribute negligibly.
Also skip entire pixel early if the tile contains no lights (n_point_lights == 0 && n_segment_lights == 0): write zeros and return. This saves branching but avoids heavy loops.
Why: Avoids heavy per-light math and memory reads for lights that contribute nothing.

Reduce/global memory reads by caching per-tile lists in shared (workgroup) memory
If you dispatch compute such that each workgroup covers exactly one tile (i.e., local_size_x == TILE_SIZE, local_size_y == TILE_SIZE), load the tile's light indices (and then the referenced light structs) once into shared memory by a single invocation, then synchronize and let all local threads read the small shared arrays.
If one workgroup covers multiple tiles, consider reorganizing dispatch to make workgroup == tile or at least to have threads collaborate per-tile.
Why: SSBO access and global memory loads are expensive; caching a small list of active lights reduces loads by factor TILE_SIZE^2.

Use compile-friendly loop bounds and early break
Many GPU drivers perform better when loops have a fixed upper bound that the compiler can reason about. Replace loops like for (int i = 0; i < n_point_lights; ++i) with: for (int i = 0; i < MAX_N_POINT_LIGHTS; ++i) { if (i >= n_point_lights) break; ... }
This helps enable compile-time unrolling or better optimization in some drivers.
Avoid expensive math when unnecessary
Delay sqrt() or other heavy ops until after you know you care. For attenuation you compute dist = sqrt(distance_squared); compute gaussian(dist * inv_range). Use an early-check on distance_squared. Only perform sqrt for lights that pass the squared-distance cutoff.
Consider replacing your gaussian approximation with a cheaper one that uses distance_squared directly (if accuracy allows). E.g. approximate attenuation with 1.0/(1.0 + k * ds) or other polynomial to avoid sqrt.
Reduce precision and bandwidth
Use lower precision texture formats and SSBO storage:
Use RG11_B10F, R16G16B16A16F, or even half (16-bit float) formats for light intensity/direction if enough precision. This halves memory bandwidth for writes/reads.
Pack two outputs into one RGBA16F or pack direction into intensity texture's unused channels to reduce imageStore count.
Use 16-bit indices for tile lists (uint16_t) instead of 32-bit ints where possible — pack them into uvecN or arrays. That reduces SSBO size and memory bandwidth when transferring tile lists.
Why: imageStore and SSBO reads/writes are limited by memory bandwidth; halving size often improves throughput.

Minimize number of imageStore calls
Currently you imageStore() twice (intensity and direction). If possible, pack direction into intensity texture or use a single output texture with packed data (e.g., intensity in RGB, normalized XY direction in A and something else) and write once. If formats must differ, consider writing only when the pixel actually changes or batching.
Workgroup sizing & dispatch tuning
Choose local_size_x and local_size_y to match hardware wavefront/warp sizes and TILE_SIZE. Typical good choices: 16x8, 16x16 or 32x8 depending on GPU. Tune and profile.
If possible set local_size to exactly TILE_SIZE so that a single workgroup processes a tile and you can use shared memory for tile’s cached lights.
Use shared atomics / subgroup operations for reductions if needed
For computing per-pixel direction mean you already do a per-pixel weighted average; not suitable for global reduction. But if there are patterns where you can use subgroup intrinsics to accelerate sums across lane neighbors do so.
Data layout and compact lists
Pack tile data to reduce stride: a compact list of indices (no unused fixed slots) for each tile with a small header (count) is smaller than a huge fixed stride. You may already have fixed stride; swapping to compact variable lists reduces memory reads if many lights are zero (sparse).
Alternatively store bitsets of active lights per tile (when number of lights <= 256) and iterate over set bits. Bitset approach can be faster to test light membership for many tiles (but iterating set bits also has cost).
Deferred / multi-resolution rendering
For very high resolutions, compute lighting at a lower resolution (e.g., half or quarter resolution) and bilinearly upsample the light maps. This can drastically reduce compute cost with plausible visual quality.
Use a two-pass approach: compute coarse light map and refine near camera or moving objects.
Temporal accumulation / history reuse
Reuse previous frames' light maps with reprojection and temporal filtering; recompute only differences or moving lights. This reduces per-frame compute work at the cost of complexity and potential ghosting.
Reduce data you read for lights
Store only what you need per light in SSBO: if color alpha already multiplied or if you can compute derived values on CPU and upload, do that.
Precompute inverse_range, radius_squared or other common values on CPU and store in SSBO as a float. Avoid recomputing per-pixel.
Use half-precision (mediump) where possible in shader
On mobile and some GPUs, declaring mediump for floats reduces register pressure and memory footprint. (GLSL ES only)
Profiling and GPU-specific features
Profile with GPU tools (NVIDIA Nsight, AMD Radeon GPU Profiler, RenderDoc) to find if bottleneck is compute-bound or memory-bound.
If memory-bound, focus on reducing SSBO and image bandwidth.
If compute-bound, focus on reducing arithmetic and expensive ops (sqrt, divisions).
Use vendor-specific subgroup/wave intrinsics to accelerate reductions or fetch patterns if available.
GPU pipeline & synchronization
Avoid unnecessary memoryBarrier() or atomic ops.
Make sure SSBO and images have proper memory layouts to avoid cache thrashing.
Concrete shader-level changes (summary)

Add early tile-level exit if no lights.
Add per-light squared-range check and continue early.
Use for-loop with constant upper bound and break for compile-time optimization.
Optionally use shared arrays to cache light data per tile (requires workgroup == tile mapping).
Precompute constants (inv_range, inv_height, luma_coefficients constant) at top-level.
Consider packing outputs and choosing lower precision image formats.
Example optimized shader Below is an example "optimized" variant of your shader demonstrating:

early tile-level exit,
early distance-squared checks,
a loop pattern that is friendly to some drivers (bounded by MAX_* and break),
shared (workgroup) caching of per-tile light lists and light structs when workgroup size equals TILE_SIZE (fall back to original path otherwise).
This is an example to illustrate the pattern — you should adapt macros and dispatch so that local_size == TILE_SIZE where you intend to use shared caching. Also tune MAX_N_* and TILE_SIZE to match available memory for shared arrays on your GPU.

#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X undefined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y undefined"
#endif

#ifndef WORK_GROUP_SIZE_Z
#error "WORK_GROUP_SIZE_Z undefined"
#endif

#ifndef LIGHT_RANGE
#error "LIGHT_RANGE undefined"
#endif

#ifndef MAX_N_POINT_LIGHTS
#error "MAX_N_POINT_LIGHTS undefined"
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#error "MAX_N_SEGMENT_LIGHTS undefined"
#endif

#ifndef TILE_SIZE
#error "TILE_SIZE undefined"
#endif

#ifndef LIGHT_INTENSITY_TEXTURE_FORMAT
#error "LIGHT_INTENSITY_TEXTURE_FORMAT undefined"
#endif

#ifndef LIGHT_DIRECTION_TEXTURE_FORMAT
#error "LIGHT_DIRECTION_TEXTURE_FORMAT undefined"
#endif

struct PointLight {
    vec2 position; // in screen space
    float radius;
    vec4 color;
};

layout(std430) readonly buffer point_light_source_buffer {
    PointLight point_light_sources[];
};

struct SegmentLight {
    vec4 segment; // screen space: xy = a, zw = b
    vec4 color;
};

layout(std430) readonly buffer segment_light_sources_buffer {
    SegmentLight segment_light_sources[];
};

// packed tile list inline buffer
layout(std430) readonly buffer tile_data_buffer {
    int tile_data_inline[];
};

const int TILE_DATA_STRIDE = 1 + MAX_N_POINT_LIGHTS + 1 + MAX_N_SEGMENT_LIGHTS;

int xy_to_tile_data_offset(ivec2 xy, ivec2 screen_size) {
    int tile_x = xy.x / TILE_SIZE;
    int tile_y = xy.y / TILE_SIZE;
    int n_tiles_per_row = (screen_size.x + TILE_SIZE - 1) / TILE_SIZE;
    int tile_index = tile_y * n_tiles_per_row + tile_x;
    return tile_index * TILE_DATA_STRIDE;
}

int get_n_point_lights(int tile_offset) {
    return tile_data_inline[tile_offset];
}
int get_point_light_index(int tile_offset, int i) {
    return tile_data_inline[tile_offset + 1 + i];
}
int get_n_segment_lights(int tile_offset) {
    return tile_data_inline[tile_offset + 1 + MAX_N_POINT_LIGHTS];
}
int get_segment_light_index(int tile_offset, int i) {
    return tile_data_inline[tile_offset + 2 + MAX_N_POINT_LIGHTS + i];
}

layout(LIGHT_INTENSITY_TEXTURE_FORMAT) uniform writeonly image2D light_intensity_texture;
layout(LIGHT_DIRECTION_TEXTURE_FORMAT) uniform writeonly image2D light_direction_texture;

uniform float intensity = 1.0;
uniform float light_z_height = 256.0;
const vec3 luma_coefficients = vec3(0.2126, 0.7152, 0.0722);

const float inv_precomputed_range = 1.0 / float(LIGHT_RANGE);
const float LIGHT_RANGE_SQUARED = float(LIGHT_RANGE) * float(LIGHT_RANGE);

float gaussian_approx(float x) {
    return 1.0 / (1.0 + 0.5 * x * x * x);
}

vec4 compute_light_contrib(vec4 light_color, float dist_squared) {
    // Note: caller should have already thresholded by LIGHT_RANGE_SQUARED to avoid sqrt for far lights
    float dist = sqrt(dist_squared);
    float attenuation = clamp(gaussian_approx(dist * inv_precomputed_range), 0.0, 1.0);
    // Pre-multiply rgb by alpha (existing behavior)
    vec4 outc = light_color;
    outc.rgb *= outc.a;
    const float third = 1.0 / 3.0;
    return outc * (attenuation * third);
}

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;

// If we can guarantee a workgroup covers exactly one tile (WORKGROUP == TILE_SIZE),
// we can cache the tile's light indices & light structs in shared memory.
#if (WORK_GROUP_SIZE_X == TILE_SIZE) && (WORK_GROUP_SIZE_Y == TILE_SIZE)
shared int shared_n_point_lights;
shared int shared_n_segment_lights;
shared int shared_point_indices[MAX_N_POINT_LIGHTS];
shared int shared_segment_indices[MAX_N_SEGMENT_LIGHTS];
shared PointLight shared_point_lights[MAX_N_POINT_LIGHTS];
shared SegmentLight shared_segment_lights[MAX_N_SEGMENT_LIGHTS];
#endif

void computemain() {
    ivec2 image_size = imageSize(light_intensity_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(position, image_size))) return;

    int tile_offset = xy_to_tile_data_offset(position, image_size);

    // fast read counts
    int n_point_lights = get_n_point_lights(tile_offset);
    int n_segment_lights = get_n_segment_lights(tile_offset);

    // early tile-level exit: avoid doing anything if no lights
    if (n_point_lights == 0 && n_segment_lights == 0) {
        // write zero intensity and neutral direction
        imageStore(light_intensity_texture, position, vec4(0.0));
        imageStore(light_direction_texture, position, vec4(0.0, 0.0, 1.0, 1.0));
        return;
    }

    // Precompute constants
    float inv_height = 1.0 / light_z_height;

    vec4 point_color = vec4(0.0);
    vec4 segment_color = vec4(0.0);
    vec2 light_direction = vec2(0.0);
    float light_direction_weight = 0.0;

    // OPTIONALLY: load lists into shared memory when workgroup = tile
    #if (WORK_GROUP_SIZE_X == TILE_SIZE) && (WORK_GROUP_SIZE_Y == TILE_SIZE)
    // single thread loads the arrays for this tile
    if (gl_LocalInvocationIndex == 0) {
        shared_n_point_lights = n_point_lights;
        shared_n_segment_lights = n_segment_lights;
        // copy indices
        for (int i = 0; i < MAX_N_POINT_LIGHTS; ++i) {
            if (i >= shared_n_point_lights) { shared_point_indices[i] = -1; break; }
            shared_point_indices[i] = get_point_light_index(tile_offset, i);
        }
        for (int i = 0; i < MAX_N_SEGMENT_LIGHTS; ++i) {
            if (i >= shared_n_segment_lights) { shared_segment_indices[i] = -1; break; }
            shared_segment_indices[i] = get_segment_light_index(tile_offset, i);
        }
        // copy actual light structs (small number) into shared memory for faster reuse
        for (int i = 0; i < shared_n_point_lights; ++i) {
            shared_point_lights[i] = point_light_sources[shared_point_indices[i]];
        }
        for (int i = 0; i < shared_n_segment_lights; ++i) {
            shared_segment_lights[i] = segment_light_sources[shared_segment_indices[i]];
        }
    }
    // wait for loader
    memoryBarrierShared();
    barrier();
    // use shared arrays below
    #endif

    // iterate point lights: use compile-time upper bound with break for drivers
    for (int i = 0; i < MAX_N_POINT_LIGHTS; ++i) {
        if (i >= n_point_lights) break;
        PointLight light;
        #if (WORK_GROUP_SIZE_X == TILE_SIZE) && (WORK_GROUP_SIZE_Y == TILE_SIZE)
            light = shared_point_lights[i];
        #else
            int idx = get_point_light_index(tile_offset, i);
            light = point_light_sources[idx];
        #endif

        vec2 to_center = light.position - vec2(position);
        float dist_squared = dot(to_center, to_center);

        // distance-squared cull: skip if beyond global light range to avoid expensive sqrt and gaussian
        if (dist_squared > LIGHT_RANGE_SQUARED) continue;

        // accumulate color
        vec4 light_contrib = compute_light_contrib(light.color, dist_squared);
        point_color += light_contrib;

        // compute direction using closest point on disk; skip heavy ops if contribution is negligible
        float luminance = dot(light_contrib.rgb, luma_coefficients);
        if (luminance > 0.0001) {
            vec2 closest_xy;
            // inline closest_point_on_disk but avoid inv sqrt when inside
            vec2 difference = vec2(position) - light.position;
            float length_sq = dot(difference, difference);
            float radius_sq = light.radius * light.radius;
            if (length_sq <= radius_sq) {
                closest_xy = vec2(position);
            } else {
                const float eps = 1e-7;
                float inv_len = inversesqrt(max(length_sq, eps));
                closest_xy = light.position + (-difference) * (light.radius * inv_len); // note difference sign handled
            }
            vec2 direction = closest_xy - vec2(position);
            light_direction += luminance * (direction * inv_height);
            light_direction_weight += luminance;
        }
    }

    // iterate segment lights
    for (int i = 0; i < MAX_N_SEGMENT_LIGHTS; ++i) {
        if (i >= n_segment_lights) break;
        SegmentLight light;
        #if (WORK_GROUP_SIZE_X == TILE_SIZE) && (WORK_GROUP_SIZE_Y == TILE_SIZE)
            light = shared_segment_lights[i];
        #else
            int idx = get_segment_light_index(tile_offset, i);
            light = segment_light_sources[idx];
        #endif

        // compute closest point on segment:
        vec2 a = light.segment.xy;
        vec2 b = light.segment.zw;
        vec2 ab = b - a;
        float ab_len2 = dot(ab, ab);
        vec2 ap = vec2(position) - a;
        float t = 0.0;
        if (ab_len2 > 0.0) {
            t = clamp(dot(ap, ab) / ab_len2, 0.0, 1.0);
        }
        vec2 closest_xy = a + t * ab;
        vec2 direction = closest_xy - vec2(position);
        float dist_squared = dot(direction, direction);

        if (dist_squared > LIGHT_RANGE_SQUARED) continue;

        vec4 light_contrib = compute_light_contrib(light.color, dist_squared);
        segment_color += light_contrib;

        float luminance = dot(light_contrib.rgb, luma_coefficients);
        if (luminance > 0.0001) {
            light_direction += luminance * (direction * inv_height);
            light_direction_weight += luminance;
        }
    }

    // Output intensity and direction
    vec4 final_color = point_color + segment_color;
    vec4 mapped = final_color;
    // tonemap (simple Reinhard)
    vec3 hdr = mapped.rgb * intensity;
    vec3 tm = hdr / (hdr + vec3(1.0));
    imageStore(light_intensity_texture, position, vec4(clamp(tm, 0.0, 1.0), final_color.a));

    vec2 avg_dir = (light_direction_weight > 0.0) ? (light_direction / light_direction_weight) : vec2(0.0);
    // store xy in rg, keep 1,1 in ba for compatibility
    imageStore(light_direction_texture, position, vec4(avg_dir, 1.0, 1.0));
}
Copy
Insert

Additional implementation notes and trade-offs

Tile/workgroup mapping: the shared-memory optimization requires that workgroups map exactly to tiles — ensure your dispatch dimensions do so; otherwise use the non-shared fallback path.
Shared memory usage: allocating shared arrays of size MAX_N_* consumes shared memory; choose MAX_N_* and TILE_SIZE so shared memory stays within GPU limits.
Index size changes: switching tile lists to uint16 requires adapting the buffer upload code on CPU and potentially alignment/padding. This is a worthwhile optimization if you have many tiles or many indices.
Image formats: switching to half float formats may cause slight visual differences; test across target GPUs.
Temporal or multi-resolution approaches significantly reduce cost at high resolution and often give the best user-experience vs cost trade-off.
Suggested profiling steps

Run the shader at a few resolutions (1x, 2x, 4x base) and measure time per dispatch and memory bandwidth.
Turn on GPU counters (DRAM bandwidth, ALU utilization). If memory is near saturation, prioritize bandwidth reductions (packing, lower precision, caching).
If ALU bound, focus on reducing sqrt/divide and complex math; consider approximations.
Iterate: change one optimization at a time and measure impact.
If you want, I can:

Produce a CPU-side change suggested (pack tile lists with uint16, show upload code),
Provide a variant that packs both intensity + direction into one texture and single imageStore,
Add a version that computes light at half resolution and upscales,
Or help tune workgroup sizes for a specific GPU (NVIDIA/AMD/Intel) if you tell me the target hardware.
Which next step would you like to take?
*/

