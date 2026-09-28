// src: https://github.com/KhronosGroup/ToneMapping/blob/main/PBR_Neutral/README.md#pbr-neutral-specification

const float fresnel_90 = 0.025;
const float compression_start = 1.0 - fresnel_90;
const float desaturation_speed = 0.15;

float relu(float x, float eps) {
    // smoothed version of max(x, 0)
    return 0.5 * (x + sqrt(x * x + eps));
}

vec3 tonemap(vec3 rgb) {
    float m = relu(
        min(rgb.r, min(rgb.g, rgb.b)),
        2.0 * fresnel_90 // 2.0 is empirically tuned, not mathematically motivated
    );

    vec3 offset = rgb - mix(
        fresnel_90,
        m - (m * m) / (4.0 * fresnel_90),
        step(m, 2.0 * fresnel_90)
    );

    float peak = max(offset.r, max(offset.g, offset.b));

    if (peak > compression_start) {
        float d = 1.0 - compression_start;
        float peak_new = 1.0 - (d * d) / ((peak - compression_start) + d);

        return mix(
        vec3(peak_new),
        offset * (peak_new / peak),
        1.0 / (1.0 + desaturation_speed * (peak - peak_new))
        );
    }

    return offset;
}

vec4 effect(vec4 vertex_color, sampler2D image, vec2 texture_coordinates, vec2 fragment_position) {
    vec4 hdr = texture(image, texture_coordinates);
    return vec4(tonemap(hdr.rgb), 1.0);
}