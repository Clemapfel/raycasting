#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X undefined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y undefined"
#endif

#ifndef WORK_GROUP_SIZE_Z
#error "WORK_GROUP_SIZE_Z undefined"
#endif

#ifndef LIGHT_INTENSITY_TEXTURE_FORMAT
#error "LIGHT_INTENSITY_TEXTURE_FORMAT undefined"
#endif

#ifndef LIGHT_DIRECTION_TEXTURE_FORMAT
#error "LIGHT_DIRECTION_TEXTURE_FORMAT undefined"
#endif

#ifndef MAX_N_POINT_LIGHTS
#error "MAX_N_POINT_LIGHTS undefined"
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#error "MAX_N_SEGMENT_LIGHTS undefined"
#endif

#ifndef LIGHT_RANGE
#error "LIGHT_RANGE undefined"
#endif

// Precompute inverse light range to avoid repeated divisions or inversesqrt on a constant
const float INV_LIGHT_RANGE = 1.0 / float(LIGHT_RANGE);

struct PointLight {
    vec2 position; // in screen space
    float radius;
    vec4 color;
};

layout(std430) readonly buffer point_light_source_buffer {
    PointLight point_light_sources[];
}; // size: MAX_N_POINT_LIGHTS

// segment lights

struct SegmentLight {
    vec4 segment; // in screen space
    vec4 color;
};

layout(std430) readonly buffer segment_light_sources_buffer {
    SegmentLight segment_light_sources[];
}; // size: MAX_N_SEGMENT_LIGHTS


layout(LIGHT_INTENSITY_TEXTURE_FORMAT) uniform writeonly image2D light_intensity_texture;
layout(LIGHT_DIRECTION_TEXTURE_FORMAT) uniform writeonly image2D light_direction_texture;

float gaussian(float x) {
    // Approximate gaussian falloff; compute x^3 via two multiplies
    float x2 = x * x;
    float x3 = x2 * x;
    return 1.0 / (1.0 + 0.5 * x3);
}

vec2 closest_point_on_segment(vec2 xy, vec4 segment) {
    vec2 ab = segment.zw - segment.xy;
    float ab_len2 = dot(ab, ab);

    if (ab_len2 == 0.0)
        return segment.xy;

    vec2 ap = xy - segment.xy;

    float inv_ab_len2 = inversesqrt(ab_len2 * ab_len2);
    float t = clamp(dot(ap, ab) * inv_ab_len2, 0.0, 1.0);
    return segment.xy + t * ab;
}

const float eps = 1e-7;

vec2 closest_point_on_circle(vec2 xy, vec2 circle_xy, float radius) {
    vec2 diff = xy - circle_xy;
    float len2 = dot(diff, diff);
    float inv_len = inversesqrt(max(len2, eps));
    return circle_xy + diff * (radius * inv_len);
}

vec4 compute_light(vec4 light_color, float dist_sq) {
    // Use precomputed 1 / LIGHT_RANGE; keep behavior identical
    float dist = sqrt(dist_sq);
    float attenuation = clamp(gaussian(dist * INV_LIGHT_RANGE), 0.0, 1.0);
    const float third = 1.0 / 3.0;
    return light_color * (attenuation * third);
}


const vec3 luma_coefficients = vec3(0.299, 0.587, 0.114);

uniform float intensity = 1;
vec4 tonemap(vec4 color) {
    vec3 hdr = color.rgb * intensity;
    vec3 mapped = hdr / (hdr + vec3(1.0));
    return vec4(clamp(mapped, 0.0, 1.0), color.a);
}

layout(std430) readonly buffer tile_data_buffer {
    int tile_data_inline[];
    // n_point_lights, MAX_N_POINT_LIGHTS integers, n_segment_lights, MAX_N_SEGMENT_LIGHTS integers
};

#ifndef TILE_SIZE
#error "TILE_SIZE undefined"
#endif

#ifndef MAX_N_POINT_LIGHTS
#error "MAX_N_POINT_LIGHTS undefined"
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#error "MAX_N_SEGMENT_LIGHTS undefined"
#endif

const int TILE_DATA_STRIDE = 2 + MAX_N_POINT_LIGHTS + MAX_N_SEGMENT_LIGHTS;

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
    return tile_data_inline[tile_offset + 1 + MAX_N_POINT_LIGHTS];
}

int get_segment_light_index(int tile_offset, int i) {
    return tile_data_inline[tile_offset + 2 + MAX_N_POINT_LIGHTS + i];
}

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain() {
    ivec2 image_size = imageSize(light_intensity_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(position, image_size))) return;

    int tile_offset = xy_to_tile_data_offset(position, image_size);
    int n_point_lights = get_n_point_lights(tile_offset);
    int n_segment_lights = get_n_segment_lights(tile_offset);

    vec4 point_color = vec4(0.0);
    vec2 point_directional = vec2(0.0);

    for (int i = 0; i < n_point_lights; ++i) {
        int point_light_index = get_point_light_index(tile_offset, i);
        PointLight light = point_light_sources[point_light_index];

        vec2 to_light = light.position - vec2(position);
        float dist_sq = dot(to_light, to_light);

        vec2 closest = closest_point_on_circle(
            vec2(position),
            light.position,
            light.radius
        );

        vec4 light_contrib = compute_light(light.color, dist_sq);
        point_color += light_contrib;

        vec2 to_edge = closest - vec2(position);
        vec2 light_dir_2d = to_edge * inversesqrt(max(dot(to_edge, to_edge), eps));

        float luminance = dot(light_contrib.rgb, luma_coefficients);
        point_directional += luminance * max(vec2(0.0), light_dir_2d);
    }

    vec4 segment_color = vec4(0.0);
    vec2 segment_directional = vec2(0.0);

    for (int i = 0; i < n_segment_lights; ++i) {
        int segment_light_index = get_segment_light_index(tile_offset, i);
        SegmentLight light = segment_light_sources[segment_light_index];

        vec2 closest_point = closest_point_on_segment(vec2(position), light.segment);
        vec2 to_light = closest_point - vec2(position);
        float dist_sq = dot(to_light, to_light);

        vec4 light_contrib = compute_light(light.color, dist_sq);
        segment_color += light_contrib;

        vec2 light_dir_2d = to_light * inversesqrt(max(dist_sq, eps));

        float luminance = dot(light_contrib.rgb, luma_coefficients);
        segment_directional += luminance * max(vec2(0.0), light_dir_2d);
    }

    imageStore(light_intensity_texture,
        position,
        tonemap(point_color + segment_color)
    );

    imageStore(light_direction_texture,
        position,
        vec4(mix(point_directional, segment_directional, 0.5), 1.0, 1.0)
    );
}