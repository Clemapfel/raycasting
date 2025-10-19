#ifdef PIXEL

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform float elapsed;

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    float value = symmetric(length(texture_coords + normalize(-1 * texture_coords) * elapsed));
    value *= mix(0, 1.5, gaussian(length(texture_coords), 1));

    float threshold = 0.6;
    float eps = 0.02;

    float edge = smoothstep(threshold - eps, threshold + eps, value) * (1 - length(texture_coords));

    float outline = 1.0 - edge;
    outline *= smoothstep(0.0, threshold, value);
    vec3 wave = vec3(value);

    return color * vec4(mix(vec3(0), wave, edge), max(value, outline));
}

#endif