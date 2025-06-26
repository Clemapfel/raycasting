#ifdef PIXEL

#define MODE_LIGHTING 0
#define MODE_SHADOW 1

#ifndef MODE
#error "MODE should be 0 or 1"
#endif

#if MODE == MODE_LIGHTING

uniform vec2 player_position; // in screen coords
uniform vec4 player_color;
uniform float range = 50;

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#endif

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) // tex is RG8
{
    vec4 data = texture(tex, texture_coords);
    float mask = data.a;
    if (mask == 0) discard;

    vec2 gradient = normalize((data.yz * 2) - 1); // normalized gradient
    float dist = data.x; // normalized distance;


    #if MODE == MODE_LIGHTING

    float attenuation = 1 - min(distance(player_position, screen_coords) / range, 1);
    vec2 light_direction = normalize(player_position - screen_coords);
    float alignment = max(dot(gradient, light_direction), 0.0); // 1 = perfectly aligned, 0 = perpendicular or away
    float light = alignment * attenuation;

    return vec4(hsv_to_rgb(vec3((atan(gradient.y, gradient.x) + 3.14159) / (2 * 3.14159), 1, 1)), 1);
    return color * vec4(vec3(light * player_color.rgb), 1) * (1 - dist);

    #elif MODE == MODE_SHADOW

    return mix(vec4(0), color, dist);

    #elif MODE == MODE_DEBUG

    return vec4(hsv_to_rgb(vec3((atan(gradient.y, gradient.x) + 3.14159) / (2 * 3.14159), 1, 1)), 1);

    #endif
}

#endif