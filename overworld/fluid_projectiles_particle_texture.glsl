#ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    float dist = 2 * (0.5 - distance(texture_coords, vec2(0.5)));
    return vec4(sqrt(dist)); //gaussian(1 - dist, 1));
}

#endif
