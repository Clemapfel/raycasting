uniform vec2 texel_size; // Size of the upsampled (lower-res) image
uniform float bloom_strength; // Blend factor for upsampled result
uniform Image current_mip; // The current mip level texture

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position) {
    // 3x3 Gaussian kernel (same as downsample for consistency)
    const float kernel[9] = float[](
    1.0/16.0, 2.0/16.0, 1.0/16.0,
    2.0/16.0, 4.0/16.0, 2.0/16.0,
    1.0/16.0, 2.0/16.0, 1.0/16.0
    );

    const vec2 offsets[9] = vec2[](
    vec2(-1, -1), vec2(0, -1), vec2(1, -1),
    vec2(-1,  0), vec2(0,  0), vec2(1,  0),
    vec2(-1,  1), vec2(0,  1), vec2(1,  1)
    );

    // Upsample the lower mip with a 3x3 Gaussian filter
    vec4 upsampled = vec4(0.0);
    for (int i = 0; i < 9; ++i) {
        vec2 offset = offsets[i] * texel_size;
        upsampled += Texel(image, texture_coords + offset) * kernel[i];
    }

    // Sample the current mip at this coordinate
    vec4 current = Texel(current_mip, texture_coords);

    // Blend: add upsampled (scaled by strength) to current mip
    return current + upsampled * bloom_strength;
}