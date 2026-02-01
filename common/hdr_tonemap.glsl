// src: https://github.com/KhronosGroup/ToneMapping/blob/main/PBR_Neutral/README.md#pbr-neutral-specification

uniform float fresnel_90 = 0.04;         // F_90: fresnel reflection at normal incidence (index of refraction = 1.5)
uniform float compression_start = 0.95;  // K_s: highlight compression starts (0.8 - F_90)
uniform float desaturation_speed = 0.15; // K_d: speed of desaturation

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

    float peak_new = 1.0 - ((1.0 - compression_start) * (1.0 - compression_start)) /
        (peak + 1.0 - 2.0 * compression_start);

    float desaturation_factor = 1.0 / (desaturation_speed * (peak - peak_new) + 1.0);
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
