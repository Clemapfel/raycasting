#ifdef VERTEX

layout (location = 3) in vec4 particle_position; // xy: current xy, zw: last frame xy
layout (location = 4) in vec2 particle_velocity;
layout (location = 5) in vec2 particle_radius; // x: normal, y: contour
layout (location = 6) in float particle_opacity;


uniform float interpolation_alpha = 1;
uniform float texture_scale = 1;
uniform bool use_contour;

varying float opacity;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 current_position = particle_position.xy;
    vec2 previous_position = particle_position.zw;

    float scale = (use_contour ? particle_radius.y : particle_radius.x) * texture_scale;
    vec2 offset = mix(previous_position, current_position, interpolation_alpha);

    vertex_position.xy = vertex_position.xy * scale + offset;

    opacity = particle_opacity;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

varying float opacity;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    return color * texture(img, texture_coords) * vec4(opacity);
}

#endif