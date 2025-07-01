
#ifdef VERTEX

layout (location = 3) in vec2 offset;
layout (location = 4) in float radius;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 center = vec2(0);

    vec2 dxy = vertex_position.xy - center;
    float dist = length(dxy);
    dxy = normalize(dxy);
    vertex_position.xy = offset + dxy * radius * dist; // * dist to not scale center

    return transform_projection * vertex_position;
}

#endif

