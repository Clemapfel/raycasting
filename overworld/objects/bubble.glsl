#ifdef PIXEL

uniform vec2 pop_origin;   // spherical coords of the pop center
uniform float pop_fraction; // current spread radius [0..1]

const float edge_thickness = 0.05; // softness of the gradient edge

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;
    float dist = distance(uv, pop_origin) * pop_fraction;
    return color * vec4(dist) * pop_fraction;
}

#endif
