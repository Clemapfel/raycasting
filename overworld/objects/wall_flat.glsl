vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

#ifndef MAX_N_POINT_LIGHTS
#define MAX_N_POINT_LIGHTS 32
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#define MAX_N_SEGMENT_LIGHTS 32
#endif

uniform vec3 point_light_sources[MAX_N_POINT_LIGHTS]; // in screen coords (px, py, radius)
uniform vec4 point_light_colors[MAX_N_POINT_LIGHTS];
uniform int n_point_light_sources;
uniform float point_light_intensity = 1.2;

uniform vec4 segment_light_sources[MAX_N_SEGMENT_LIGHTS]; // in screen coords (ax, ay, bx, by)
uniform vec4 segment_light_colors[MAX_N_SEGMENT_LIGHTS];
uniform int n_segment_light_sources;
uniform float segment_light_intensity = 0.5;

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform float camera_scale;
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

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

uniform float light_range = 30;

vec4 compute_light(
vec2 screen_uv,
vec2 light_position,
vec4 light_color
) {
    const float sigma = 1.0;

    float dist = distance(light_position, screen_uv) / camera_scale;
    float attenuation = gaussian(dist / light_range, sigma);

    // Clamp attenuation to prevent over-bright values
    attenuation = clamp(attenuation, 0.0, 1.0);

    return light_color * attenuation / 3.0;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    vec4 point_color = vec4(0.0);
    for (int i = 0; i < n_point_light_sources; ++i) {
        vec2 light_circle = point_light_sources[i].xy;
        float light_radius = point_light_sources[i].z;
        vec2 light_position = closest_point_on_circle(screen_coords, light_circle, light_radius);

        // Pre-multiply alpha but clamp the color
        vec4 light_contrib = compute_light(
        screen_coords,
        light_position,
        vec4(point_light_colors[i].rgb, 1.0)  // Don't pre-multiply alpha here
        ) * point_light_colors[i].a;

        point_color += light_contrib;
    }

    vec4 segment_color = vec4(0.0);
    for (int i = 0; i < n_segment_light_sources; ++i) {
        vec4 light_segment = segment_light_sources[i];
        vec2 light_position = closest_point_on_segment(screen_coords, light_segment);

        vec4 light_contrib = compute_light(
        screen_coords,
        light_position,
        vec4(segment_light_colors[i].rgb, 1.0)
        ) * segment_light_colors[i].a;

        segment_color += light_contrib;
    }

    // Clamp accumulated colors before mixing
    point_color = clamp(point_color * point_light_intensity, 0.0, 1.0);
    segment_color = clamp(segment_color * segment_light_intensity, 0.0, 1.0);

    vec4 result = vec4(color.rgb + point_color.rgb + segment_color.rgb, color.a);
    return clamp(result, 0.0, 1.0);
}