uniform sampler2D light_intensity;
uniform sampler2D light_direction;
uniform mat4x4 screen_to_world_transform;

vec4 compute_light(in vec2 screen_coords, in vec3 normal_map_normal) {
    vec4 light_color = texture(light_intensity, screen_coords / love_ScreenSize.xy).rgba;
    vec2 light_dir_2d = texture(light_direction, screen_coords / love_ScreenSize.xy).rg;

    if (light_color.a == 0.0) return vec4(0.0);
    return light_color * max(dot(normal_map_normal, vec3(light_dir_2d, 1.0)), 0.0);
}

vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

float hexagon_height(vec2 position) {
    const float radius = 1.0;
    const float sqrt3 = 1.73205080757;

    float q = position.x * sqrt3 / 3.0 - position.y / 3.0;
    float r = position.y * 2.0 / 3.0;
    float s = -q - r;

    float rq = round(q);
    float rr = round(r);
    float rs = round(s);

    float q_diff = abs(rq - q);
    float r_diff = abs(rr - r);
    float s_diff = abs(rs - s);

    if (q_diff > r_diff && q_diff > s_diff) rq = -rr - rs;
    else if (r_diff > s_diff) rr = -rq - rs;
    else rs = -rq - rr;

    vec2 hex_center = vec2(sqrt3 * rq + sqrt3 / 2.0 * rr, 3.0 / 2.0 * rr);
    vec2 offset = position - hex_center;

    // Projected distance to apothem edges
    float d1 = abs(offset.y);
    float d2 = abs(offset.x * (sqrt3 / 2.0) + offset.y * 0.5);
    float d3 = abs(-offset.x * (sqrt3 / 2.0) + offset.y * 0.5);

    float max_dist = max(d1, max(d2, d3));
    float apothem = radius * sqrt3 / 2.0;

    return max(apothem - max_dist, 0.0);
}

vec3 calculate_normal(vec2 p, out float height, float steepness) {
    const vec2 e = vec2(0.01, 0.0);
    height = hexagon_height(p);

    float dx = hexagon_height(p + e.xy) - height;
    float dy = hexagon_height(p + e.yx) - height;

    return normalize(vec3(-dx * steepness / e.x, -dy * steepness / e.x, 1.0));
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    float height;
    vec3 normal = calculate_normal(world_position / 30.0, height, 1.5);

    const vec4 ambient_light_color = vec4(1.0);
    const float ambient_light_intensity = 0.3;
    vec3 ambient_light_direction = normalize(vec3(-1.0, -1.0, 0.5));

    float ambient_alignment = max(dot(normal, ambient_light_direction), 0.0);
    vec4 ambient_color = ambient_light_intensity * ambient_alignment * ambient_light_color;

    return vec4((
    color * 0.1 * (1.0 - (1.0 - height)) // Emphasizes hexagonal ridges
    + ambient_color
    + compute_light(screen_coords, normal)
    ).rgb, color.a);
}