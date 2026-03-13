#ifdef VERTEX

layout (location = 3) in vec3 particle_position;
layout (location = 4) in float particle_radius;
layout (location = 5) in vec4 particle_color;

out vec4 vertex_color;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vertex_position.xy = particle_position.xy + vertex_position.xy * particle_radius;
    vertex_color = particle_color;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

in vec4 vertex_color;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    return color * vertex_color;
}

#endif