#ifdef PIXEL

#ifndef MAX_N_POINT_LIGHTS
#error "MAX_N_POINT_LIGHTS undefined"
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#error "MAX_N_SEGMENT_LIGHTS undefined"
#endif

uniform vec3 point_light_sources[MAX_N_POINT_LIGHTS]; // in screen coords (px, py, radius)
uniform vec4 point_light_colors[MAX_N_POINT_LIGHTS];
uniform int n_point_light_sources;
uniform float point_light_intensity = 1.0;

uniform vec4 segment_light_sources[MAX_N_SEGMENT_LIGHTS]; // in screen coords (ax, ay, bx, by)
uniform vec4 segment_light_colors[MAX_N_SEGMENT_LIGHTS];
uniform int n_segment_light_sources;
uniform float segment_light_intensity = 0.35;

uniform float camera_scale;

vec2 closest_point_on_segment(vec2 xy, vec4 segment) {
    vec2 a = segment.xy;
    vec2 b = segment.zw;
    vec2 ab = b - a;
    float t = dot(xy - a, ab) / dot(ab, ab);
    return a + clamp(t, 0.0, 1.0) * ab;
}

vec2 closest_point_on_circle(vec2 xy, vec2 circle_xy, float radius) {
    vec2 delta = xy - circle_xy;
    if (length(delta) < radius) return circle_xy;
    return circle_xy + normalize(delta) * radius;
}

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

uniform float light_range = 20;

vec4 compute_light(
    vec2 screen_uv,
    vec2 light_position,
    vec4 light_color,
    vec3 normal
) {
    const float sigma = 1.0;

    vec3 light_dir = normalize(vec3(light_position - screen_uv, 0.0));
    float diffuse = max(dot(normal, light_dir), 0.0);

    float dist = distance(light_position, screen_uv) / camera_scale;
    float attenuation = gaussian(dist / light_range, sigma);

    return light_color * diffuse * attenuation;
}

vec4 effect(vec4 vertex_color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 data = Texel(tex, texture_coords);
    float mask = data.a;
    if (mask == 0.0) discard;

    vec2 gradient = normalize((data.yz * 2.0) - 1.0);
    float height = 1.0 - data.x;
    vec3 normal = normalize(vec3(gradient.x, gradient.y, 1.0 - height));

    vec4 point_color = vec4(0.0);
    for (int i = 0; i < n_point_light_sources; ++i) {
        vec2 light_circle = point_light_sources[i].xy;
        float light_radius = point_light_sources[i].z * camera_scale;

        vec2 light_position = closest_point_on_circle(screen_coords, light_circle, light_radius);
        point_color += compute_light(
            screen_coords,
            light_position,
            point_light_colors[i] * point_light_colors[i].a,
            normal
        );
    }

    vec4 segment_color = vec4(0.0);
    for (int i = 0; i < n_segment_light_sources; ++i) {
        vec4 light_segment = segment_light_sources[i];

        vec2 light_position = closest_point_on_segment(screen_coords, light_segment);
        segment_color += compute_light(
            screen_coords,
            light_position,
            segment_light_colors[i] * segment_light_colors[i].a,
            normal
        );
    }

    return vertex_color * mix(
        point_color * point_light_intensity, // * height,
        segment_color * segment_light_intensity * height,
        0.5
    );
}


#endif