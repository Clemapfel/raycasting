#ifdef PIXEL

uniform sampler3D noise_texture;
float gradient_noise(vec3 xyz) {
    xyz /= 8;
    return texture(noise_texture, xyz).r;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

uniform float elapsed;
uniform vec4 color = vec4(1, 0, 1, 1);
uniform bool bloom_active = false;
uniform float brightness_scale;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;
    float side = sign((2 * vertex_color.a) - 1);
    vec2 seed = uv.xy;
    seed.y += 10 * side;

    float noise_frequency = 20;
    float noise_amplitude = 0.5;

    seed *= noise_frequency;
    float noise = noise_amplitude * gradient_noise(vec3(seed.yy + side * elapsed, elapsed));

    float value = uv.x - noise;

    float eps = 0.3;
    float outline_thickness = 0.1 * (1 + 4 *(brightness_scale - 1));
    float outline = smoothstep(outline_thickness, outline_thickness + eps, vertex_color.r * value * gaussian(1 - uv.x, 1.1));

    value = smoothstep(0, eps, value * gaussian(1 - uv.x, 1));
    vec4 result = brightness_scale * color * smoothstep(0, 0.6, vertex_color.r) * vec4(mix(vec3(value), vec3(0), outline), max(value, outline));

    if (bloom_active) result *= (1 - outline);
    return result;
}

#endif