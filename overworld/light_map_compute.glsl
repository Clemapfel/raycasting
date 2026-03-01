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

#ifndef MASK_TEXTURE_FORMAT
#error "MASK_TEXTURE_FORMAT undefined"
#endif

// point lights

struct PointLight {
    vec2 position; // in screen space
    float radius;
    vec4 color;
};

uniform int n_point_light_sources = 0;
layout(std430) readonly buffer point_light_source_buffer {
    PointLight point_light_sources[];
};

// segment lights

struct SegmentLight {
    vec4 segment; // in screen space
    vec4 color;
};

uniform int n_segment_light_sources = 0;
layout(std430) readonly buffer segment_light_sources_buffer {
    SegmentLight segment_light_sources[];
};

// camera transform

const float light_range = 30;

// output textures
layout(LIGHT_INTENSITY_TEXTURE_FORMAT) uniform writeonly image2D light_intensity_texture;
layout(LIGHT_DIRECTION_TEXTURE_FORMAT) uniform writeonly image2D light_direction_texture;
layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;

const float sigma = 1.0;
float gaussian(float x) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

vec2 closest_point_on_segment(vec2 xy, vec4 segment) {
    vec2 ab = segment.zw - segment.xy;
    float t = clamp(dot(xy - segment.xy, ab) / dot(ab, ab), 0.0, 1.0);
    return segment.xy + t * ab;
}

vec2 closest_point_on_circle(vec2 xy, vec2 circle_xy, float radius) {
    return circle_xy + normalize(xy - circle_xy) * radius;
}

vec4 compute_light(vec2 screen_uv, vec2 light_position, vec4 light_color) {
    float dist = distance(light_position, screen_uv);
    float attenuation = clamp(gaussian(dist / light_range), 0.0, 1.0);
    return light_color * (attenuation / 3.0);
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

const vec3 luma_coefficients = vec3(0.299, 0.587, 0.114);
vec4 tonemap(vec4 rgba) {
    return clamp(rgba, 0.0, 1.0);
}

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain() {
    ivec2 image_size = imageSize(light_intensity_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(position, image_size))) return;
    if (imageLoad(mask_texture, position).r == 0) return;

    vec2 world_position = to_world_position(position);

    vec4 point_color = vec4(0.0);
    vec2 point_directional = vec2(0.0);

    float light_range_cutoff = 2.5 * light_range;

    for (int i = 0; i < n_point_light_sources; ++i) {
        PointLight light = point_light_sources[i];
        if (distance(world_position, light.position) > light_range_cutoff) continue;

        vec2 light_position = closest_point_on_circle(
            world_position,
            light.position,
            light.radius
        );

        vec4 light_contrib = compute_light(world_position, light.position, light.color);
        point_color += light_contrib;

        vec2 light_dir_2d = normalize(light_position - world_position);
        float luminance = dot(light_contrib.rgb, luma_coefficients);

        point_directional.x += luminance * max(0.0, light_dir_2d.x);
        point_directional.y += luminance * max(0.0, light_dir_2d.y);
    }

    vec4 segment_color = vec4(0.0);
    vec2 segment_directional = vec2(0.0);

    for (int i = 0; i < n_segment_light_sources; ++i) {
        SegmentLight light = segment_light_sources[i];

        vec2 light_position = closest_point_on_segment(
            world_position,
            light.segment
        );

        vec4 light_contrib = compute_light(world_position, light_position, light.color);
        segment_color += light_contrib;

        vec2 light_dir_2d = normalize(light_position - world_position);
        float luminance = dot(light_contrib.rgb, luma_coefficients);

        segment_directional.x += luminance * max(0.0, light_dir_2d.x);
        segment_directional.y += luminance * max(0.0, light_dir_2d.y);
    }

    imageStore(light_intensity_texture,
        position,
        mix(tonemap(point_color), tonemap(segment_color), 0.5)
    );

    /*
    imageStore(light_direction_texture,
        position,
        vec4(mix(point_directional, segment_directional, 0.5).rg, 1, 1)
    );
    */
}

