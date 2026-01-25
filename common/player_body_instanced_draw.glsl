#ifdef VERTEX

layout (location = 3) in vec2 particle_position;
layout (location = 4) in vec2 particle_radius; // x: normal, y: contour
layout (location = 5) in float particle_opacity;

uniform float texture_scale = 1;
uniform float contour_interpolation_factor = 0;

varying float opacity;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float scale = mix(
        particle_radius.x,
        particle_radius.y,
        contour_interpolation_factor
    ) * texture_scale;

    vertex_position.xy = vertex_position.xy * scale + particle_position.xy;

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