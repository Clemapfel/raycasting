#ifdef PIXEL

float fast_angle(float dx, float dy) {
    float p = dx / (abs(dx) + abs(dy));
    if (dy < 0.0) {
        return (3.0 - p) / 4.0;
    } else {
        return (1.0 + p) / 4.0;
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

#define PI 3.1415926535897932384626433832795
float slow_angle(float dx, float dy) {
    return (atan(dy, dx) + PI) / (2.0 * PI);
}

float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
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

uniform float elapsed;
//uniform float fraction;

vec4 effect(vec4 color, Image img, vec2 uv, vec2 _) {

    float fraction = (sin(elapsed) + 1) / 2;

    const float threshold = 1.0 - 0.9;
    const float eps = 0.01;
    float circle = smoothstep(threshold - eps, threshold + eps, (1.0 - distance(uv, vec2(0.5)) * 2.0));

    float open = gaussian(distance(uv, vec2(0.5)), 1.5);
    int n = 8;


    uv -= vec2(0.5);
    uv = rotate(uv, 1.0 - distance(uv, vec2(0.0)) * 2.0 * PI - elapsed);
    uv += vec2(0.5);

    // Calculate normalized angle in [0, 1)
    vec2 centered = uv - vec2(0.5);
    float angle = slow_angle(centered.x, centered.y); // [0,1)
    float slice_f = angle * float(n);

    // Get current and next slice indices
    float current_slice = floor(slice_f);
    float next_slice = mod(current_slice + 1.0, float(n));

    // Calculate blend factor (how far we are between current and next slice)
    float blend_factor = fract(slice_f);

    // Calculate stripe values for current and next slices
    float current_stripe = mod(current_slice, 2.0);
    float next_stripe = mod(next_slice, 2.0);

    // --- Assign LCH color to each slice ---
    // Constant lightness and chroma, hue per slice
    float l = 0.8;
    float c = 1.0;
    float current_h = current_slice / float(n); // 0..1
    float next_h = next_slice / float(n);       // 0..1

    vec3 current_rgb = lch_to_rgb(vec3(l, c, current_h));
    vec3 next_rgb = lch_to_rgb(vec3(l, c, next_h));

    // Smooth blending between slices
    float blend_width = 0.15; // Controls the width of the blend region (0.0 to 0.5)
    float blend_start = 0.5 - blend_width * 0.5;
    float blend_end = 0.5 + blend_width * 0.5;

    vec3 col;
    if (blend_factor < blend_start) {
        col = current_rgb;
    } else if (blend_factor > blend_end) {
        col = next_rgb;
    } else {
        float local_blend = (blend_factor - blend_start) / blend_width;
        local_blend = smoothstep(0.0, 1.0, local_blend); // Apply smoothstep for even smoother transition
        col = mix(current_rgb, next_rgb, local_blend);
    }

    return color * vec4(col, circle);
}

#endif // PIXEL