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

float gaussian2d(vec2 xy, float ramp)
{
    float r2 = dot(xy, xy); // x^2 + y^2
    return exp(((-4.0 * PI) / 3.0) * (ramp * r2));
}

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

uniform float elapsed;
uniform vec2 player_position;
uniform float player_radius;
uniform vec2 size;
uniform float spawn_fraction;
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

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {

    vec2 uv = to_uv(vertex_position);

    float distortion_ramp = 2;
    float fade_out = gaussian(texture_coords.x, 1);
    float boost = gaussian(texture_coords.x, 8) * 0.5;

    float distortion_strength = 0.2;
    float distortion_scale = 20;
    float distortion_speed = 1 / 2.0;
    vec2 distortion = vec2(
    gradient_noise(vec3(uv * distortion_scale, elapsed * distortion_speed)),
    gradient_noise(vec3(uv * distortion_scale, elapsed * distortion_speed))
    ) * distortion_strength;

    vec2 center = to_uv(vec2(0.5));

    //texture_coords.x += noise * 0.5;

    // If size is not (1,1), normalize to square
    vec2 norm_player_pos = player_position * size / max(size.x, size.y);
    vec2 norm_tex_coords = texture_coords * size / max(size.x, size.y);

    float threshold = max(norm_player_pos.y + 2.0 * player_radius / love_ScreenSize.y, spawn_fraction);
    float fade = 1 - gaussian(texture_coords.y - threshold, 10); // Adjust ramp as needed
    if (texture_coords.y > threshold) fade = 0;

    const float delay = 0.4;
    float threshold2 = max(spawn_fraction - delay, 0);
    float fade2 = gaussian(texture_coords.y - threshold2, 1); // Adjust ramp as needed
    if (texture_coords.y > threshold2) fade2 = 1;
    fade *= fade2;

    const float ball_eps = 0.3;
    const float ball_size = 15;
    float player_ball = gaussian(distance(norm_player_pos, norm_tex_coords), ball_size);
    player_ball *= gaussian(abs(texture_coords.x - 0.5) * 2, 1);
    player_ball = smoothstep(0.5 - ball_eps, 0.5 + ball_eps, player_ball);

    texture_coords += distortion * (1 - player_ball);

    float player_weight = distance(norm_player_pos, norm_tex_coords);
    const float ray_eps = 0.4;

    const float ray_width = 2.5;
    float ray = gaussian(abs(texture_coords.x - 0.5), ray_width);
float ray_inner = gaussian(abs(texture_coords.x - 0.5), ray_width * 10);
ray += ray_inner;

vec3 player_lch = rgb_to_lch(color.rgb);
vec3 ray_lch = vec3(0.8, 1, fract(player_lch.z - player_weight));

return fade * vec4(smooth_max(ray, player_ball, 0.05)) * vec4(lch_to_rgb(ray_lch), 1);
}

#endif