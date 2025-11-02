#ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    float t = length(texture_coords);
    return vec4(vec4(gaussian(t, 0.6)));
}

#endif
