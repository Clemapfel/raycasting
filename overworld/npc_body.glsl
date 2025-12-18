#ifdef PIXEL

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec4 texel = texture(img, texture_coords);
    return vec4(texel.rgb * (1 + vertex_color.a), texel.a);
}

#endif