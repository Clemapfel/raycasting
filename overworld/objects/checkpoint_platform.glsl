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
    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix(
    mix(
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,0,0)), v - vec3(0,0,0)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,0,0)), v - vec3(1,0,0)), u.x),
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,1,0)), v - vec3(0,1,0)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,1,0)), v - vec3(1,1,0)), u.x),
    u.y),
    mix(
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,0,1)), v - vec3(0,0,1)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,0,1)), v - vec3(1,0,1)), u.x),
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,1,1)), v - vec3(0,1,1)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,1,1)), v - vec3(1,1,1)), u.x),
    u.y),
    u.z);
}

#define PI 3.1415926535897932384626433832795

float gaussian(float x, float ramp) {
    return exp(((-4.0 * PI) / 3.0) * (ramp * x) * (ramp * x));
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

uniform float elapsed;
uniform vec4 color = vec4(1, 0, 1, 1);
uniform bool bloom_active = false;
uniform float outline_width = 0.08;
uniform float brightness_scale;

vec4 effect(vec4 vertex_color, sampler2D img, vec2 uv, vec2 vertex_position) {
    if (color.a == 0) return vec4(0.0, 0.0, 0.0, 1.0);

    float noise_frequency = 20.0;
    float noise_amplitude = 0.5;
    float noise = noise_amplitude * gradient_noise(vec3(noise_frequency * vec2(symmetric(uv.x)), elapsed));

    float value = uv.y - (noise + 1.0) / 2.0;

    float eps = 0.3;
    float outline_thickness = outline_width * (1 + (3.5 * (brightness_scale - 1)));
    float outline = smoothstep(outline_thickness, outline_thickness + eps,
        gaussian(1.0 - uv.y, 2) * abs(value));

    float inner = smoothstep(0.0, 0.15, value * gaussian(1.0 - uv.y, 1.0));

    vec4 result = brightness_scale * color * vec4(mix(vec3(inner), vec3(0.0), outline), max(inner, outline));
    return result;
}

#endif
