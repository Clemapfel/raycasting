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

vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}
// Returns the surface normal of a spherical dome at a given point
// The dome has a given radius and height, centered at origin
// Returns the surface normal of a spherical dome at a given point
// The dome has a given radius footprint and height, centered at origin
vec3 get_dome_normal(vec2 point, float radius, float height, vec2 origin) {
    vec2 offset = point - origin;
    float horizontal_dist_sq = dot(offset, offset);
    float radius_sq = radius * radius;

    // Clamp to avoid numerical issues at the edge
    if (horizontal_dist_sq >= radius_sq) {
        // At or beyond the edge - return upward normal
        return vec3(0.0, 0.0, 1.0);
    }

    // The dome is a section of a sphere with a specific radius of curvature
    // We need to find the sphere radius R such that:
    // - The dome has footprint radius 'radius'
    // - The dome has apex height 'height'
    // From geometry: R^2 = radius^2 + (R - height)^2
    // Solving: R = (radius^2 + height^2) / (2 * height)
    float sphere_radius = (radius_sq + height * height) / (2.0 * height);

    // The sphere center is at (origin.x, origin.y, sphere_radius - height)
    float sphere_center_z = sphere_radius - height;

    // Calculate z-coordinate on the sphere surface
    float z = sphere_center_z + sqrt(sphere_radius * sphere_radius - horizontal_dist_sq);

    // Normal points from sphere center to surface point
    vec3 surface_point = vec3(offset.x, offset.y, z);
    vec3 sphere_center = vec3(0.0, 0.0, sphere_center_z);
    vec3 normal = surface_point - sphere_center;

    return normalize(normal);
}

// Returns the center of the nearest hexagonal cell in a flat-topped hexagonal tiling
// Assumes unit hexagon size (distance between cell centers = 1.0)
vec2 get_nearest_hex_center(vec2 position) {
    // Hexagonal grid constants for flat-topped hexagons
    const float sqrt3 = 1.7320508075688772;
    const float hex_width = 2.0 / sqrt3;
    const float hex_height = 1.0;

    // Convert to axial coordinates (q, r)
    float q = position.x * sqrt3 / 3.0 - position.y / 3.0;
    float r = position.y * 2.0 / 3.0;

    // Convert to cube coordinates (q, r, s) where q + r + s = 0
    float s = -q - r;

    // Round to nearest integer cube coordinates
    float rq = round(q);
    float rr = round(r);
    float rs = round(s);

    // Ensure constraint q + r + s = 0 after rounding
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

    // Convert back to world coordinates
    float x = (sqrt3 * rq + sqrt3 / 2.0 * rr);
    float y = (3.0 / 2.0 * rr);

    return vec2(x, y);
}

vec3 get_normal(vec2 position, float radius, float height, out float sdf) {
    // Find the center of the nearest hexagonal cell
    vec2 hex_center = get_nearest_hex_center(position);

    // Get the dome normal at this position relative to the hex center
    vec3 normal = get_dome_normal(position, radius, height, hex_center);
    sdf = distance(position, hex_center) / radius;

    return normal;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform float elapsed;
uniform vec2 player_position; // screen coords
uniform vec4 player_color;
uniform mat4x4 screen_to_world_transform;

#ifndef MAX_N_POINT_LIGHTS
#define MAX_N_POINT_LIGHTS 32
#endif


#ifndef MAX_N_SEGMENT_LIGHTS
#define MAX_N_SEGMENT_LIGHTS 32
#endif

uniform vec2 point_lights[MAX_N_POINT_LIGHTS]; // in screen coords (px, py)
uniform vec4 point_colors[MAX_N_POINT_LIGHTS];
uniform int n_point_lights; // clamped before being send to shader

uniform vec4 segment_lights[MAX_N_SEGMENT_LIGHTS]; // in screen coords (ax, ay, bx, by)
uniform vec4 segment_colors[MAX_N_SEGMENT_LIGHTS];
uniform int n_segment_lights; // see n_point_lights

vec2 closest_point_on_segment(vec2 a, vec2 b, vec2 point) {
    vec2 ab = b - a;
    vec2 ap = point - a;
    float ab_length_squared = dot(ab, ab);
    float t = dot(ap, ab) / ab_length_squared;
    t = clamp(t, 0.0, 1.0);
    return a + t * ab;
}

uniform vec4 outline_color;

vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 screen_pos = to_world_position(screen_coords);

    const float noise_scale = 1.0 / 100;
    const float noise_amplitude = 5; // world pos px
    float time = elapsed * 0.25;
    float noise_x = gradient_noise(vec3(screen_pos * noise_scale, time));
    float noise_y = gradient_noise(vec3((screen_pos * noise_scale).xy * -1, time));

    const float tiling_height = 0.4;

    float tiling;
    vec2 surface_normal = get_normal(
    (screen_pos + vec2(noise_x, noise_y) * noise_amplitude) / 30,
    1, // radius
    1, // height
    tiling // sdf
    ).xy;

    vec4 point_color = vec4(0);
    for (int i = 1; i < n_point_lights; ++i) {
        vec2 light_pos = to_world_position(point_lights[i]);
        float dist = distance(light_pos, screen_pos) / 100.0;
        float attenuation = gaussian(dist, 0.5);
        vec2 light_direction = normalize(light_pos - screen_pos);
        float alignment = max(dot(surface_normal, light_direction), 0);
        float light = alignment * attenuation;
        point_color += light * point_colors[i];
    }

    vec4 segment_color = vec4(0);
    for (int i = 0; i < n_segment_lights; ++i) {
        vec4 segment = segment_lights[i];
        vec2 a_uv = to_world_position(segment.xy);
        vec2 b_uv = to_world_position(segment.zw);
        vec2 light_pos = closest_point_on_segment(a_uv, b_uv, screen_pos);

        float dist = distance(light_pos, screen_pos) / 100.0;
        float attenuation = gaussian(dist, 0.5);
        vec2 light_direction = normalize(light_pos - screen_pos);
        float alignment = max(dot(surface_normal, light_direction), 0);
        float light = alignment * attenuation;
        segment_color += light * segment_colors[i];
    }

    float base = mix(0, 0.5, -tiling);
    return vec4((base * color + mix(0.2 * segment_color, 1.2 * point_color, 0.5)).rgb, 0.8);
}