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

    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix(mix(mix(dot(-1 + 2 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
                       dot(-1 + 2 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
                   mix(dot(-1 + 2 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
                       dot(-1 + 2 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
               mix(mix(dot(-1 + 2 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
                       dot(-1 + 2 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
                   mix(dot(-1 + 2 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
                       dot(-1 + 2 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float hexagonal_dome_sdf(vec2 position, out vec3 surface_normal) {
    const float radius = 1;
    const float height = 1;
    const float sqrt3 = 1.7320508075688772;

    float q = position.x * sqrt3 / 3.0 - position.y / 3.0;
    float r = position.y * 2.0 / 3.0;
    float s = -q - r;

    float rq = round(q);
    float rr = round(r);
    float rs = round(s);

    float q_diff = abs(rq - q);
    float r_diff = abs(rr - r);
    float s_diff = abs(rs - s);

    if (q_diff > r_diff && q_diff > s_diff) {
        rq = -rr - rs;
    } else if (r_diff > s_diff) {
        rr = -rq - rs;
    } else {
        rs = -rq - rr;
    }

    vec2 hex_center = vec2(sqrt3 * rq + sqrt3 / 2.0 * rr, 3.0 / 2.0 * rr);
    vec2 offset = position - hex_center;
    float horizontal_dist_sq = dot(offset, offset);
    float radius_sq = radius * radius;

    if (horizontal_dist_sq >= radius_sq) {
        surface_normal = normalize(vec3(0.0, 0.0, 1.0));
        return distance(position, hex_center) / radius;
    }

    float sphere_radius = (radius_sq + height * height) / (2.0 * height);
    float sphere_center_z = sphere_radius - height;
    float z = sphere_center_z + sqrt(sphere_radius * sphere_radius - horizontal_dist_sq);

    vec3 surface_point = vec3(offset.x, offset.y, z);
    vec3 sphere_center = vec3(0.0, 0.0, sphere_center_z);

    surface_normal = normalize(surface_point - sphere_center);
    return distance(position, hex_center) / radius;
}

#define PATTERN_FLAT 0
#define PATTERN_SPHERES 1

#ifndef MAX_N_POINT_LIGHTS
#define MAX_N_POINT_LIGHTS 32
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#define MAX_N_SEGMENT_LIGHTS 32
#endif

uniform vec3 point_light_sources[MAX_N_POINT_LIGHTS];
uniform vec4 point_light_colors[MAX_N_POINT_LIGHTS];
uniform int n_point_light_sources;
uniform float point_light_intensity = 1.2;

uniform vec4 segment_light_sources[MAX_N_SEGMENT_LIGHTS];
uniform vec4 segment_light_colors[MAX_N_SEGMENT_LIGHTS];
uniform int n_segment_light_sources;
uniform float segment_light_intensity = 0.5;

uniform float segment_light_height = 16.0;

uniform float elapsed;
uniform vec2 player_position;
uniform vec4 player_color;

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

vec4 compute_light(vec2 screen_uv, vec2 light_position, float light_height, vec4 light_color, vec3 normal) {
    const float sigma = 1.0;

    vec3 L = vec3(light_position - screen_uv, -max(light_height, 1e-3));
    
    vec3 light_dir = normalize(L);
    float diffuse = max(dot(normal, light_dir), 0.0);

    float dist = length(L) / camera_scale;
    float attenuation = gaussian(dist / light_range, sigma);

    return light_color * diffuse * attenuation;
}

#ifndef PATTERN
#error "PATTERN undefined, should be 0 or 1"
#endif

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    vec3 normal = vec3(0.0, 0.0, -1.0);
    float tiling = 0.5;


    #if PATTERN == PATTERN_SPHERES
        const float tiling_height = 0.4;
        tiling = hexagonal_dome_sdf(world_position / 30.0, normal);
    #endif

    const vec4 ambient_light_color = vec4(1.0);
    const float ambient_light_intensity = 0.3;
    const float ambient_light_time_scale = 0.0;
    vec3 ambient_light_direction = normalize(vec3(
        -1.0, -1.0, mix(-0.25, 0.75, 0.5 * (1.0 + sin(elapsed * ambient_light_time_scale)))
    ));
    float ambient_alignment = max(dot(normal, ambient_light_direction), 0.0);
    vec4 ambient_color = ambient_light_intensity * ambient_alignment * ambient_light_color;

    vec4 point_color = vec4(0.0);
    for (int i = 0; i < n_point_light_sources; ++i) {
        vec3 source = point_light_sources[i]; // .xy = pos, .z = height OR radius
        vec4 col = point_light_colors[i];
        
        vec2 light_pos;
        float light_height;

        #if PATTERN == PATTERN_FLAT
            // Flat: Z is height, use position directly
            light_pos = source.xy;
            light_height = source.z;
        #elif PATTERN == PATTERN_SPHERES
            // Spheres: Z is radius, find closest point on ring, height is standard 1.0
            light_pos = closest_point_on_circle(screen_coords, source.xy, source.z);
            light_height = 1.0;
        #endif

        point_color += compute_light(
            screen_coords, light_pos, light_height, col * col.a, normal
        );
    }

    vec4 segment_color = vec4(0.0);
    for (int i = 0; i < n_segment_light_sources; ++i) {
        vec4 source = segment_light_sources[i];
        vec4 col = segment_light_colors[i];

        vec2 light_pos = closest_point_on_segment(screen_coords, source);
        float light_height;

        #if PATTERN == PATTERN_FLAT
            light_height = segment_light_height;
        #elif PATTERN == PATTERN_SPHERES
            light_height = 1;
        #endif

        segment_color += compute_light(
            screen_coords, light_pos, light_height, col * col.a, normal
        );
    }

    return vec4((
        color * 0.05 * (1.0 - tiling)
        + ambient_color
        + mix(
            point_color * point_light_intensity,
            segment_color * segment_light_intensity,
            0.5
        )
    ).rgb, color.a * 0.8);
}