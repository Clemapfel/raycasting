#ifdef PIXEL

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

vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}
#define PI 3.1415926535897932384626433832795

float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
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

float manhatten_distance(vec2 p)
{
    return max(abs(p.x), abs(p.y));
}

// Hash function for generating pseudo-random values
vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Fast 3D Voronoi - returns distance to nearest cell point
float voronoise(vec3 p) {
    vec3 cell = floor(p);
    vec3 frac = fract(p);

    float minDist = 1.0;

    // Check neighboring cells
    for(int z = -1; z <= 1; z++) {
        for(int y = -1; y <= 1; y++) {
            for(int x = -1; x <= 1; x++) {
                vec3 offset = vec3(x, y, z);
                vec3 neighbor = cell + offset;

                // Random point within the neighbor cell
                vec3 point = hash33(neighbor);

                // Distance to this point
                vec3 diff = offset + point - frac;
                float dist = dot(diff, diff);

                minDist = min(minDist, dist);
            }
        }
    }

    return sqrt(minDist);
}

// checkerboard sdf
float checkerboard(vec2 uv) {
    // src: https://www.shadertoy.com/view/wc2Szh
    float value = (int(floor(uv.x)) + int(floor(uv.y))) % 2 == 0
        ? 1.0 - manhatten_distance(fract(uv) - 0.5)
        :       manhatten_distance(fract(uv) - 0.5)
    ;
    return value;
}

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

uniform float elapsed;
uniform float fraction; // 0: start, 1: end;
uniform bool draw_bloom = true;
uniform float flash;
uniform float brightness_scale;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {

    float noise = gradient_noise(vec3(texture_coords * 10 + vec2(0, -elapsed), 0));

    // uv encodes global position
    const float min_eps = 0.015;
    const float max_eps = 0.75;
    float pattern_outline = checkerboard((5 * texture_coords) + mix(0.05, 0.6, fraction) * vec2(noise));

    float threshold_eps = draw_bloom ? 0.08 : 0.04;
    float threshold_a = 0.49;
    float threshold_b = 0.5 + 0.5 * threshold_eps + 0.02 * (draw_bloom ? 1 : 1);
    pattern_outline = smoothstep(threshold_a - threshold_eps, threshold_a + threshold_eps, pattern_outline) -
        smoothstep(threshold_b - threshold_eps, threshold_b + threshold_eps, pattern_outline);
    pattern_outline -= (1 - color.a);

    float pattern_fill = checkerboard((5 * texture_coords) + 0.2 * noise);
    pattern_fill = smoothstep(0.5 - threshold_eps, 0.5 + threshold_eps, pattern_fill);

    float pattern_noise = gradient_noise(vec3(texture_coords * 10, elapsed));

    float pattern_eps = 2; //fwidth(pattern_noise);
    float pattern_threshold = 0;
    pattern_fill *= 0.4 * smoothstep(pattern_threshold - pattern_eps, pattern_threshold + pattern_eps, pattern_noise);

    // alpha encodes rim
    float outline = 1 - color.a > 0 ? 1 : 0;
    vec4 rim = vec4(mix( vec3(0), color.rgb, outline), outline);

    float intensity = 0.6;
    pattern_outline *= intensity;
    pattern_fill *= intensity;

    vec4 result;
    if (!draw_bloom)
        result = rim + (1 - outline) * vec4(color.rgb * vec3((1 - fraction * 0.5) * min(pattern_outline + pattern_fill, 1)), 1);
    else
        result = rim + (1 - outline) * vec4(color.rgb * pattern_outline, 1);

    return mix(brightness_scale * result, vec4(1), flash);
}

#endif
