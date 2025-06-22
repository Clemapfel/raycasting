#ifdef PIXEL

uniform vec2 texel_size;

const float kernel[9] = float[](
    1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
    2.0 / 16.0, 4.0 / 16.0, 2.0 / 16.0,
    1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0
);

const vec2 offsets[9] = vec2[](
    vec2(-1, -1), vec2(0, -1), vec2(1, -1),
    vec2(-1,  0), vec2(0,  0), vec2(1,  0),
    vec2(-1,  1), vec2(0,  1), vec2(1,  1)
);

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec2 uv = texture_coords;

    vec4 color = vec4(0.0);
    color += texture(img, uv + offsets[0] * texel_size) * kernel[0];
    color += texture(img, uv + offsets[1] * texel_size) * kernel[1];
    color += texture(img, uv + offsets[2] * texel_size) * kernel[2];
    color += texture(img, uv + offsets[3] * texel_size) * kernel[3];
    color += texture(img, uv + offsets[4] * texel_size) * kernel[4];
    color += texture(img, uv + offsets[5] * texel_size) * kernel[5];
    color += texture(img, uv + offsets[6] * texel_size) * kernel[6];
    color += texture(img, uv + offsets[7] * texel_size) * kernel[7];
    color += texture(img, uv + offsets[8] * texel_size) * kernel[8];

    return color;
}

#endif