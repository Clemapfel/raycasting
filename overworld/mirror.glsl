#ifdef PIXEL

#define PI 3.1415926535897932384626433832795

// Improved gaussian function with proper normalization
float gaussian(float x, float sigma)
{
    // Standard gaussian: e^(-x^2 / (2 * sigma^2))
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

// Alternative falloff functions for different visual effects
float exponential_falloff(float x, float decay)
{
    return exp(-decay * pow(x, 1.2));
}

// Returns the perpendicular distance from point pt to the infinite line through line.xy and line.zw
float distance_to_line(vec2 pt, vec4 line)
{
    vec2 a = line.xy;
    vec2 b = line.zw;
    vec2 ab = b - a;
    float ab_len = length(ab);
    if (ab_len < 1e-6) {
        // Line is degenerate; return distance to point a
        return length(pt - a);
    }
    vec2 ap = pt - a;
    // 2D cross product: ab.x * ap.y - ab.y * ap.x
    float cross = abs(ab.x * ap.y - ab.y * ap.x);
    return cross / ab_len;
}

uniform vec4 axis_of_reflection;
uniform float radius;
uniform vec2 player_position;
uniform vec4 player_color;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = texture(img, texture_coords);

    const float mirror_range = 50.0;
    float dist = distance_to_line(screen_coords, axis_of_reflection);

    float normalized_dist = dist / mirror_range;
    float falloff = exponential_falloff(normalized_dist, 2);

    falloff = clamp(falloff, 0.0, 1.0);
    return texel * falloff;
}

#endif