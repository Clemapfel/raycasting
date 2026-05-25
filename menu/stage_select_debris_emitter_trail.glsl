#ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4.0 * PI) / 3.0) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {
    const float offset = 0.2;
    return vec4(gaussian(1.0 - texture_coords.y - (1.0 - offset), 1.0));
}

#endif