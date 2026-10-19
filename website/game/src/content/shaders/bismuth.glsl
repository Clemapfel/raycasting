/*
#version 300 es
precision highp float;

uniform vec2 rt_ScreenSize;
uniform float elapsed;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;
*/

#define PI  3.14159265358979323846
#define TAU 6.28318530717958647692

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

    return mix( mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
    mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );
}

vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float chebyshev(vec3 a, vec3 b) {
    vec3 d = abs(a - b);
    return max(d.x, max(d.y, d.z));
}

// Assumed signature: rotates around the z axis. Swap in your own if it differs.
vec3 rotate(vec3 v, float angle) {
    float s = sin(angle), c = cos(angle);
    return vec3(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}
float noise(vec3 p, float twist) {
    // Map pixel coords into a single cell spanning the screen (0..1 in xy)
    vec3 f = vec3(p.xy / love_ScreenSize.xy, p.z);

    // Hash a fixed seed to get the one feature point's position
    vec3 q = fract(vec3(1.0) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yxz + 19.19);
    vec3 center = fract((q.xxy + q.yzz) * q.zyx);

    // Same twist as before
    center = vec3(rotate(center, 2.0 * twist * chebyshev(f, center) * TAU).xy, center.z);
    vec3 delta = f - center;

    float dist = length(delta);
    return 1.0 - dist;
}

uniform float elapsed;


vec4 effect(vec4 color, sampler2D tex, vec2 rt_TextureCoords, vec2 screen_coords) {
    vec2 rt_ScreenSize = love_ScreenSize.xy;

    float time = elapsed / 30.0;

    vec2 uv = rt_TextureCoords + vec2(0.5);
    uv -= 0.5;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    vec2 pos = uv;
    vec2 center = vec2(0.5);
    center.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    return vec4(1.0, 0.0, 1.0, 1.0);
}
