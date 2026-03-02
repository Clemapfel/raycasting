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

float gaussian(float x) {
    float x2 = x * x * x; // gaussian approximation
    return 1.0 / (1.0 + 0.5 * x2);
}

vec2 closest_point_on_segment(vec2 xy, vec4 segment) {
    vec2 ab = segment.zw - segment.xy;
    vec2 ap = xy - segment.xy;
    float t = clamp(dot(ap, ab) * inversesqrt(dot(ab, ab) * dot(ab, ab)), 0.0, 1.0);
    return segment.xy + t * ab;
}

vec2 closest_point_on_circle(vec2 xy, vec2 circle_xy, float radius) {
    vec2 diff = xy - circle_xy;
    return circle_xy + diff * (radius * inversesqrt(dot(diff, diff)));
}

vec4 compute_light(vec2 screen_uv, vec2 light_position, vec4 light_color, float dist_sq) {
    float dist = sqrt(dist_sq);
    float attenuation = clamp(gaussian(dist * inversesqrt(light_range * light_range)), 0.0, 1.0);
    const float third = 1.0 / 3.0;
    return light_color * (attenuation * third);
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy * inversesqrt(result.w * result.w);
}

const vec3 luma_coefficients = vec3(1, 1, 1); //0.299, 0.587, 0.114);
vec4 tonemap(vec4 rgba) {
    return clamp(rgba, 0.0, 1.0);
}

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain() {
    ivec2 image_size = imageSize(light_intensity_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(position, image_size))) return;
    if (imageLoad(mask_texture, position).r == 0.0) return;

    vec2 world_position = to_world_position(position);

    vec4 point_color = vec4(0.0);
    vec2 point_directional = vec2(0.0);

    float light_range_sq = light_range * light_range;
    float light_range_cutoff = 6.25 * light_range_sq; // 2.5^2

    for (int i = 0; i < n_point_light_sources; ++i) {
        PointLight light = point_light_sources[i];

        vec2 to_light = light.position - world_position;
        float dist = dot(to_light, to_light);

        vec2 light_position = light.position - to_light * (light.radius * inversesqrt(dist));

        vec4 light_contrib = compute_light(world_position, light.position, light.color, dist);
        point_color += light_contrib;

        vec2 light_dir_2d = (light_position - world_position) * inversesqrt(dot(light_position - world_position, light_position - world_position));
        float luminance = dot(light_contrib.rgb, luma_coefficients);

        point_directional += luminance * max(vec2(0.0), light_dir_2d);
    }

    vec4 segment_color = vec4(0.0);
    vec2 segment_directional = vec2(0.0);

    for (int i = 0; i < n_segment_light_sources; ++i) {
        SegmentLight light = segment_light_sources[i];

        vec2 light_position = closest_point_on_segment(world_position, light.segment);

        vec2 to_light = light_position - world_position;
        float dist = dot(to_light, to_light);

        vec4 light_contrib = compute_light(world_position, light_position, light.color, dist);
        segment_color += light_contrib;

        vec2 light_dir_2d = to_light * inversesqrt(dist);
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