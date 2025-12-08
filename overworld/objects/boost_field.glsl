float smooth_abs(float x) {
    return abs(x);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform vec2 axis = vec2(0, -1);


uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform vec2 player_position; // in screen space
uniform vec4 player_color;
uniform float player_influence;
uniform float elapsed;
uniform float brightness_offset; // already scaled

vec4 effect(vec4 vertex_color, sampler2D _, vec2 texture_coordinates, vec2 frag_position) {
    vec2 uv = to_world_position(frag_position) / 500.0;

    vec2 aspect_correct = vec2(1.0, love_ScreenSize.y / love_ScreenSize.x);
    float dist = gaussian(min(1.0, distance(
    to_world_position(frag_position) * aspect_correct,
    to_world_position(player_position) * aspect_correct
    ) / 400.0), 3.0);

    #ifdef SHADER_DERIVATIVES_AVAILABLE
    float distortion = pow(dist, 1.2);
    vec2 dxy = vec2(dFdx(distortion), dFdy(distortion));
    #else
    vec2 dxy = vec2(0.0);
    #endif

    // Align the local UV basis to the axis:
    // - dir is along the axis
    // - perp is perpendicular to the axis
    vec2 dir = normalize(axis);
    vec2 perp = vec2(-dir.y, dir.x);
    uv = vec2(dot(uv, perp), dot(uv, dir));

    // Apply distortion in the aligned space
    uv -= dxy * player_influence * 3.0;

    uv *= 12.0;

    const float width = 0.5; // line width
    const float eps = 0.06;
    const float flatness = 1.1;

    // Scroll along the axis direction (dir). Subtract to move visually along +dir.
    uv.y = fract(uv.y - elapsed / 2.5);
    uv.y /= width;
    uv.y -= width;
    uv.x = fract(uv.x);

    float v = distance(uv.y, (1.0 / flatness) * smooth_abs(uv.x * 2.0 - 1.0));
    float value = smoothstep(width - eps, width + eps, 1.0 - v);

    vec4 color = mix(vertex_color, player_color, dist * player_influence);

    return vec4(vec3(mix(0.2, brightness_offset, value)), 1.0) * color;
}