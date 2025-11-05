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

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float hexagonal_dome_sdf(vec2 position, float radius, float height, out vec3 surface_normal) {
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

#ifndef MAX_N_POINT_LIGHTS
#define MAX_N_POINT_LIGHTS 32
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#define MAX_N_SEGMENT_LIGHTS 32
#endif

uniform vec2 point_lights[MAX_N_POINT_LIGHTS]; // in screen coords (px, py)
uniform vec4 point_colors[MAX_N_POINT_LIGHTS];
uniform int n_point_lights;

uniform vec4 segment_lights[MAX_N_SEGMENT_LIGHTS]; // in screen coords (ax, ay, bx, by)
uniform vec4 segment_colors[MAX_N_SEGMENT_LIGHTS];
uniform int n_segment_lights;

vec2 closest_point_on_segment(vec2 a, vec2 b, vec2 point) {
    vec2 ab = b - a;
    vec2 ap = point - a;
    float ab_length_squared = dot(ab, ab);
    float t = dot(ap, ab) / ab_length_squared;
    t = clamp(t, 0.0, 1.0);
    return a + t * ab;
}

uniform float elapsed;
uniform vec2 player_position; // screen coords
uniform vec4 player_color;

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    const float tiling_height = 0.4;

    vec3 surface_normal_3d;
    float tiling = hexagonal_dome_sdf(
        world_position / 30,
        1, // radius
        1, // height
        surface_normal_3d
    );

    vec2 surface_normal = surface_normal_3d.xy;

    vec4 point_color = vec4(0);
    for (int i = 1; i < n_point_lights; ++i) {
        vec2 light_position = to_world_position(point_lights[i]);

        float dist = distance(light_position, world_position) / 100.0;
        float attenuation = gaussian(dist, 0.5);

        vec2 light_direction = normalize(light_position - world_position);
        float alignment = max(dot(surface_normal, light_direction), 0);
        float light = alignment * attenuation;
        point_color += light * point_colors[i];
    }

    vec4 segment_color = vec4(0);
    for (int i = 0; i < n_segment_lights; ++i) {
        vec4 segment = segment_lights[i];
        vec2 a_uv = to_world_position(segment.xy);
        vec2 b_uv = to_world_position(segment.zw);
        vec2 light_position = closest_point_on_segment(a_uv, b_uv, world_position);

        float dist = distance(light_position, world_position) / 100.0;
        float attenuation = gaussian(dist, 0.5);

        vec2 light_direction = normalize(light_position - world_position);
        float alignment = max(dot(surface_normal, light_direction), 0);
        float light = alignment * attenuation;
        segment_color += light * segment_colors[i];
    }

    const float segment_light_intensity = 0.2;
    const float point_light_intensity = 1.2;
    const float opacity = 0.8;

    float base = mix(0, 0.5, -tiling);
    return vec4((base * color + mix(
        segment_light_intensity * segment_color,
        point_light_intensity * point_color,
    0.5)).rgb, opacity);
}