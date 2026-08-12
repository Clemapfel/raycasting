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

void square_tiling(vec2 p, out float height, out vec3 normal) {
    p = p / sqrt(2.0);

    vec2 local = fract(p) - 0.5;
    vec2 abs_local = abs(local);

    height = 0.5 - max(abs_local.x, abs_local.y);

    vec2 gradient;
    if (abs_local.x > abs_local.y) {
        gradient = vec2(-sign(local.x), 0.0);
    } else {
        gradient = vec2(0.0, -sign(local.y));
    }

    const float steepness = 1.0;
    normal = normalize(vec3(-gradient * steepness, 1.0));
}

vec2 rotate(vec2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c) * p;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_position = to_world_position(screen_coords);
    world_position = rotate(world_position, radians(45.0));

    float height;
    vec3 normal;
    square_tiling(world_position / 30.0, height, normal);

    const vec4 ambient_light_color = vec4(1.0);
    const float ambient_light_intensity = 0.3;

    vec3 ambient_light_direction = normalize(vec3(-0.8, -0.3, 0.8));

    float ambient_alignment = max(dot(normal, ambient_light_direction), 0.0);
    vec4 ambient_color = ambient_light_intensity * ambient_alignment * ambient_light_color;

    return vec4((
    color * 0.1 * (1.0 - (1.0 - height * 2.0)) // ridge shading
    + ambient_color
    + compute_light(screen_coords, normal)
    ).rgb, color.a);
}