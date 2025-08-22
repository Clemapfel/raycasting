vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    if (color.a < 0.75) discard;
    return vec4(1);
}