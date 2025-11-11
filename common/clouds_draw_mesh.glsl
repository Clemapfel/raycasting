#ifdef VERTEX

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 texture_coords;
layout (location = 2) in vec4 color;

out vec3 varying_texture_coords;
out vec4 varying_color;

void vertexmain() {
    varying_texture_coords = texture_coords;
    varying_color = gammaCorrectColor(ConstantColor * color);
    love_Position = TransformProjectionMatrix * vec4(position.xyz, 1);
}

#endif // VERTEX

#ifdef PIXEL

in vec3 varying_texture_coords;
in vec4 varying_color;

uniform sampler3D volume_texture;

out vec4 frag_color;

void pixelmain() {
    frag_color = texture(volume_texture, varying_texture_coords);
}

#endif // PIXEL