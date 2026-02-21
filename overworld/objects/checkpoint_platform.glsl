#ifdef PIXEL

uniform sampler3D noise_texture;
float gradient_noise(vec3 xyz) {
    xyz /= 8;
    return texture(noise_texture, xyz).r;
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
uniform vec4 black;

vec4 effect(vec4 vertex_color, sampler2D img, vec2 uv, vec2 vertex_position) {
    if (color.a < 0.5) return black;

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
