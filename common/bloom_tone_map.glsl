#ifdef PIXEL

vec3 aces_approx(vec3 v) {
    // src: https://64.github.io/tonemapping/
    v *= 0.6;
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec4 hdr = texture(img, texture_coords);
    if (hdr.a == 0) discard;

    return color * vec4(aces_approx(hdr.rgb), 1.0);
}

#endif