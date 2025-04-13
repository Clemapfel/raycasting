vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 screen_coords) {
    vec4 texel = texture(image, texture_coords);

    return texel;
}