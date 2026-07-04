uniform sampler2D light_intensity;
uniform sampler2D light_direction;
vec4 compute_light(in vec2 screen_coords, in vec3 normal_map_normal)
{
    vec4 light_color = texture(light_intensity, screen_coords / love_ScreenSize.xy).rgba;
    vec2 light_dir_2d = texture(light_direction, screen_coords / love_ScreenSize.xy).rg;

    if (light_color.a == 0.0) return vec4(0.0);
    return light_color * max(dot(normal_map_normal, vec3(light_dir_2d, 1.0)), 0.0);
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec3 normal = vec3(0.0, 0.0, 1.0);
    vec4 light = compute_light(screen_coords, normal);
    return vec4(mix(color.rgb, light.rgb, 0.5), color.a);
}