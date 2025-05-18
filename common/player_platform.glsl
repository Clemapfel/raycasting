vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = texture(image, texture_coords);
    const float eps = 0.15;
    const float threshold_override = 0.0;
    float value = smoothstep(threshold_override - eps, threshold_override + eps, pixel.a);
    return vec4(pixel.rgb, value);
}