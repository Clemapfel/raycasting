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

float worley_noise(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float dist = 1.0;
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(i, j, k);

                vec3 p = n + g;
                p = fract(p * vec3(0.1031, 0.1030, 0.0973));
                p += dot(p, p.yxz + 19.19);
                vec3 o = fract((p.xxy + p.yzz) * p.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);
                dist = min(dist, d);
            }
        }
    }

    return 1 - dist;
}

/// @brief bayer dithering
/// @source adapted from https://www.shadertoy.com/view/WstXR8
vec3 dither_4x4(vec3 color_a, vec3 color_b, float mix_fraction, vec2 screen_position) {
    const mat4 bayer_4x4 = mat4(
        0.0 / 16.0, 12.0 / 16.0,  3.0 / 16.0, 15.0 / 16.0,
        8.0 / 16.0,  4.0 / 16.0, 11.0 / 16.0,  7.0 / 16.0,
        2.0 / 16.0, 14.0 / 16.0,  1.0 / 16.0, 13.0 / 16.0,
        10.0 / 16.0,  6.0 / 16.0,  9.0 / 16.0,  5.0 / 16.0
    );

    vec3 color = mix(color_a, color_b, mix_fraction);
    color = pow(color.rgb, vec3(2.2)) - 0.004; // gamma correction
    int col_i = int(mod(screen_position.x, 4));
    int row_i = int(mod(screen_position.y, 4));
    float bayer_value = bayer_4x4[col_i][row_i];
    return vec3(step(bayer_value,color.r), step(bayer_value,color.g), step(bayer_value,color.b));
}

#define PI 3.1415926535897932384626433832795

uniform float elapsed;

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#define N_COLORS 5u
uniform vec3 color_a;
uniform vec3 color_b;
uniform vec3 color_c;
uniform vec3 color_d;
uniform vec3 color_e;
vec3 palette[N_COLORS] = vec3[](
    color_a,
    color_b,
    color_c,
    color_d,
    color_e
);

const uint MODE_TOON =  0u;
const uint MODE_ANTI_ALIASED = 1u;

vec3 grayscale_to_color(float gray, uint mode)
{
    const float color_mode_toon_aa_eps = 0.1;
    gray = clamp(gray, 0.0, 1.0);

    uint mapped_left = uint(floor(gray * float(N_COLORS)));
    uint mapped_right = mapped_left + 1u;
    mapped_right = clamp(mapped_right, 0u, N_COLORS - 1u);

    vec3 left_color = palette[mapped_left];
    vec3 right_color = palette[mapped_right];
    float factor = 1.0 / float(N_COLORS);
    float local_eps = mod(gray, factor) / factor;

    if (mode == MODE_TOON)
    {
        if (distance(local_eps, 1.0) < color_mode_toon_aa_eps) {
            float fraction = (local_eps - 1.0) / color_mode_toon_aa_eps;
            return clamp(mix(left_color, right_color, 1.0 + fraction), vec3(0.0), vec3(1.0));
        }
        else
        {
            return mix(left_color, right_color, 1.0 - step(local_eps, 1.0));
        }
    }
    else if (mode == MODE_ANTI_ALIASED)
    {
        return mix(left_color, right_color, local_eps);
    }
    else
    {
        discard;
    }
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    uv.y *= love_ScreenSize.y / love_ScreenSize.x;

    float noise1 = (gradient_noise(vec3(6 * uv, elapsed)) + 1) / 2 * 1;
    float noise2 = (worley_noise(vec3(8 * uv, elapsed / 10)) + 1) / 2;
    float noise_elapsed = ((sin(elapsed / 3 - PI) + 1) / 2);
    float noise1_step = noise_elapsed * 10;
    float noise2_step = noise_elapsed * 3;
    uv.x += dFdx(noise1) * noise1_step + (noise2) * noise2_step;
    uv.y += dFdy(noise1) * noise1_step + (noise2) * noise2_step;

    float speed = 1 / 10.0;
    uv.y -= elapsed * speed;
    uv = rotate(uv, -PI / 2);
    uv.x -= elapsed * speed / 2;
    uv.y += ((sin(20 * uv.x) + 1) / 2) * (1 / 10.0);
    uv.y *= 30;

    float fraction = sin(uv.y);
    return vec4(vec3(grayscale_to_color(fraction, MODE_TOON)), 1);
}
