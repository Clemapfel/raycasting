
#ifdef VERTEX

layout (location = 3) in vec2 offset;
layout (location = 4) in float scale;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 center = vec2(0);

    vec2 dxy = vertex_position.xy - center;
    float dist = length(dxy);
    dxy = normalize(dxy);
    vertex_position.xy = offset + dist * dxy * scale; // don't scale center

    return transform_projection * vertex_position;
}

#endif

