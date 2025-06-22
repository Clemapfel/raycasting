uniform vec2 texel_size;

const float kernel[9] = float[](
    1.0/16.0, 2.0/16.0, 1.0/16.0,
    2.0/16.0, 4.0/16.0, 2.0/16.0,
    1.0/16.0, 2.0/16.0, 1.0/16.0
);

const vec2 offsets[9] = vec2[](
    vec2(-1, -1), vec2(0, -1), vec2(1, -1),
    vec2(-1,  0), vec2(0,  0), vec2(1,  0),
    vec2(-1,  1), vec2(0,  1), vec2(1,  1)
);

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {
    vec2 uv = texture_coords;
    vec4 color = vec4(0.0);
    for (int i = 0; i < 9; ++i)
        color += Texel(image, uv + offsets[i] * texel_size) * kernel[i];

    return color;
}