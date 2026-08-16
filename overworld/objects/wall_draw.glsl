uniform sampler2D wall_texture; // xyz: normal, w: height
uniform sampler2D light_intensity; // rgba: color
uniform sampler2D light_direction; // xy: direction

vec4 compute_light(in vec2 screen_coords, in vec3 normal_map_normal)
{
    vec4 light_color = texture(light_intensity, screen_coords / love_ScreenSize.xy).rgba;
    vec2 light_dir_2d = texture(light_direction, screen_coords / love_ScreenSize.xy).rg;
    if (light_color.a == 0.0) return vec4(0.0);
    return light_color * max(dot(normal_map_normal, vec3(light_dir_2d, 1.0)), 0.0);
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform float elapsed;
uniform vec4 ambient; // xyz: direction, w: intensity

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    const float tiling_height = 0.4;

    vec4 data = texture(wall_texture, texture_coords);
    vec3 normal = normalize(data.xyz * 2.0 - 1.0);
    float height = data.w;

    const vec4 ambient_light_color = vec4(1.0);

    float ambient_alignment = max(dot(normal, normalize(ambient.xyz)), 0.0);
    vec4 ambient_color = ambient.w * ambient_alignment * ambient_light_color;

    return vec4((
    color.rgba * (1.0 - height)
    + ambient_color
    + compute_light(screen_coords, normal)
    ).rgb, color.a);
}