#ifdef PIXEL

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 texel = texture(img, texture_coordinates);

    float center = 0.0;
    float fill_eps = 0.01;
    float outline_eps = 0.1;

    float fill_value = smoothstep(max(center - fill_eps, 0.0), min(center + fill_eps, 1.0), texel.a);
    vec4 fill = vec4(0.2, 0.2, 0.2, 1.0);
    
    float outline_value = dirac(smoothstep(max(center - outline_eps, 0.0), min(center + outline_eps, 1.0), texel.a));
    vec4 outline = vec4(1.0, 1.0, 1.0, 1.0);

    return vec4(fill_value * fill + outline_value * outline);
}

#endif // PIXEL

