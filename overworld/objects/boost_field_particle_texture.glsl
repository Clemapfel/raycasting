#ifdef PIXEL

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    float dist = 2.0 * distance(texture_coords, vec2(0.5));
    float height = sqrt(max(0.0, 1.0 - dist * dist));
    return vec4(height);
}

#endif