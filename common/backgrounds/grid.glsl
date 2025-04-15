#ifdef PIXEL

uniform float elapsed;
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

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

float merge(float x, float y) {
    return max(x, y);
}

vec4 effect(vec4 vertex_color, Image image, vec2 _, vec2 frag_position) {
    vec2 uv = to_uv(frag_position);
    float aspect_ratio = love_ScreenSize.x / love_ScreenSize.y;
    vec2 pixel_size = 1 / love_ScreenSize.xy;

    float line_thickness = pixel_size.x * 20;
    const float eps = 0.001;

    float tile_size = 32.0;
    float scale = love_ScreenSize.x / tile_size;
    uv = uv * scale;
    uv -= line_thickness;
    uv = fract(uv);

    float base_color = 0.2;
    float line_color_light = 0.23;
    float line_color_dark = 0.185;

    float lower = line_thickness - eps;
    float upper = line_thickness + eps;

    float value = 0;
    value = merge(value, (1 - smoothstep(lower, upper, distance(uv.x, line_thickness - pixel_size.x))) * line_color_light);
    value = merge(value, (1 - smoothstep(lower, upper, distance(uv.y, line_thickness - pixel_size.y))) * line_color_light);
    value = merge(value, (1 - smoothstep(lower, upper, distance(uv.x, 1 - (line_thickness + pixel_size.x)))) * line_color_dark);
    value = merge(value, (1 - smoothstep(lower, upper, distance(uv.y, 1 - (line_thickness + pixel_size.y)))) * line_color_dark);

    return vec4(vec3(merge(base_color, value)), 1);
}

#endif