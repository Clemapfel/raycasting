#ifdef PIXEL

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {

    // filter metaballs that do not hit outline threshold
    float value = texture(img, texture_coords).a;
    float eps = 0.55;
    return color * vec4(smoothstep(1 - eps, 1, value));
}

#endif