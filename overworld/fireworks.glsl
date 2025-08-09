#ifdef VERTEX

/*
layout (location = 0) in vec2 VertexPosition;
layout (location = 1) in vec2 VertexTexCoord;
layout (location = 2) in vec4 VertexColor;
*/

layout (location = 3) in vec3 particle_position;
layout (location = 4) in vec4 particle_color;
layout (location = 5) in vec3 velocity;
layout (location = 6) in vec3 explosion_direction;
layout (location = 7) in float explosion_force;
layout (location = 8) in float mass;
layout (location = 9) in float radius;
layout (location = 10) in float lifetime;

out vec4 vertex_color;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 center = vec2(0);

    vec2 dxy = vertex_position.xy - center;
    float dist = length(dxy);
    dxy = normalize(dxy);
    vertex_position.xy = particle_position.xy + dxy * radius * dist; // * dist to not scale center

    vertex_color = particle_color;

    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

in vec4 vertex_color;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    return color * vertex_color;
}

#endif