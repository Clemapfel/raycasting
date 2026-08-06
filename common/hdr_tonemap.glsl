// src: https://github.com/KhronosGroup/ToneMapping/blob/main/PBR_Neutral/README.md#pbr-neutral-specification

const float fresnel_90 = 0.04;
const float compression_start = 2.0;
const float desaturation_speed = 0.15;

vec3 tonemap(vec3 rgb) {
    float minimum = min(rgb.r, min(rgb.g, rgb.b));

    // Branchless selection of offset
    float cond1 = step(minimum, 2.0 * fresnel_90);
    float offset1 = minimum - (minimum * minimum) / (4.0 * fresnel_90);
    float offset = mix(fresnel_90, offset1, cond1);

    vec3 color_offset = rgb - offset;
    float peak = max(color_offset.r, max(color_offset.g, color_offset.b));

    // Branchless selection between early return (peak <= 2.0) and compressed path
    float cond2 = step(peak, compression_start);

    // Compute the compressed result safely, even when it will not be used
    float excess = max(peak - compression_start, 0.0);            // avoid negative / zero division
    float peak_new = compression_start + excess / (excess + 1.0);
    float compression_amount = peak - peak_new;
    float desaturation_factor = 1.0 / (1.0 + desaturation_speed * compression_amount);

    float peak_safe = max(peak, 1e-10);                           // avoid division by zero
    vec3 blend_result = mix(vec3(peak_new), color_offset * (peak_new / peak_safe), desaturation_factor);

    // Choose the correct output
    return mix(blend_result, color_offset, cond2);
}

vec4 effect(vec4 vertex_color, sampler2D image, vec2 texture_coordinates, vec2 fragment_position) {
    vec4 hdr = texture(image, texture_coordinates);
    return vec4(tonemap(hdr.rgb), 1.0);
}