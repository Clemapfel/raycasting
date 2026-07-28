#ifdef VERTEX

layout (location = 3) in vec2 offset;
layout (location = 4) in float radius;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vertex_position.xy = offset + vertex_position.xy * radius;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

vec4 effect(vec4 vertex_color, sampler2D _, vec2 texture_coords, vec2 frag_position) {
    return vertex_color;
}

#endif