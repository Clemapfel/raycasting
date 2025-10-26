#ifdef VERTEX

layout (location = 3) in vec3 offset;
layout (location = 4) in float scale;
layout (location = 5) in vec4 rotation; // quaternion

vec3 rotate(vec3 vector, vec4 quaternion)
{
    vec3 u = quaternion.xyz;
    float s = quaternion.w;

    vec3 uv = cross(u, vector);
    vec3 uuv = cross(u, uv);
    return vector + 2.0 * (s * uv + uuv);
}

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vec3 dxyz = vertex_position.xyz; // local position (around origin)
    dxyz *= scale;
    dxyz = rotate(dxyz, rotation);
    dxyz += offset;
    return transform_projection * vec4(dxyz, vertex_position.w);
}

#endif
