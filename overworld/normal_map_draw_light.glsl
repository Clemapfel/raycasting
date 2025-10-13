#ifdef PIXEL

#ifndef MAX_N_POINT_LIGHTS
#define MAX_N_POINT_LIGHTS 32
#endif

#ifndef MAX_N_SEGMENT_LIGHTS
#define MAX_N_SEGMENT_LIGHTS 32
#endif

uniform vec2 point_lights[MAX_N_POINT_LIGHTS]; // in screen coords (px, py)
uniform vec4 point_colors[MAX_N_POINT_LIGHTS];
uniform int n_point_lights; // clamped before being send to shader
uniform float point_light_intensity = 1;

uniform vec4 segment_lights[MAX_N_SEGMENT_LIGHTS]; // in screen coords (ax, ay, bx, by)
uniform vec4 segment_colors[MAX_N_SEGMENT_LIGHTS];
uniform int n_segment_lights; // see n_point_lights
uniform float segment_light_intensity = 0.35;

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

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 closest_point_on_segment(vec2 a, vec2 b, vec2 point) {
    vec2 ab = b - a;
    vec2 ap = point - a;
    float ab_length_squared = dot(ab, ab);
    float t = dot(ap, ab) / ab_length_squared;
    t = clamp(t, 0.0, 1.0);
    return a + t * ab;
}

vec4 effect(vec4 vertex_color, Image tex, vec2 texture_coords, vec2 screen_coords) // tex is RG8
{
    vec4 data = texture(tex, texture_coords);
    float mask = data.a;
    if (mask == 0) discard;

    vec2 gradient = normalize((data.yz * 2) - 1); // normalized gradient
    float dist = data.x; // normalized distance;
    vec2 screen_uv = to_uv(screen_coords);

    vec4 point_color = vec4(0);
    for (int i = 0; i < n_point_lights; ++i) {
        vec2 position = to_uv(point_lights[i]);
        vec4 color = point_colors[i];

        float attenuation = gaussian(distance(position, screen_uv) * 2, 1.5); // lower ot increase range
        vec2 light_direction = normalize(position - screen_uv);
        float alignment = max(dot(gradient, light_direction), 0.0);
        float light = alignment * attenuation;
        point_color += point_light_intensity * vec4(vec3(light * color.rgb), 1) * (1 - dist);
    }

    vec4 segment_color = vec4(0);
    for (int i = 0; i < n_segment_lights; ++i) {
        vec4 segment = segment_lights[i];
        vec4 color = segment_colors[i];

        vec2 a_uv = to_uv(segment.xy);
        vec2 b_uv = to_uv(segment.zw);
        vec2 position = closest_point_on_segment(a_uv, b_uv, screen_uv);

        float attenuation = gaussian(distance(position, screen_uv) * 2, 1.5); // lower to increase range

        vec2 light_direction = normalize(position - screen_uv);
        float alignment = max(dot(gradient, light_direction), 0.0);
        float light = alignment * attenuation;
        segment_color += segment_light_intensity * vec4(vec3(light * color.rgb), 1) * (1 - dist);
    }

    if (n_point_lights == 0 && n_segment_lights > n_point_lights)
        return segment_color;
    else if (n_segment_lights == 0 && n_point_lights > n_segment_lights)
        return point_color;
    else
        return mix(point_color, segment_color, 0.5);
}

#endif