#ifdef PIXEL

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {
    float dist = 1 - distance(texture_coords, vec2(0.5)) * 2;
    return vec4(vec3(dist), 3 * dist);
}

#endif