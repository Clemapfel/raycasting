vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    return vec4(texture(img, texture_coords).xxxx); // r8 to grayscale
}