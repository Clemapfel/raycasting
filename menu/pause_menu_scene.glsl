#ifdef PIXEL

uniform float elapsed;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {

    return vec4(vec3(1, 0, 1), 1 - distance(texture_coords.x, 0.5));
}

#endif