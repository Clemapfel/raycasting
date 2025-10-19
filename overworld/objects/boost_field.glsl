float smooth_abs(float x) {
    return abs(x);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform vec2 axis = vec2(0, -1);

uniform vec2 camera_offset;
uniform float camera_scale = 1;
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


uniform vec2 player_position; // in screen space
uniform vec4 player_color;
uniform float player_influence; // 0, 1
uniform float elapsed;

vec4 effect(vec4 vertex_color, sampler2D _, vec2 texture_coordinates, vec2 frag_position) {
    vec2 uv = to_uv(frag_position);

    vec2 aspect_correct = vec2(1, love_ScreenSize.y / love_ScreenSize.x);
    float dist = gaussian(distance(aspect_correct * to_uv(frag_position), aspect_correct * to_uv(player_position)), 4);

    #ifdef RT_SHADER_DERIVATIVES
    vec2 dxy = vec2(dFdx(dist), dFdy(dist)) * 1.25;
    #else
    vec2 dxy = vec2(1);
    #endif

    // rotate
    vec2 axis_norm = normalize(axis);
    float cos_a = -axis_norm.y;
    float sin_a = -axis_norm.x;

    uv = vec2(
        uv.x * cos_a - uv.y * sin_a,
        uv.x * sin_a + uv.y * cos_a
    );

    uv += dxy * player_influence;

    uv *= 12;

    const float width = 0.5; // line width
    const float eps = 0.01;
    const float flatness = 1.1;

    uv.y = fract(uv.y + elapsed / 2.5);
    uv.y /= width;
    uv.y -= width;
    uv.x = fract(uv.x);

    float v = distance(uv.y, (1 / flatness) * smooth_abs(uv.x * 2 - 1));
    float value = smoothstep(width - eps, width + eps, 1 - v);

    vec4 color = mix(vertex_color, player_color, player_influence * dist);

    return vec4(vec3(mix(0.2, 1, value)), 1) * color;
}