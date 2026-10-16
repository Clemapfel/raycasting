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

// cheap hash: tile index -> pseudo-random value in [0, 1)
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

vec2 symmetric(vec2 value) {
    return vec2(symmetric(value.x), symmetric(value.y));
}

const float tile_size = 40.0;

vec2 pos_to_tile_id(vec2 pos) {
    return floor(pos / tile_size);
}

vec2 tile_id_to_ray_dir(vec2 tile_id) {
    return mod(tile_id, 2.0) * 2.0 - 1.0;
}

uniform float elapsed;

vec2 snap_cardinal(vec2 v, float strength) {
    vec2 target = abs(v.x) > abs(v.y)
    ? vec2(sign(v.x), 0.0)
    : vec2(0.0, sign(v.y));
    // keep original length so only the direction changes
    return mix(v, target * length(v), strength);
}

float sine(float x) {
    return (sin(x) + 1.0) / 2.0;
}

vec2 rotate(vec2 v, float n) {
    float a = n;
    float c = cos(a);
    float s = sin(a);
    return vec2(
        c * v.x - s * v.y,
        s * v.x + c * v.y
    );
}

float chebyshev(vec2 pos, vec2 other) {
    vec2 d = abs(pos - other);
    return max(d.x, d.y);
}

const float PI  = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    float time = elapsed / 100.0;

    vec2 uv = texture_coords;
    uv -= 0.5;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;

    vec2 amp = vec2(1.0);
    vec2 amp_mul = vec2(1.0);
    vec2 amp_add = vec2(0.0);

    vec2 dir = 0.05 * vec2(
        gradient_noise(vec3(uv.x, uv.y, time)),
        gradient_noise(vec3(uv.y, time, uv.x))
    );

    vec2 pos = uv;

    const int n_steps = 0;
    for (int i = 0; i < n_steps; ++i) {

        dir = rotate(dir, mix(0.0, TAU, 2.0 * chebyshev(pos, uv)));

        pos = pos + amp * dir;
        amp += amp_add;
        amp = amp * amp_mul;
    }

    pos *= 3.0;
    pos = vec2(tanh(pos.x), tanh(pos.y));
    pos = rotate(pos, mix(0.0, TAU, 2.0 * chebyshev(pos, uv) - time));
    float hue = atan(pos.y, pos.x);
    float t = 1.0;
    vec3 rgb = lch_to_rgb(vec3(0.8, 1.0, hue));
    return vec4(vec3(fract(6.0 * hue / TAU)), 1.0);
}