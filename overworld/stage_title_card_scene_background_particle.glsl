#ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    float value = distance(texture_coordinates, vec2(0.5)) * 2;
    value = gaussian(value, 1);
    return vec4(value);
}

#endif