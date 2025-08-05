#define PI 3.1415926535897932384626433832795
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

    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );
}

float fractal_noise(vec3 p, int octaves, float persistence, float lacunarity) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < octaves; i++) {
        value += gradient_noise(p * frequency) * amplitude;
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    return value / max_value;
}


vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}


#ifdef PIXEL

uniform float elapsed;
uniform vec4 black;

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;
    float line_width = 30 / love_ScreenSize.x;

    float noise = fractal_noise(
        vec3(0, vec2(1, 2) * (vertex_position.xy / love_ScreenSize.xy + vec2(elapsed / 10, 0))),
        4, // octaves
        1, // amplitude
        2  // frequency
    );

    noise *= distance(uv.x, 0);

    float center_fill = 1 - smoothstep(1 - 0.05, 1, length(texture_coords));
    float line_mask = smoothstep(1 - 0.25 + 0.075, 1 - 0.25, length(uv + noise));

    center_fill -= 1 - smoothstep(1 - 0.25 + 0.075, 1 - 0.25, length(vec2(1 - uv.y, uv.y) - uv + noise));
    line_mask = min(line_mask, center_fill);

    vec2 vertex_uv = vertex_position / love_ScreenSize.xy;
    float sign = vertex_position.x >= 0.5 * love_ScreenSize.x ? 1 : -1;
    vec3 rainbow = line_mask * lch_to_rgb(vec3(0.8, 1, vertex_uv.y - elapsed / 10 * sign));

    float rainbow_diff = smoothstep(1 - 0.2, 1, center_fill);
    vec4 line_color = vec4(rainbow.rgb, line_mask);

    float inside_mask = smoothstep(0, 0.01, max(1 - uv.x * 2, 0) - gaussian(max(1 - uv.y * 2, 0), 1));
    vec4 inside_color = vec4(black.rgb * inside_mask, inside_mask);
    return vec4(inside_color + line_color);
}

#endif