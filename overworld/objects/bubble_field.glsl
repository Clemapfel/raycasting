
#define MODE_BASE 0
#define MODE_OUTLINE 1
#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

#ifdef VERTEX

#if MODE == MODE_BASE

layout (location = 0) in vec2 position; // start of vector
layout (location = 1) in vec3 contour_vector; // xy normalized, z magnitude
layout (location = 2) in float scale; // magnitude scale

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    vec2 dxdy = contour_vector.xy;
    float magnitude = contour_vector.z;
    vec2 position = position + dxdy * magnitude * scale;

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

uniform sampler3D noise_texture;
float gradient_noise(vec3 p) {
    p /= 24;
    return texture(noise_texture, p).r;
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
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

uniform float elapsed;
uniform float hue;

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_world_position(vertex_position) / 60;
    float noise = gradient_noise(vec3(uv, elapsed / 4));

    #if MODE == MODE_BASE
    const float hue_offset = 0.1;
    float alpha = noise;
    #elif MODE == MODE_OUTLINE
    const float hue_offset = 0.4;
    float alpha = 1;
    #endif

    float final_hue = mix(hue - hue_offset, hue + hue_offset, noise);
    return color * vec4(lch_to_rgb(vec3(0.8, 1, final_hue)), alpha);
}

#endif // PIXEL