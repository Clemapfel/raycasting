vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    float dist = distance(texture_coords, vec2(0.5)) * 2.0;
    return vec4(dist);
}