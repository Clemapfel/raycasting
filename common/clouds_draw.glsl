#pragma glsl4
#ifdef VERTEX

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 texture_coords;
layout (location = 2) in vec4 color;

out vec3 varying_texture_coords;
out vec4 varying_color;
out vec4 varying_frag_position;

void vertexmain() {
    varying_texture_coords = texture_coords;
    varying_color = gammaCorrectColor(ConstantColor * color);
    varying_frag_position = TransformProjectionMatrix * vec4(position.xyz, 1.0);
    love_Position = varying_frag_position;
}

#endif // VERTEX

#ifdef PIXEL

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

in vec3 varying_texture_coords;
in vec4 varying_color;
in vec4 varying_frag_position;

uniform sampler2DArray export_texture;
uniform float n_layers;
uniform float hue;
uniform float whiteness;
uniform float hue_offset;

out vec4 frag_color;

void pixelmain() {
    float value = texture(export_texture, varying_texture_coords).r;
    vec3 layer_color = lch_to_rgb(vec3(0.8, 1, fract(mix(hue - hue_offset, hue + hue_offset, varying_texture_coords.z / n_layers))));
    frag_color = vec4(layer_color, 1) * vec4(vec3(min(whiteness * value, 1)), value);
}

#endif // PIXEL