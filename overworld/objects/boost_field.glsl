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

vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

uniform vec2 axis = vec2(0, -1);

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coordinates, vec2 frag_position) {
    vec2 uv = to_uv(frag_position - origin_offset);

    float angle = atan(axis.y, axis.x) + 0.5 * PI;
    uv = rotate(uv, -angle);

    uv *= 20;

    const float width = 0.5;
    const float eps = 0.2;
    const float flatness = 2;

    uv.y = fract(uv.y + elapsed);
    uv.y /= width;
    uv.y -= width;
    uv.x = fract(uv.x);


    float v = distance(uv.y, (1 / flatness) * smooth_abs(uv.x * 2 - 1));
    float value = smoothstep(width - eps, width + eps, 1 - v);
    vec3 color = lch_to_rgb(vec3(0.8, 1, angle / (2 * PI)));
    return vec4(vec3(color) *  mix(0.7, 1, value), 1) * vertex_color;
}