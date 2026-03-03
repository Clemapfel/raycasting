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

uniform sampler2D light_intensity;
uniform sampler2D light_direction;
vec4 compute_light(in vec2 screen_coords, in vec3 normal_map_normal)
{
    vec4 light_color = texture(light_intensity, screen_coords / love_ScreenSize.xy).rgba;
    vec2 light_dir_2d = texture(light_direction, screen_coords / love_ScreenSize.xy).rg;

    if (dot(light_color, light_color) == 0.0)
    return vec4(0.0);

    vec3 L = normalize(vec3(light_dir_2d, 1.0));
    vec3 N = normalize(normal_map_normal);
    return light_color * max(dot(N, L), 0.0);
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform float elapsed;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    const float tiling_height = 0.4;

    vec3 normal;
    float tiling = hexagonal_dome_sdf(world_position / 30, normal);

    const vec4 ambient_light_color = vec4(1);
    const float ambient_light_intensity = 0.3;
    vec3 ambient_light_direction = normalize(vec3(
        -1, -1, mix(-0.25, 0.75, 0.5 * gradient_noise(vec3(to_world_position(screen_coords) / 10, elapsed)))
    ));
    float ambient_alignment = max(dot(normal, ambient_light_direction), 0.0);
    vec4 ambient_color = ambient_light_intensity * ambient_alignment * ambient_light_color;

    return vec4((
        color * 0.05 * (1 - tiling)
        + ambient_color
        + compute_light(screen_coords, normal)
    ).rgb, color.a);
}