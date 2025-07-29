#ifdef PIXEL

#define MODE_INNER 0
#define MODE_OUTER 1

#ifndef MODE
#error "MODE not set, should be 0 or 1"
#endif

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
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
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


float butterworth(float x, float ramp, int order) {
    // Map ramp parameter to bandwidth (inverse relationship like gaussian)
    float bandwidth = 2.0 / max(ramp, 0.1);
    float center = 0.0; // Center the filter at x=0

    return butterworth_bandpass(x, center, bandwidth, order);
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

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

uniform float elapsed;
uniform vec4 red;

#if MODE == MODE_INNER
uniform vec2 center; // unnormalized screen coords
#endif

const float noise_scale = 30;

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

float triangle(float x) {
    return 2.0 * abs(fract(x) - 0.5) - 1.0;
}

float triangle_tiling(vec2 p) {
    // Triangle lattice basis vectors
    const vec2 basis_a = vec2(1.0, 0.0);
    const vec2 basis_b = vec2(0.5, sqrt(3.0) * 0.5);

    // Transform to lattice coordinates
    mat2 lattice_to_world = mat2(basis_a, basis_b);
    mat2 world_to_lattice = inverse(lattice_to_world);
    vec2 lattice_coords = world_to_lattice * p;

    // Find the nearest lattice point
    vec2 base_point = floor(lattice_coords);
    vec2 fract_part = lattice_coords - base_point;

    // Check the three candidate lattice points in the fundamental triangle
    vec2 candidates[3];
    candidates[0] = base_point;
    candidates[1] = base_point + vec2(1.0, 0.0);
    candidates[2] = base_point + vec2(0.0, 1.0);

    // If we're in the upper-right triangle, add the diagonal point
    if (fract_part.x + fract_part.y > 1.0) {
        candidates[2] = base_point + vec2(1.0, 1.0);
    }

    // Find the closest lattice point
    float min_distance = 1e10;
    for (int i = 0; i < 3; i++) {
        vec2 world_point = lattice_to_world * candidates[i];
        float dist = distance(p, world_point);
        min_distance = min(min_distance, dist);
    }

    return min_distance;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec2 uv = to_uv(frag_position.xy);

    #if MODE == MODE_OUTER

    vec2 seed = vec2(symmetric(texture_coords.x))   ;
    float noise = (gradient_noise(vec3(vec2(seed) * noise_scale, elapsed)) + 1) / 2;
    float opacity = 1 - (texture_coords.y + 0.5 * noise);
    opacity *= 3;
    vec3 intensity = vec3(gaussian(dirac(opacity), 3));

    #elif MODE == MODE_INNER

    float noise = 0;
    float scale = 10;
    bool which = true;
    for (int _ = 1; _ < 4; _++) {
        vec2 seed = uv;
        noise += gradient_noise(vec3(seed * scale, elapsed / 2));
        scale = scale * 2;
        which = !which;
    }

    noise = (noise + 1) / 2;

    float opacity = 1;
    float weight = 1; //color.a;
    vec3 intensity = vec3(pow(dirac(noise), 5) * weight);
    #endif

    return red * triangle_tiling(uv * 10); //vec4(vec3(intensity), opacity);
}

#endif // PIXEL