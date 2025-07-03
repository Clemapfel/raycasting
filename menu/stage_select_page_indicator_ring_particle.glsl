
#ifdef VERTEX

layout (location = 3) in vec2 offset;
layout (location = 4) in float radius;
layout (location = 5) in vec3 rgb;

varying vec3 particle_color;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 center = vec2(0);

    vec2 dxy = vertex_position.xy - center;
    float dist = length(dxy);
    dxy = normalize(dxy);
    vertex_position.xy = offset + dxy * radius * dist; // * dist to not scale center

    particle_color.rgb = rgb;

    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

varying vec3 particle_color;

vec4 effect(vec4 vertex_color, sampler2D _, vec2 texture_coords, vec2 frag_position) {
    return vec4(vertex_color.rgb * particle_color.rgb, vertex_color.a);
}

#endif

