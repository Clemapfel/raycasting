#ifdef PIXEL

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
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
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

vec3 rgb_to_lch(vec3 rgb) {
    // 1. Clamp input to [0,1]
    float R = clamp(rgb.r, 0.0, 1.0);
    float G = clamp(rgb.g, 0.0, 1.0);
    float B = clamp(rgb.b, 0.0, 1.0);

    // 2. Inverse gamma correction (sRGB to linear RGB)
    R = (R <= 0.04045) ? R / 12.92 : pow((R + 0.055) / 1.055, 2.4);
    G = (G <= 0.04045) ? G / 12.92 : pow((G + 0.055) / 1.055, 2.4);
    B = (B <= 0.04045) ? B / 12.92 : pow((B + 0.055) / 1.055, 2.4);

    // 3. Linear RGB to XYZ (D65)
    float X = R * 0.4124 + G * 0.3576 + B * 0.1805;
    float Y = R * 0.2126 + G * 0.7152 + B * 0.0722;
    float Z = R * 0.0193 + G * 0.1192 + B * 0.9505;

    // 4. Normalize for D65 white point
    X /= 0.95047;
    Y /= 1.00000;
    Z /= 1.08883;

    // 5. XYZ to LAB
    float epsilon = 0.008856;
    float kappa = 903.3;

    float fx = (X > epsilon) ? pow(X, 1.0/3.0) : (kappa * X + 16.0) / 116.0;
    float fy = (Y > epsilon) ? pow(Y, 1.0/3.0) : (kappa * Y + 16.0) / 116.0;
    float fz = (Z > epsilon) ? pow(Z, 1.0/3.0) : (kappa * Z + 16.0) / 116.0;

    float L = 116.0 * fy - 16.0;
    float a = 500.0 * (fx - fy);
    float b = 200.0 * (fy - fz);

    // 6. LAB to LCH
    float C = sqrt(a * a + b * b);
    float H = degrees(atan(b, a));
    if (H < 0.0) H += 360.0;

    // 7. Normalize to [0,1] for output
    return vec3(L / 100.0, C / 100.0, H / 360.0);
}

uniform float elapsed;
uniform vec2 size;
uniform float fraction;
uniform float fade_out_fraction;
uniform float hue;

uniform vec2 camera_offset;
uniform float camera_scale = 1;

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

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_uv(vertex_position);

    float distortion_strength = (1 - distance(texture_coords.x, 0.5) * 2) ;
    vec2 distortion_scale = vec2(1.8, 10);
    float ground_weight = 1 - gaussian(1 - texture_coords.y, 12); // so ray touches bottom at center

    vec2 norm = size / max(size.x, size.y);
    const float ball_eps = 0.5;
    float ball = gaussian(distance(texture_coords * norm, vec2(0.5, fraction - 26 / size.y) * norm), 3);
    //ball = smoothstep(0.5 - ball_eps, 0.5 + ball_eps, ball);
    float ball_attenuation = texture_coords.y > fraction ? gaussian(texture_coords.y - fraction, 10.0) : 1.0;
    ball *= ball_attenuation;

    vec2 distortion = vec2(
        gradient_noise(vec3(uv * distortion_scale, elapsed)),
        gradient_noise(vec3(uv * distortion_scale, elapsed))
    ) * distortion_strength;

    float overlap_factor = fade_out_fraction > 0 ? 1.05 : 1;
    float fade = 1 - gaussian(texture_coords.y - fraction * overlap_factor, 15); // multiply so fade out is below ground
    if (texture_coords.y > fraction) fade = 0;

    float fade2 = gaussian(texture_coords.y * norm.y - fade_out_fraction * 2, 0.5);
    if (texture_coords.y > fade_out_fraction * 2) fade2 = 1;
    fade *= fade2;

    texture_coords.x += distortion.x * ground_weight;

    float ray_width = 4;
    float ray_outer = gaussian(abs(texture_coords.x - 0.5), ray_width);
    float ray_inner = gaussian(abs(texture_coords.x - 0.5), ray_width * 10);

    float ray = (ray_outer * (1 + ball) + ray_inner) / (1 + ball) * fade;
    ray *= 1 + ball * (fade_out_fraction > 0 ? 0.4 : 0);
    float hue = fract(hue + texture_coords.y * norm.y);
    return vec4(ray) * vec4(lch_to_rgb(vec3(0.8, 1, hue)), 1);

}

#endif