#ifdef PIXEL

#define MODE_LIGHTING 0
#define MODE_SHADOW 1

#ifndef MODE
#error "MODE should be 0 or 1"
#endif

#if MODE == MODE_LIGHTING

#define MAX_N_LIGHTS 16

uniform vec2 positions[MAX_N_LIGHTS]; // in screen coords
uniform vec4 colors[MAX_N_LIGHTS];
uniform int n_lights;

uniform vec2 camera_offset;
uniform float camera_scale = 1;
vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#endif

vec4 effect(vec4 vertex_color, Image tex, vec2 texture_coords, vec2 screen_coords) // tex is RG8
{
    vec4 data = texture(tex, texture_coords);
    float mask = data.a;
    if (mask == 0) discard;

    vec2 gradient = normalize((data.yz * 2) - 1); // normalized gradient
    float dist = data.x; // normalized distance;

    #if MODE == MODE_LIGHTING
    vec4 final_color = vec4(0);

    vec2 screen_uv = to_uv(screen_coords);
    for (int i = 0; i < n_lights; ++i) {
        vec2 position = to_uv(positions[i]);
        vec4 color = colors[i];

        float attenuation = gaussian(distance(position, screen_uv) * 2, 3.7); // range
        vec2 light_direction = normalize(position - screen_coords);
        float alignment = max(dot(gradient, light_direction), 0.0);
        float light = alignment * attenuation;
        final_color += vec4(vec3(light * color.rgb), 1) * (1 - dist);
    }

    return vertex_color * final_color;

    #elif MODE == MODE_SHADOW

    return vertex_color * mix(vec4(0), vec4(1), dist);

    #endif
}

#endif