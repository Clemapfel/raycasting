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

// Fractal noise function with configurable octaves
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

// Butterworth bandpass filter
float butterworth_bandpass(float x, float center, float bandwidth, int order) {
    // Normalize frequency relative to center
    float normalized_freq = abs(x - center) / (bandwidth * 0.5);

    // Avoid division by zero
    if (normalized_freq < 0.001) {
        return 1.0;
    }

    // Butterworth bandpass response
    float response = 1.0 / (1.0 + pow(normalized_freq, 2.0 * float(order)));

    return response;
}

// Simplified version with default parameters for easy replacement
float butterworth_bandpass(float x, float ramp, int order) {
    // Map ramp parameter to bandwidth (inverse relationship like gaussian)
    float bandwidth = 2.0 / max(ramp, 0.1);
    float center = 0.0; // Center the filter at x=0

    return butterworth_bandpass(x, center, bandwidth, order);
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

#ifdef PIXEL

uniform float fraction; // [0, 1, 2]
uniform float elapsed;
uniform float slope; // degrees
uniform float line_width;

uniform vec4 black = vec4(0, 0, 0, 1);

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;
    vec2 uv_backup = uv;
    uv += vec2(0, 0);
    uv = rotate(uv, slope);
    uv -= vec2(0, 0);

    float time = elapsed / 2;
    float outline_noise = 0.1 * (gradient_noise(vec3((vec2(0, uv_backup.y * 20)), time)) + 1) / 2;

    // Use fractal noise with multiple octaves for more detailed texture
    float texture_noise = fractal_noise(
        vec3(fraction, vec2(1, 2) * (vertex_position.xy / love_ScreenSize.xy - vec2(elapsed / 10, 0))),
        4  , // octaves
        1,  // amplitude
        2  // frequency
    );

    vec2 screen_size = love_ScreenSize.xy;
    float line_width_normalized = line_width / love_ScreenSize.x;

    float line_center = mix(1.0 + line_width_normalized, line_width_normalized * 0.5, fraction) + outline_noise - 0.5 * line_width_normalized;

    float line_eps = 0.25 * line_width_normalized; // aa region of line
    float line_mask = 1.0 - smoothstep(0.0, line_eps, distance(uv.x, line_center));
    float reveal_mask = smoothstep(line_center - line_eps, line_center, uv.x);
    float gradient = gaussian(distance(uv.x, line_center), (1 - line_width_normalized) * 20); // gradient width

    // Replace gaussian with Butterworth bandpass filter
    float texture_gradient = butterworth_bandpass(distance(uv.x, line_center), 5, 3);
    texture_noise *= texture_gradient;

    float outline_eps = line_eps * 0.5;
    float outline = 1.0 - smoothstep(0, outline_eps, distance(uv.x + outline_eps, line_center));

    vec3 rainbow = (max(line_mask, gradient) - outline + texture_noise) * lch_to_rgb(vec3(0.8, 1, fract(uv.y - elapsed / 10)));
    vec3 base = (reveal_mask + outline) * black.rgb;

    return vec4((base + rainbow), max(line_mask, reveal_mask));
}

#endif