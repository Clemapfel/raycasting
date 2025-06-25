#ifdef PIXEL

float fast_angle(vec2 dxy)
{
    float dx = dxy.x;
    float dy = dxy.y;
    float p = dx / (abs(dx) + abs(dy));
    if (dy < 0.0)
        return (3.0 - p) / 4.0;
    else
        return (1.0 + p) / 4.0;
}

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#define PI 3.1415926535897932384626433832795

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) // tex is RG8
{
    vec4 data = texture(tex, texture_coords);
    if (data.x == 0 && data.y == 0) discard;

    vec2 gradient = (data.xy * 2) - 1;
    float hue = (atan(gradient.y, gradient.x) + PI) / (2 + PI);
    return vec4(hsv_to_rgb(vec3(hue, 1, 1)), 1);
}
#endif