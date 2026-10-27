#version 300 es
precision highp float;

uniform vec2 rt_ScreenSize;
uniform float elapsed;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

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

vec2 rotate(vec2 v, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(
    c * v.x - s * v.y,
    s * v.x + c * v.y
    );
}

uniform vec2 cursor_position;
uniform float cursor_visible;
float cursor_distance() {
    vec2 aspect = vec2(rt_ScreenSize.x / rt_ScreenSize.y, 1.0);
    vec2 distance = (rt_TextureCoords - cursor_position / rt_ScreenSize) * aspect;
    float x = dot(distance, distance) * 32.0;
    return cursor_visible * (1.0 / (1.0 + x * x));
}


void main() {
    float time = elapsed / 30.0;

    vec2 uv = rt_TextureCoords;
    uv -= 0.5;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    vec2 pos = 1.5 * uv;

    vec2 amp = vec2(0.1);
    vec2 amp_mul = vec2(1.0);
    vec2 amp_add = vec2(0.02);

    float angle_t = 0.8;
    float angle_t_mul = 1.0;
    float angle_t_add = 0.0;

    vec2 center = vec2(0.0);
    vec2 seed = 2.0 * pos;
    vec2 dir = normalize(vec2(
        gradient_noise(vec3(seed.x, seed.y, time)),
        gradient_noise(vec3(seed.y, time, seed.x))
    ));

    vec3 rgb = vec3(0.0);
    const int n_steps = 4;
    for (int i = 0; i < n_steps; ++i) {
        amp = amp * amp_mul + amp_add;
        angle_t = angle_t * angle_t_mul + angle_t_add;
        center = center + dir * amp;

        float which = (i % 2 == 0 ? 1.0 : -1.0);
        vec2 rel = pos - center;
        float angle = angle_t * which * TAU * (2.0 * distance(pos, center));
        pos = center + rotate(rel, angle + mix(0.0, 0.1, cursor_distance()) * TAU);

        float hue = fract(angle_t + atan(pos.y, pos.x) / TAU);
        float d = distance(pos, center);
        float mask = pow(0.5 + 0.5 * cos(TAU * 2.0 * d), 6.0);

        rgb = mix(rgb, lch_to_rgb(vec3(0.8, 1.0, hue)), mask);
    }

    rt_FragColor = vec4(0.75 * rgb, 1.0);
}
