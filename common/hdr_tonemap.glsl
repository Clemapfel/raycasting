// src: https://github.com/KhronosGroup/ToneMapping/blob/main/PBR_Neutral/README.md#pbr-neutral-specification
// Modified to support compression_start > 1

uniform float fresnel_90 = 0.04;
uniform float compression_start = 2.0;
uniform float desaturation_speed = 0.15;

vec3 tonemap(vec3 rgb) {
    float minimum = min(rgb.r, min(rgb.g, rgb.b));

    float offset;
    if (minimum <= 2.0 * fresnel_90) {
        offset = minimum - (minimum * minimum) / (4.0 * fresnel_90);
    } else {
        offset = fresnel_90;
    }

    vec3 color_offset = rgb - offset;
    float peak = max(color_offset.r, max(color_offset.g, color_offset.b));

    if (peak <= compression_start) {
        return color_offset;
    }

    // Modified compression formula that works for compression_start > 1
    // Maps [compression_start, infinity) to [compression_start, compression_start + 1)
    // Using a hyperbolic curve: f(x) = K_s + (x - K_s) / (x - K_s + 1)
    float excess = peak - compression_start;
    float peak_new = compression_start + excess / (excess + 1.0);

    // Adjusted desaturation that works across all ranges
    // Desaturate based on how much compression was applied
    float compression_amount = peak - peak_new;
    float desaturation_factor = 1.0 / (desaturation_speed * compression_amount + 1.0);

    return mix(
    vec3(peak_new),
    color_offset * (peak_new / peak),
    desaturation_factor
    );
}

vec4 effect(vec4 vertex_color, sampler2D image, vec2 texture_coordinates, vec2 fragment_position) {
    vec4 hdr = texture(image, texture_coordinates);
    return vec4(tonemap(hdr.rgb), 1.0);
}