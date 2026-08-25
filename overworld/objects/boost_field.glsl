vec3 oklch_to_rgb(vec3 lch) {
    float L = lch.x;
    float C = lch.y;
    float hue_rad = radians(lch.z * 360.0);

    float a = cos(hue_rad) * C;
    float b = sin(hue_rad) * C;

    float l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    float m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    float s_ = L - 0.0894841775 * a - 1.2914855480 * b;

    float l = l_ * l_ * l_;
    float m = m_ * m_ * m_;
    float s = s_ * s_ * s_;

    float linear_r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    float linear_g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    float linear_b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

    return vec3(
    clamp(linear_r > 0.0031308 ? 1.055 * pow(linear_r, 1.0 / 2.4) - 0.055 : 12.92 * linear_r, 0.0, 1.0),
    clamp(linear_g > 0.0031308 ? 1.055 * pow(linear_g, 1.0 / 2.4) - 0.055 : 12.92 * linear_g, 0.0, 1.0),
    clamp(linear_b > 0.0031308 ? 1.055 * pow(linear_b, 1.0 / 2.4) - 0.055 : 12.92 * linear_b, 0.0, 1.0)
    );
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

float mix_periodic(float a, float b, float t) {
    float tri = 1.0 - abs(2.0 * fract(t) - 1.0); // triangle wave: 0,1,0
    float w = smoothstep(0.0, 1.0, tri);
    return mix(a, b, w);
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

uniform float elapsed;
uniform float velocity_factor;

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

vec4 effect(vec4 vertex_color, sampler2D _, vec2 texture_coordinates, vec2 frag_position) {
    float hue = fract(texture_coordinates.y - 0.0 * elapsed);

    vec2 uv = to_world_position(frag_position) / 10.0;
    float hue_noise = (gradient_noise(vec3(uv.xy + normalize(uv.xy) * elapsed, elapsed / 3.0)) + 1.0) / 2.0;
    float lightness_noise = (gradient_noise(vec3(uv.y, elapsed, uv.x)) + 1.0) / 2.0;

    return vertex_color * vec4(lch_to_rgb(vec3(
        0.8 + mix(-0.2, 0.0, lightness_noise),
        1.2 - mix(0.0, 0.5, lightness_noise),
        hue + mix(-0.05, 0.05, hue_noise)
    )), 1.0);
}