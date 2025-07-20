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

// Triangle wave function centered at zero
float triangle(float x) {
    return 2.0 * abs(fract(x) - 0.5) - 1.0;
}

// Noise function using summed triangle waves
float triangle_noise(float x, int octaves, float persistence) {
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float maxAmp = 0.0;

    for (int i = 0; i < octaves; ++i) {
        sum += amp * triangle(x * freq);
        maxAmp += amp;
        freq *= 2.0;
        amp *= persistence;
    }

    // Normalize to [-1, 1]
    return sum / maxAmp;
}

#define PI 3.1415926535897932384626433832795

float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
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

const float noise_scale = 1;

#if MODE == MODE_INNER

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {

    vec2 uv = to_uv(frag_position);
    float noise = gradient_noise(vec3(vec2(uv * 10) * noise_scale, elapsed));

    return vec4(vec3(noise), 1);
    return color;
}

#elif MODE == MODE_OUTER

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {

    float depth = 1 - texture_coords.y;
    vec2 uv = to_uv(frag_position);

    float noise = gradient_noise(vec3(vec2(uv) * 30, elapsed));

    float spikes = gaussian(1 - depth * ((noise * 2) + 1) / 2, 0.9);
    return vec4(spikes);
}

#endif // MODE
