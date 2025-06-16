
#define MODE_BASE 0
#define MODE_OUTLINE 1
#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

#ifdef VERTEX

#if MODE == MODE_BASE

layout (location = 0) in vec2 vertex_position;
layout (location = 1) in vec3 contour_vector;
layout (location = 2) in float scale;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

uniform vec2 center;

void vertexmain() {
    vec2 dxdy = contour_vector.xy;
    float magnitude = contour_vector.z;
    vec2 position = center + dxdy * magnitude * scale;

    VaryingTexCoord = vec4(0);
    VaryingColor = gammaCorrectColor(ConstantColor);

    love_Position = TransformProjectionMatrix * vec4(position.xy, 0, 1);
}

#elif MODE == MODE_OUTLINE

// default vertex main

layout (location = 0) in vec4 VertexPosition;
layout (location = 1) in vec4 VertexTexCoord;
layout (location = 2) in vec4 VertexColor;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    VaryingTexCoord = VertexTexCoord;
    VaryingColor = gammaCorrectColor(VertexColor) * ConstantColor;
    love_Position = ClipSpaceFromLocal * VertexPosition;
}

#endif

#endif // VERTEX

#ifdef PIXEL

vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform float elapsed;
uniform float hue;

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

#define PI 3.1415926535897932384626433832795

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_uv(vertex_position);
    uv += elapsed / 20;
    uv = rotate(uv, -0.25 * PI);
    uv *= 2;
    float noise = gradient_noise(vec3(vec2(4, 1) * uv, 0));

    #if MODE == MODE_BASE
    const float hue_offset = 0.1;
    return vec4(lch_to_rgb(vec3(0.8, 1, fract(mix(hue - hue_offset, hue + hue_offset, (noise + 1) / 2)))), 0.4 * (noise + 1) / 2);
    #elif MODE == MODE_OUTLINE
    const float hue_offset = 0.4;
    return vec4(lch_to_rgb(vec3(0.8, 1, fract(mix(hue - hue_offset, hue + hue_offset, (noise + 1) / 2)))), 1);
    #endif
}

#endif // PIXEL