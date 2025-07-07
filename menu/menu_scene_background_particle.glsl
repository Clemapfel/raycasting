#ifdef PIXEL

float shape(float r, float concavity) {
    return max(1.0 - pow(r, concavity), 0) * smoothstep(1.0, 0.9, r);
}

float shape2(float r) {
    return 1 - r;
}

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    float r = distance(texture_coordinates, vec2(0.5)) * 2.0;
    float concavity = 1.5;
    float value = shape2(clamp(r, 0.0, 1.0));
    return vec4(vec3(1), value);
}

#endif