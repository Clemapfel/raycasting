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

    float result = mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );

    return (result + 1) / 2.;
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

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
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

#ifdef PIXEL

uniform float elapsed;
uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform float fallspeed = 0;

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

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

float smooth_fract(float x) {
    float epsilon = 0.01; // Adjust for smoothness
    return x - floor(x) - sin(2.0 * PI * x) * epsilon;
}

vec2 smooth_fract(vec2 v) {
    return vec2(smooth_fract(v.x), smooth_fract(v.y));
}

vec3 smooth_fract(vec3 v) {
    return vec3(smooth_fract(v.x), smooth_fract(v.y), smooth_fract(v.z));
}

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}
float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}




vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {
    vec2 uv = to_uv(frag_position);

    float time = elapsed / 200;
    vec2 center = to_uv(0.5 * love_ScreenSize.xy);

    vec4 stars = vec4(0);
    float value = 0;
    if (fraction < 1) {
        float scale = 15;
        float noise = 0;
        int n_octaves = 4;
        float current_hue = 0;
        for (int i = 1; i <= n_octaves; ++i) {
            noise = smooth_max(noise, worley_noise(vec3(uv * scale - vec2(0, -elapsed * (1 + fraction)), i)), mix(0.3, 0.7, fraction));
            current_hue += noise * 0.75;
            scale *= pow(1.3, i);
        }

        float eps = 0.05;
        float threhsold = 0.83;
        value = smoothstep(threhsold, threhsold + eps, noise);
        float hue_offset = gradient_noise(vec3(uv * scale * value, elapsed));
        stars = vec4(lch_to_rgb(vec3(mix(0.6, 0.9, hue_offset), 0.9, fract((1 - hue) + current_hue))), value);
    }

    // LCH-based gradient
    float bg_y = uv.y / 1.4 + elapsed / 4;
    float gradient_alpha = symmetric(bg_y); // Invisible at the top, visible at the bottom
    vec3 gradient_color = lch_to_rgb(vec3(0.8, 0.9, mix(0.7, 1.0, bg_y))) * (1 - gradient_noise(vec3(uv * 1.5, time)));
    vec4 bg = vec4(gradient_color, gradient_alpha) * smoothstep(0, 0.8, gradient_noise(vec3(uv , time)));

    // gradient at edge of screen
    bg += vec4(fraction * 3 * smoothstep(0, 1.8, (1 - gaussian((texture_coords.y) + gradient_noise(vec3(uv.xx, elapsed) * 1), 1.0 / 5))));

    return mix(stars, mix(0.6, 0.8, fraction) * bg, min(1 - value + fraction, 1));
}

#endif