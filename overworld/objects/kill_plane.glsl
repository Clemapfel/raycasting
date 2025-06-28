#define MODE_BASE 0
#define MODE_OUTLINE 1

#ifdef VERTEX

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

vec4 effect(vec4 vertex_color, Image image, vec2 _, vec2 frag_position) {
    return vertex_color;
}

#endif
