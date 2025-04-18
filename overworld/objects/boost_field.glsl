uniform float elapsed;

float smooth_abs(float x) {
    return abs(x);
}

#define PI 3.1415926535897932384626433832795
vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform vec2 origin_offset;

vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

uniform vec2 axis = vec2(0, -1);

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coordinates, vec2 frag_position) {
    vec2 uv = to_uv(frag_position - origin_offset);

    float angle = atan(axis.y, axis.x) + 0.5 * PI;
    uv = rotate(uv, -angle);

    uv *= 20;

    const float width = 0.5;
    const float eps = 0.2; // anti-aliasing
    const float flattness = 2;

    uv.y = fract(uv.y + elapsed);
    uv.y /= width;
    uv.y -= width;
    uv.x = fract(uv.x);

    float value = smoothstep(width - eps, width + eps, 1 - distance(uv.y, (1 / flattness) * smooth_abs(uv.x * 2 - 1)));
    return vec4(mix(0.58, 0.7, value)) * vertex_color;
}