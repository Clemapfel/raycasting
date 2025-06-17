#ifdef PIXEL

uniform float elapsed;
const int n = 8; // Number of radial slices

float fast_angle(float dx, float dy) {
    float p = dx / (abs(dx) + abs(dy));
    if (dy < 0.0) {
        return (3.0 - p) / 4.0;
    } else {
        return (1.0 + p) / 4.0;
    }
}

#define PI 3.1415926535897932384626433832795
float slow_angle(float dx, float dy) {
    return (atan(dy, dx) + PI) / (2.0 * PI);
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

vec4 effect(vec4 color, Image img, vec2 uv, vec2 _) {

    const float threshold = 1.0 - 0.9;
    const float eps = 0.01;
    float circle = smoothstep(threshold - eps, threshold + eps, (1.0 - distance(uv, vec2(0.5)) * 2.0));

    uv -= vec2(0.5);
    uv = rotate(uv, 1.0 - distance(uv, vec2(0.0)) * 2.0 * PI + elapsed * 0.0);
    uv += vec2(0.5);

    // Calculate normalized angle in [0, 1)
    vec2 centered = uv - vec2(0.5);
    float angle = fast_angle(centered.x, centered.y); // [0,1)
    float slice_f = angle * float(n);

    // Get current and next slice indices
    float current_slice = floor(slice_f);
    float next_slice = mod(current_slice + 1.0, float(n));

    // Calculate blend factor (how far we are between current and next slice)
    float blend_factor = fract(slice_f);

    // Calculate stripe values for current and next slices
    float current_stripe = mod(current_slice, 2.0);
    float next_stripe = mod(next_slice, 2.0);

    // Smooth blending between slices
    float blend_width = 0.15; // Controls the width of the blend region (0.0 to 0.5)
    float blend_start = 0.5 - blend_width * 0.5;
    float blend_end = 0.5 + blend_width * 0.5;

    float val;
    if (blend_factor < blend_start) {
        // Pure current slice
        val = current_stripe;
    } else if (blend_factor > blend_end) {
        // Pure next slice
        val = next_stripe;
    } else {
        // Blend region - smooth interpolation
        float local_blend = (blend_factor - blend_start) / blend_width;
        local_blend = smoothstep(0.0, 1.0, local_blend); // Apply smoothstep for even smoother transition
        val = mix(current_stripe, next_stripe, local_blend);
    }

    return vec4(vec3(val), circle);
}

#endif // PIXEL