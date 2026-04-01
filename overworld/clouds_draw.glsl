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

uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

in vec3 varying_texture_coords;
in vec4 varying_color;
in vec4 varying_frag_position;

uniform sampler2DArray export_texture;
uniform float n_layers;
uniform float hue;
uniform float opacity;
uniform float hue_offset;

out vec4 frag_color;

void pixelmain() {
    float value = texture(export_texture, varying_texture_coords).r;
    if (value < 10e-3) discard;

    vec3 layer_color = lch_to_rgb(vec3(0.8, 1, fract(mix(hue - hue_offset, hue + hue_offset, varying_texture_coords.z / n_layers))));
    frag_color = vec4(layer_color, 1) * vec4(vec3(min(6 * value, 1)), opacity * value);
}

#endif // PIXEL