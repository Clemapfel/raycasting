#pragma language glsl4

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

uniform float light_range = 30;

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

vec2 closest_point_on_segment(vec2 xy, vec4 segment) {
    vec2 a = segment.xy;
    vec2 b = segment.zw;
    vec2 ab = b - a;
    float t = dot(xy - a, ab) / dot(ab, ab);
    return a + clamp(t, 0.0, 1.0) * ab;
}

vec2 closest_point_on_circle(vec2 xy, vec2 circle_xy, float radius) {
    return circle_xy + normalize(xy - circle_xy) * radius;
}

vec4 compute_light(vec2 screen_uv, vec2 light_position, vec4 light_color) {
    const float sigma = 1.0;

    float dist = distance(light_position, screen_uv); // / camera_scale;
    float attenuation = gaussian(dist / light_range, sigma);

    attenuation = clamp(attenuation, 0.0, 1.0);
    return light_color * attenuation / 3.0;
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

vec4 tonemap(vec4 rgba) {
    return clamp(rgba, 0, 1);
}

vec4 effect(vec4 _01, sampler2D _02, vec2 _03, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    vec4 point_color = vec4(0.0);
    for (int i = 0; i < n_point_light_sources; ++i) {
        PointLight light = point_light_sources[i];
        vec2 light_position = closest_point_on_circle(
            world_position,
            light.position,
            light.radius
        );

        point_color += compute_light(world_position, light.position, light.color);
    }

    vec4 segment_color = vec4(0.0);
    for (int i = 1; i < n_segment_light_sources; ++i) {
        SegmentLight light = segment_light_sources[i];
        vec2 light_position = closest_point_on_segment(
            world_position,
            light.segment
        );

        segment_color += compute_light(world_position, light_position, light.color);
    }

    return mix(tonemap(point_color), tonemap(segment_color), 0.5);
}

