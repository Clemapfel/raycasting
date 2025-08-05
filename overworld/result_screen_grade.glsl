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

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

#define MODE_FRAME 0
#define MODE_MASK 1

#ifndef MODE
#error "In overworld/result_screen_circle.glsl: `MODE` unset, should be 0 or 1"
#endif

#ifdef PIXEL

uniform float elapsed;

#if MODE == MODE_FRAME

uniform vec4 black;

#endif

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;

    // For circle mesh: u wraps around circumference [0,1], v goes from center (0) to outer ring (1)
    float radial_distance = uv.y; // v coordinate represents radial distance
    float circumferential_pos = uv.x; // u coordinate wraps around circumference

    // Generate noise based on circumferential position and time
    float noise = fractal_noise(
    vec3(circumferential_pos * 10, radial_distance * 2.0, elapsed / 10.0),
    4, // octaves
    0.5, // persistence
    2.0  // lacunarity
    ) * 0.1; // Scale noise intensity

    // Apply noise to radial distance for wavy outline effect
    float noisy_radius = radial_distance + noise;

    // Define regions based on radial distance
    float inner_threshold = 0.1;  // Inner solid region
    float outer_threshold = 0.8;  // Start of rainbow outline
    float edge_threshold = 1.0;   // Outer edge

    // Create masks for different regions
    float inner_mask = 1.0 - smoothstep(0.0, inner_threshold, noisy_radius);
    float outline_mask = smoothstep(outer_threshold - 0.1, outer_threshold, noisy_radius) *
    (1.0 - smoothstep(edge_threshold - 0.1, edge_threshold, noisy_radius));
    float edge_mask = smoothstep(edge_threshold - 0.05, edge_threshold, noisy_radius);

    // Rainbow color calculation using circumferential position and time
    float time = elapsed / 10.0;
    float hue = fract(circumferential_pos + time); // Animate hue around circumference
    vec3 rainbow = lch_to_rgb(vec3(0.8, 1.0, hue));

    // Combine regions
    vec4 final_color;

    #if MODE == MODE_MASK

    // Stencil masking - only render the solid inner part
    if (inner_mask < 0.5) discard;
    return vec4(1.0);

    #elif MODE == MODE_FRAME

    // Inner solid color
    vec4 inner_color = vec4(black.rgb, inner_mask);

    // Rainbow outline
    vec4 outline_color = vec4(rainbow * outline_mask, outline_mask);

    // Edge fade
    vec4 edge_color = vec4(black.rgb * edge_mask, edge_mask);

    // Blend layers
    final_color = inner_color;
    final_color = mix(final_color, outline_color, outline_mask);
    final_color = mix(final_color, edge_color, edge_mask);

    return final_color;

    #endif
}

#endif