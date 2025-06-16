#ifdef VERTEX

layout(location = 3) in vec3 axis_offset;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 axis = axis_offset.xy;
    float offset = axis_offset.z;
    vertex_position.xy += axis * offset;
    return transform_projection * vertex_position;
}

#endif