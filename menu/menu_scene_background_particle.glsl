#ifdef PIXEL

float shape(float r, float concavity) {
    return max(1.0 - pow(r, concavity), 0) * smoothstep(1.0, 0.95, r);
}

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    float r = distance(texture_coordinates, vec2(0.5)) * 2.0;
    float concavity = 1.5;
    float value = shape(clamp(r, 0.0, 1.0), concavity);
    return vec4(vec3(1), value);
}

#endif