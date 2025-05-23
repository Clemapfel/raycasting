uniform vec2 camera_offset;
uniform float camera_scale = 1;

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

vec2 turn(vec2 v, bool left_or_right) {
    if (left_or_right) {
        return vec2(v.y, -v.x);
    } else {
        return vec2(-v.y, v.x);
    }
}

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

#ifndef MAX_N_COINS
#error "In coin_effect.glsl: MAX_N_COINS is not defined"
#endif

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

uniform vec2 coin_positions[MAX_N_COINS];
uniform vec4 coin_colors[MAX_N_COINS];
uniform float coin_elapsed[MAX_N_COINS];
uniform uint coin_is_active[MAX_N_COINS];
uniform int n_coins;

uniform float elapsed;
uniform vec2 player_position;
uniform vec4 player_color;
uniform float player_pulse_elapsed;

uniform sampler2D bubble_mask;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {
    vec2 origin = 0.5 * love_ScreenSize.xy;

    vec2 uv = frag_position;
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;

    vec4 value = vec4(0);
    vec4 static_value = vec4(0);
    vec2 uv_offset = vec2(0);

    { // coin post fx

        float eps = 0.01;
        float inner_radius = 0.05;

        const float duration = 0.8;
        float static_radius = 10 / love_ScreenSize.x;
        float static_eps = 0.025;
        float warp_value = 0;

        for (int i = 0; i < n_coins; ++i) {
            if (coin_is_active[i] != 1u) continue;

            vec4 color = coin_colors[i];

            vec2 position = coin_positions[i];
            vec2 delta = position - uv;
            delta.x *= love_ScreenSize.x / love_ScreenSize.y;
            delta /= love_ScreenSize.xy;

            float dist = length(delta);

            float time = pow(coin_elapsed[i], 2) * (1 / 1.5);
            float outer_radius = inner_radius + mix(0.05, 0.4, coin_elapsed[i] / duration);
            float inner = smoothstep(inner_radius, inner_radius + eps, dist - time + outer_radius);
            float outer = smoothstep(outer_radius, outer_radius + eps, dist - time + outer_radius);

            float time_factor = (1 - min(coin_elapsed[i] / duration, 1));

            value += (inner - outer) * color * time_factor;
            static_value += (smoothstep(static_radius + static_eps, static_radius - static_eps, dist)) * time_factor;

            warp_value += gaussian(dist - time, 3) * time_factor;
        }

        uv_offset += vec2(dFdx(warp_value), dFdy(warp_value));
    }

    vec4 texel = texture(image, texture_coords + uv_offset);
    vec4 result = vec4(mix(texel.rgb, value.rgb, value.a), texel.a);

    return result;
}