#ifdef VERTEX

layout (location = 3) in vec2 particle_position;
layout (location = 4) in float particle_radius;

uniform float texture_scale = 1;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    float scale = particle_radius * texture_scale;
    vec2 offset = particle_position;
    vertex_position.xy = vertex_position.xy * scale + offset;
    return transform_projection * vertex_position;
}

#endif
