#ifdef VERTEX

layout (location = 3) in vec2 particle_position;
layout (location = 4) in float particle_radius;
layout (location = 5) in vec4 particle_color;

varying vec4 color_override;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vertex_position.xy = vertex_position.xy * particle_radius + particle_position;
    color_override = particle_color;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

varying vec4 color_override;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    return color_override * texture(img, texture_coords);
}

#endif