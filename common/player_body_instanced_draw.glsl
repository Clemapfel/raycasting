#ifdef VERTEX

layout (location = 3) in vec4 particle_position; // xy: current xy, zw: last frame xy
layout (location = 4) in vec2 particle_velocity;
layout (location = 5) in float particle_radius;

uniform float interpolation_alpha = 1;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 current_position = particle_position.xy;
    vec2 previous_position = particle_position.zw;

    float scale = particle_radius;

    vec2 offset = mix(previous_position, current_position, interpolation_alpha);
    vertex_position.xy = vertex_position.xy * scale + offset;

    return transform_projection * vertex_position;
}

#endif
