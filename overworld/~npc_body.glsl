vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    return vec4(texture_coords.xyx, 1);
}