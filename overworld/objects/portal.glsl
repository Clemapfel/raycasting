#ifdef PIXEL

vec4 effect(vec4 vertex_color, Image img, vec2 texture_coords, vec2 frag_position) {
    return vec4(distance(texture_coords.x, 0), 1, 0, distance(texture_coords.y, 0));
}

#endif // PIXEL