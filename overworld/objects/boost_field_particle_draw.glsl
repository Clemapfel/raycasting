#ifdef VERTEX

layout (location = 0) in vec3 vertex_position;
layout (location = 1) in vec3 vertex_texture_coords;
layout (location = 2) in vec4 vertex_color;
layout (location = 3) in vec2 instance_offset;
layout (location = 4) in float instance_radius;
layout (location = 5) in vec4 instance_color;

out vec3 varying_texture_coords;
out vec4 varying_color;

void vertexmain() {
    varying_texture_coords = vertex_texture_coords;
    varying_color = gammaCorrectColor(vertex_color * instance_color);

    vec2 position = vertex_position.xy * instance_radius + instance_offset;
    love_Position = TransformProjectionMatrix * vec4(
        position.xy,
        vertex_position.z,
        1.0
    );
}

#endif // VERTEX

#ifdef PIXEL

in vec3 varying_texture_coords;
in vec4 varying_color;

out vec4 frag_color;

uniform sampler2D instance_texture;

void pixelmain() {
    frag_color = varying_color * texture(instance_texture, varying_texture_coords.xy);
}

#endif // PIXEL