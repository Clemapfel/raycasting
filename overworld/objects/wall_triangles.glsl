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

void triangle_tiling(vec2 p, out float height, out vec3 normal) {
    const float H_half = 0.5;
    const float sqrt3_2 = sqrt(3.0) / 2.0;

    p = p / sqrt(3.0);

    float u1 = fract(p.y + H_half) - H_half;
    float d1 = abs(u1);
    vec2 grad1 = vec2(0.0, sign(u1));

    float v2 = p.x * sqrt3_2 + p.y * 0.5;
    float u2 = fract(v2 + H_half) - H_half;
    float d2 = abs(u2);
    vec2 grad2 = vec2(sqrt3_2, 0.5) * sign(u2);

    float v3 = -p.x * sqrt3_2 + p.y * 0.5;
    float u3 = fract(v3 + H_half) - H_half;
    float d3 = abs(u3);
    vec2 grad3 = vec2(-sqrt3_2, 0.5) * sign(u3);

    height = min(d1, min(d2, d3));

    vec2 active_grad = grad1;
    if (d2 < d1 && d2 < d3) active_grad = grad2;
    else if (d3 < d1 && d3 < d2) active_grad = grad3;

    const float steepness = 0.5;
    normal = normalize(vec3(-active_grad * steepness, 1.0));
}

vec2 rotate(vec2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c) * p;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);

    float height;
    vec3 normal;

    world_position = rotate(world_position, radians(60.0));
    triangle_tiling(world_position / 30.0, height, normal);

    const vec4 ambient_light_color = vec4(1.0);
    const float ambient_light_intensity = 0.3;
    vec3 ambient_light_direction = normalize(vec3(-1.0, -1.0, 0.5));

    float ambient_alignment = max(dot(normal, ambient_light_direction), 0.0);
    vec4 ambient_color = ambient_light_intensity * ambient_alignment * ambient_light_color;

    return vec4((
    color * 0.1 * (1.0 - (1.0 - height * 2.0))
    + ambient_color
    + compute_light(screen_coords, normal)
    ).rgb, color.a);
}