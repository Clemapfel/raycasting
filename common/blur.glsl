#ifdef PIXEL

uniform float offset[3] = float[](0.0, 1.3846153846, 3.2307692308);
uniform float weight[3] = float[](0.2270270270, 0.3162162162, 0.0702702703);

uniform vec2 texture_size;
uniform float relaxation_factor = 1; // 0 = no relaxation, 1 = full relaxation

// src: https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position)
{
    vec4 color = Texel(image, frag_position / texture_size.xy) * weight[0];
    float alpha = color.a * weight[0];

    #if HORIZONTAL_OR_VERTICAL == 1
    for (int i = 1; i < 3; i++) {
        float o = offset[i] / texture_size.y;
        vec4 sample1 = texture(image, (texture_coords + vec2(0.0, o)));
        vec4 sample2 = texture(image, (texture_coords - vec2(0.0, o)));
        color += sample1 * weight[i];
        color += sample2 * weight[i];
        alpha += sample1.a * weight[i];
        alpha += sample2.a * weight[i];
    }
    #elif HORIZONTAL_OR_VERTICAL == 0
    for (int i = 1; i < 3; i++) {
        float o = offset[i] / texture_size.x;
        vec4 sample1 = texture(image, (texture_coords + vec2(o, 0.0)));
        vec4 sample2 = texture(image, (texture_coords - vec2(o, 0.0)));
        color += sample1 * weight[i];
        color += sample2 * weight[i];
        alpha += sample1.a * weight[i];
        alpha += sample2.a * weight[i];
    }
    #endif

    color.a = alpha;

    // --- Relaxation/Diffusion Step ---
    vec2 texel = 1.0 / texture_size;
    vec4 up    = texture(image, texture_coords + vec2(0.0,  texel.y));
    vec4 down  = texture(image, texture_coords - vec2(0.0,  texel.y));
    vec4 left  = texture(image, texture_coords - vec2(texel.x, 0.0));
    vec4 right = texture(image, texture_coords + vec2(texel.x, 0.0));

    vec4 relaxed = (color + up + down + left + right) / 5.0;
    color = mix(color, relaxed, relaxation_factor);

    return color;
}

#endif