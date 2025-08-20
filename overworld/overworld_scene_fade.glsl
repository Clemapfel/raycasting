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

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#ifdef PIXEL

uniform float value; // 1 fully opaque, 0 fully transparent
uniform float direction; // +1 going from transparent to opaque, -1 otherwise
uniform float elapsed;

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 vertex_position) {
    // override for full black at 1, which is when fade usually causes a lag frame
    if (distance(value, 1) < 0.001) return vec4(0, 0, 0, 1);

    // Aspect ratio normalization
    float aspect = love_ScreenSize.x / love_ScreenSize.y;

    // Center in normalized coordinates
    vec2 center = vec2(0.5, 0.5);

    // Aspect-corrected coordinates: scale x so that distances are isotropic
    vec2 norm_coords = texture_coords;
    norm_coords.x = (norm_coords.x - 0.5) * aspect + 0.5;
    vec2 norm_center = center;
    norm_center.x = (norm_center.x - 0.5) * aspect + 0.5;

    // For noise, keep original texture_coords, but for all distance/circle ops use norm_coords
    vec2 pos = norm_coords;

    const int n_octaves = 3;
    vec2 noise_scale = vec2(3, 2) * 4;

    const float angle_width = 0.5 * 2 * PI;
    const float angle_direction = 0; // upwards

    float step_size = 0.5;

    float steps = 0;
    for (int i = 0; i < n_octaves; ++i) {
        float dist = distance(pos.xy, norm_coords.xy);

        vec2 seed = texture_coords.xy * noise_scale;

        float angle = mix(angle_direction - angle_width / 2, angle_direction + angle_width / 2, (gradient_noise(vec3(seed.xy, elapsed)) + 1) / 2);
        vec2 offset = vec2(
        cos(angle),
        sin(angle)
        );

        pos.xy += offset * step_size;
        step_size = step_size * 0.5;
        noise_scale = noise_scale * 0.5;
    }

    float eps = 0.02;

    float noise = 0;
    if (direction > 0) { // fade in: wipe upwards
        // For vertical wipe, aspect ratio is not needed
        noise = distance(pos.y, norm_coords.y);
        noise = 1 - clamp(norm_coords.y / 2 + noise, 0, 1);
    }
    else if (direction < 0) { // fade out: circle wipe
        // Use aspect-corrected coordinates for circular wipe
        float dist = distance(norm_coords, norm_center) * (value + 1 + distance(pos.y, norm_coords.y));
        noise = 1 - dist;
    }

    float opacity = 1 - smoothstep(value - eps, value + eps, noise);

    float border_eps = 0.07;
    float border_band = 1 - gaussian(
    smoothstep(value - border_eps, value, noise) - smoothstep(value, value + border_eps, noise),
    20 // border width
    );
    // Use pos.x from aspect-corrected pos for color
    return vec4(lch_to_rgb(vec3(0.8, 1, pos.x)) * border_band, color.a * opacity);
}

#endif