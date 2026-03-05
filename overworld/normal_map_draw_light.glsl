#ifdef PIXEL

uniform sampler2D light_intensity;
uniform sampler2D light_direction;
vec4 compute_light(in vec2 screen_coords, in vec3 normal_map_normal)
{
    vec4 light_color = texture(light_intensity, screen_coords / love_ScreenSize.xy).rgba;
    vec2 light_dir_2d = texture(light_direction, screen_coords / love_ScreenSize.xy).rg;
    vec3 L = normalize(vec3(light_dir_2d, 1.0));
    vec3 N = normalize(normal_map_normal);
    return light_color * max(dot(N, L), 0.0);
}

vec4 effect(vec4 vertex_color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 data = Texel(tex, texture_coords);
    float mask = data.a;
    if (mask == 0.0) discard;

    vec2 gradient = normalize((data.yz * 2.0) - 1.0);
    float height = 1.0 - data.x;
    vec3 normal = normalize(vec3(gradient.x, gradient.y, 1.0 - height));

    return vertex_color * compute_light(screen_coords, normal);
}


#endif