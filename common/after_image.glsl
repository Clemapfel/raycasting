vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    float value = texture(img, texture_coords);
    return vec4(vec3(value), step(value, 0)); // r8 to grayscale
}