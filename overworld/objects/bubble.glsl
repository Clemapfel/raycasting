#ifdef PIXEL
#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform float pop_fraction; // current spread radius [0..1]

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;

    const vec2 center = vec2(0);

    // shadow
    float shadow_offset = -1. / 3.5;
    float body = max(0.05, 1 - gaussian(distance(uv, vec2(shadow_offset)) * pop_fraction, 0.6));
    vec4 body_color = body * color;
    body_color.a = 0.1;

    // highlight
    float dist = distance(pow(distance(uv, center), 1.5) * uv, vec2(-1. / 3.2, -1. / 2.7));
    float highlight = gaussian(dist, 1.2) * gaussian(distance(uv, center), 0.2);
    vec4 highlight_color = pop_fraction * vec4(vec3(1), distance(uv, center)) * highlight;

    return body_color + highlight_color;
}

#endif
