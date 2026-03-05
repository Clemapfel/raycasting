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

    const float eps = 1e-7;
    return circle_xy + difference * (radius * inversesqrt(max(length_squared, eps)));
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

/// ### LIGHT COMPUTATION ###

#ifndef LIGHT_INTENSITY_TEXTURE_FORMAT
#error "LIGHT_INTENSITY_TEXTURE_FORMAT undefined"
#endif

#ifndef LIGHT_DIRECTION_TEXTURE_FORMAT
#error "LIGHT_DIRECTION_TEXTURE_FORMAT undefined"
#endif

layout(LIGHT_INTENSITY_TEXTURE_FORMAT) uniform writeonly image2D light_intensity_texture;
// rgb: light color, a: intensity

layout(LIGHT_DIRECTION_TEXTURE_FORMAT) uniform writeonly image2D light_direction_texture;
// rg: light normal

#ifndef LIGHT_RANGE
#error "LIGHT_RANGE undefined"
#endif

// tonemap multiplie
uniform float intensity = 1;

// slope of 3d light plane for normal computation, in px
uniform float light_z_height = 256;

// rgb weights for luminance computation
const vec3 luma_coefficients = vec3(0.2126, 0.7152, 0.0722); // BT.709

float gaussian(float x) {
    return 1.0 / (1.0 + 0.5 * x * x * x); // gaussian approximation
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
    vec3 hdr = color.rgb * intensity;
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

    float inv_height = 1.0 / light_z_height;

    // accumulate point lights
    for (int i = 0; i < n_point_lights; ++i) {
        int point_light_index = get_point_light_index(tile_offset, i);
        PointLight light = point_light_sources[point_light_index];

        vec2 to_center = light.position - vec2(position);
        float dist_squared = dot(to_center, to_center);

        // accumulate color
        vec4 light_contrib = compute_light(light.color, dist_squared);
        point_color += light_contrib;

        // accumulate direction
        vec2 closest_xy = closest_point_on_disk(vec2(position), light.position, light.radius);
        vec2 direction = closest_xy - vec2(position);

        float luminance = dot(light_contrib.rgb, luma_coefficients);
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

