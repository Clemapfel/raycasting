#ifdef PIXEL

uniform float offset[3] = float[](0.0, 1.3846153846, 3.2307692308);
uniform float weight[3] = float[](0.2270270270, 0.3162162162, 0.0702702703);

uniform vec2 texture_size;

// src: https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position)
{
    vec4 color = Texel(image, frag_position / texture_size.xy) * weight[0];

    #if HORIZONTAL_OR_VERTICAL == 1
    for (int i = 1; i < 3; i++) {
        float offset = offset[i] / texture_size.y;
        color += texture(image, (texture_coords + vec2(0.0, offset))) * weight[i];
        color += texture(image, (texture_coords - vec2(0.0, offset))) * weight[i];
    }
    #elif HORIZONTAL_OR_VERTICAL == 0
    for (int i = 1; i < 3; i++) {
        float offset = offset[i] / texture_size.x;
        color += texture(image, (texture_coords + vec2(offset, 0.0))) * weight[i];
        color += texture(image, (texture_coords - vec2(offset, 0.0))) * weight[i];
    }
    #endif

    return color;
}

#endif