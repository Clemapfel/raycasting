#ifdef PIXEL

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
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

    float result = mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );

    return result;
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

uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform float fraction = 1;
uniform vec4 black = vec4(0, 0, 0, 1);
uniform float elapsed;
uniform float speedup = 1;
uniform bool bloom = false;

const float threshold = 0.37;
const float eps = 0.025;

float get(vec4 data) {
    float v = max(max(data.x, data.y), data.z);
    float smoothed = smoothstep(threshold - eps, threshold + eps, v);
    return smoothed;
}

vec2 to_uv(vec2 frag_position, vec2 offset) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset + offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

float smooth_min(float a, float b, float k) {
    float h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 bg = vec4(0);

    if (fraction > 0) {
        vec2 offset= vec2(0, 100 * elapsed);
        vec2 uv = to_uv(frag_position, offset);
        float time = elapsed / 200;
        vec2 center = to_uv(0.5 * love_ScreenSize.xy, offset);

        // LCH-based gradient
        float bg_y = uv.y / 1.4;
        float gradient_alpha = symmetric(bg_y);// Invisible at the top, visible at the bottom
        vec3 gradient_color = lch_to_rgb(vec3(0.8, 1, mix(0.7, 0.9, bg_y))) * (1 - gradient_noise(vec3(uv * 1.5, elapsed)));
        bg = vec4(gradient_color, gradient_alpha) * smoothstep(0, 0.8, gradient_noise(vec3(uv * vec2(5, 1), elapsed)));

        // gradient at edge of screen
        bg += vec4(fraction * 3 * smoothstep(0, 1.8, (1 - gaussian((texture_coordinates.y) + gradient_noise(vec3(uv.xx, 0) * 1), 1.0 / 5))));
        bg = mix(vec4(0), mix(0.6, 0.8, fraction) * bg, fraction);
    }

    vec2 normalization = love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);

    // post fx
    if (fraction < 1) {
        vec2 texSize = textureSize(img, 0);
        vec2 pixel = 1.0 / texSize;

        vec2 uv = texture_coordinates;

        float v00 = get(texture(img, uv + pixel * vec2(-1.0, -1.0)));
        float v01 = get(texture(img, uv + pixel * vec2(0.0, -1.0)));
        float v02 = get(texture(img, uv + pixel * vec2(1.0, -1.0)));
        float v10 = get(texture(img, uv + pixel * vec2(-1.0, 0.0)));
        float v12 = get(texture(img, uv + pixel * vec2(1.0, 0.0)));
        float v20 = get(texture(img, uv + pixel * vec2(-1.0, 1.0)));
        float v21 = get(texture(img, uv + pixel * vec2(0.0, 1.0)));
        float v22 = get(texture(img, uv + pixel * vec2(1.0, 1.0)));

        float gradient_x = -v00 - 2.0 * v10 - v20 + v02 + 2.0 * v12 + v22;
        float gradient_y = -v00 - 2.0 * v01 - v02 + v20 + 2.0 * v21 + v22;

        float gradient = length(vec2(gradient_x, gradient_y));

        float value = smoothstep(threshold - eps, threshold + eps, texture(img, uv).a);
        vec4 data = texture(img, uv);
        vec3 color = value * data.rgb / data.a;
        float smooth_gradient = smoothstep(0.0, threshold, max(abs(gradient_x), abs(gradient_y)));

        vec2 gradient_coords = to_uv(frag_position, camera_offset);
        vec2 gradient_center = to_uv(vec2(love_ScreenSize.xy / 2), camera_offset);
        float gradient_weight = min(
            gaussian(2 * distance(gradient_coords.x, gradient_center.x), 0.25),
            gaussian(2 * distance(gradient_coords.y, gradient_center.y), 0.3)
        );

        if (bloom) gradient_weight = 1;

        vec4 balls = (1 - fraction) * vec4(color * smooth_gradient * gradient_weight, gradient * gradient_weight);
        //balls += gradient_weight * vec4(color, data.a);
        balls = max(balls, vec4(0));
        bg += balls;
        bg *= 1.2; // bloom
        bg = clamp(bg, vec4(0), vec4(1));
    }

    return vertex_color * bg;
}

#endif // PIXEL