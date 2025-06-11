#ifdef PIXEL

vec4 effect(vec4 vertex_color, Image img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 mask = texture(img, texture_coordinates);
    return mask;
}


#endif