#ifdef PIXEL

uniform float offset[3] = float[](0.0, 1.3846153846, 3.2307692308);
uniform float weight[3] = float[](0.2270270270, 0.3162162162, 0.0702702703);
uniform float relaxation_factor = 1; // 0 = no relaxation, 1 = full relaxation

// src: https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 frag_position)
{
    vec2 texture_size = textureSize(img, 0);
    float value = texture(img, frag_position / texture_size.xy).z * weight[0];

    #if HORIZONTAL_OR_VERTICAL == 1
    for (int i = 1; i < 3; i++) {
        float o = offset[i] / texture_size.y;
        float sample1 = texture(img, (texture_coords + vec2(0.0, o))).z;
        float sample2 = texture(img, (texture_coords - vec2(0.0, o))).z;
        value += sample1 * weight[i];
        value += sample2 * weight[i];

    }
    #elif HORIZONTAL_OR_VERTICAL == 0
    for (int i = 1; i < 3; i++) {
        float o = offset[i] / texture_size.x;
        float sample1 = texture(img, (texture_coords + vec2(o, 0.0))).z;
        float sample2 = texture(img, (texture_coords - vec2(o, 0.0))).z;
        value += sample1 * weight[i];
        value += sample2 * weight[i];
    }
    #endif

    vec2 texel = 1.0 / texture_size;
    float up    = texture(img, texture_coords + vec2(0.0,  texel.y)).z;
    float down  = texture(img, texture_coords - vec2(0.0,  texel.y)).z;
    float left  = texture(img, texture_coords - vec2(texel.x, 0.0)).z;
    float right = texture(img, texture_coords + vec2(texel.x, 0.0)).z;

    float relaxed = (value + up + down + left + right) / 5.0;
    value = mix(value, relaxed, 0.0);

    vec4 current = texelFetch(img, ivec2(round(texture_coords * texture_size)), 0);
    return vec4(current.xy, relaxed, current.w);
}

#endif