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

#ifndef N_POINT_LIGHTS_PER_TILE
#error "N_POINT_LIGHTS_PER_TILE undefined"
#endif

#ifndef N_SEGMENT_LIGHTS_PER_TILE
#error "N_SEGMENT_LIGHTS_PER_TILE undefined"
#endif

#if ((TILE_SIZE % WORK_GROUP_SIZE_X) != 0)
#error "TILE_SIZE must be an integer multiple of WORK_GROUP_SIZE_X so workgroups tile-align within a tile"
#endif

#if ((TILE_SIZE % WORK_GROUP_SIZE_Y) != 0)
#error "TILE_SIZE must be an integer multiple of WORK_GROUP_SIZE_Y so workgroups tile-align within a tile"
#endif

#if WORK_GROUP_SIZE_Z != 1
#error "WORK_GROUP_SIZE_Z must be 1"
#endif

#if N_POINT_LIGHTS_PER_TILE > (WORK_GROUP_SIZE_X * WORK_GROUP_SIZE_Y * WORK_GROUP_SIZE_Z)
#error "N_POINT_LIGHTS_PER_TILE larger than work group size"
#endif

#if N_SEGMENT_LIGHTS_PER_TILE > (WORK_GROUP_SIZE_X * WORK_GROUP_SIZE_Y * WORK_GROUP_SIZE_Z)
#error "N_SEGMENT_LIGHTS_PER_TILE larger than work group size"
#endif

layout(std430) readonly buffer tile_data_buffer {
    int tile_data_inline[];
    // layout: n_point_lights | i x N_POINT_LIGHTS_PER_TILE | n_segment_lights | i x N_SEGMENT_LIGHTS_PER_TILE |
};

const int TILE_DATA_STRIDE = 1 + N_POINT_LIGHTS_PER_TILE + 1 + N_SEGMENT_LIGHTS_PER_TILE;
const int SEGMENT_LIGHT_COUNT_OFFSET = 1 + N_POINT_LIGHTS_PER_TILE;
const int SEGMENT_LIGHT_BASE_OFFSET = 1 + N_POINT_LIGHTS_PER_TILE + 1;

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

// workgroup shared memory
shared PointLight shared_point_lights[N_POINT_LIGHTS_PER_TILE];
shared SegmentLight shared_segment_lights[N_SEGMENT_LIGHTS_PER_TILE];

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain() {
    ivec2 image_size = imageSize(light_intensity_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    // base pixel position for this workgroup
    ivec2 work_group_base_position = ivec2(gl_WorkGroupID.xy) * ivec2(WORK_GROUP_SIZE_X, WORK_GROUP_SIZE_Y);
    int tile_offset = xy_to_tile_data_offset(work_group_base_position, image_size);

    int n_point_lights = min(get_n_point_lights(tile_offset), N_POINT_LIGHTS_PER_TILE);
    int n_segment_lights = min(get_n_segment_lights(tile_offset), N_SEGMENT_LIGHTS_PER_TILE);

    uint local_id = gl_LocalInvocationIndex; // id within the same work group
    const int stride = int(WORK_GROUP_SIZE_X * WORK_GROUP_SIZE_Y * WORK_GROUP_SIZE_Z);

    // each local invocation may need to load multiple entries; stride by LOCAL_INVOCATIONS.
    for (int i = int(local_id); i < n_point_lights; i += stride) {
        int light_index = get_point_light_index(tile_offset, i);
        shared_point_lights[i] = point_light_sources[light_index];
    }

    for (int i = int(local_id); i < n_segment_lights; i += stride) {
        int segment_index = get_segment_light_index(tile_offset, i);
        shared_segment_lights[i] = segment_light_sources[segment_index];
    }

    // ensure writes to shared memory are visible to all invocations in this workgroup, then synchronize
    memoryBarrierShared();
    barrier();

    if (any(greaterThanEqual(position, image_size))) return;

    if (imageLoad(mask_texture, position).r == 0) {
        imageStore(light_intensity_texture, position, vec4(1, 1, 1, 0));
        imageStore(light_direction_texture, position, vec4(0, 0, 1, 1));
        return;
    }

    // light rgba
    vec4 point_color = vec4(0.0);
    vec4 segment_color = vec4(0.0);

    // slope for all lights
    vec2 light_direction = vec2(0.0);
    float light_direction_weight = 0.0;

    const float inv_height = 1.0 / LIGHT_Z_HEIGHT;

    // accumulate point lights
    for (int i = 0; i < n_point_lights; ++i) {
        PointLight light = shared_point_lights[i];

        vec2 closest = closest_point_on_disk(vec2(position), light.position, light.radius);
        vec2 direction = closest - vec2(position);
        float dist_squared = dot(direction, direction);

        // color
        vec4 light_contribution = compute_light(light.color, dist_squared);
        point_color += light_contribution;

        // direction
        float luminance = dot(light_contribution.rgb, luma_coefficients);
        light_direction += luminance * (direction * inv_height);
        light_direction_weight += luminance;
    }

    // accumulate segment lights
    for (int i = 0; i < n_segment_lights; ++i) {
        SegmentLight light = shared_segment_lights[i];

        vec2 closest_xy = closest_point_on_segment(vec2(position), light.segment);
        vec2 direction = closest_xy - vec2(position);
        float dist_squared = dot(direction, direction);

        vec4 light_contrib = compute_light(light.color, dist_squared);
        segment_color += light_contrib;

        float luminance = dot(light_contrib.rgb, luma_coefficients);
        light_direction += luminance * (direction * inv_height);
        light_direction_weight += luminance;
    }

    // export rgba
    imageStore(light_intensity_texture, position, tonemap(point_color + segment_color));

    // export mean direction
    light_direction = (light_direction_weight > 0.0) ? (light_direction / light_direction_weight) : vec2(0.0);
    imageStore(light_direction_texture, position, vec4(light_direction, 1.0, 1.0));
}