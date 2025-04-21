uniform vec2 camera_offset;
uniform float camera_scale = 1;

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#ifndef MAX_N_COINS
#error "In coin_effect.glsl: MAX_N_COINS is not defined"
#endif

uniform vec2 coin_positions[MAX_N_COINS];
uniform vec4 coin_colors[MAX_N_COINS];
uniform float coin_elapsed[MAX_N_COINS];
uniform uint coin_is_active[MAX_N_COINS];
uniform int n_coins;

uniform float elapsed;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {
    vec2 origin = 0.5 * love_ScreenSize.xy;

    vec2 uv = frag_position;
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;

    vec4 value = vec4(0);
    float eps = 0.1;
    float inner_radius = 0.05;
    float outer_radius_delta = 0.15;

    const float duration = 3;
    const float warp_strength = 1;

    for (int i = 0; i < n_coins; ++i) {
        if (coin_is_active[i] != 1u) continue;

        vec4 color = coin_colors[i];

        vec2 position = coin_positions[i];
        vec2 delta = position - uv;
        delta.x *= love_ScreenSize.x / love_ScreenSize.y;
        delta /= love_ScreenSize.xy;

        float dist = length(delta);
        float time = coin_elapsed[i] / 2;
        float outer_radius = inner_radius + mix(0.05, 0.7, coin_elapsed[i] / duration);
        float inner = smoothstep(inner_radius, inner_radius + eps, dist - time + outer_radius);
        float outer = smoothstep(outer_radius, outer_radius + eps, dist - time + outer_radius);
        value += (inner - outer) * color * (1 - min(coin_elapsed[i] / duration, 1));
    }

    vec4 texel = texture(image, texture_coords + vec2(dFdx(value.a), dFdy(value.a)) * warp_strength);
    return vec4(mix(texel.rgb, value.rgb, value.a), texel.a);
}