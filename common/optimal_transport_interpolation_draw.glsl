#ifdef PIXEL

// Uniforms for better control
uniform float u_sdf_scale = 1.0;        // Scale factor for SDF values
uniform float u_smoothing = 0.6;       // Smoothing amount (0.0 = sharp, 1.0 = very smooth)
uniform float u_threshold = 0.7;        // SDF threshold for edge detection
uniform float u_outline_width = 0.05;    // Optional outline width
uniform vec3 u_outline_color = vec3(0.0, 0.0, 0.0); // Outline color

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
{
    // Sample the SDF value
    float dist = sqrt(Texel(tex, tc).r);

    // Calculate adaptive epsilon based on screen-space derivatives
    // This helps maintain consistent edge quality across different zoom levels
    vec2 grad = vec2(dFdx(dist), dFdy(dist));

    // Adaptive epsilon that works better for varying scales and close letters
    float eps = u_smoothing * length(grad); // Minimum epsilon to prevent division issues

    // Main text alpha
    float alpha = smoothstep(u_threshold - eps, u_threshold + eps, dist);

    // Optional outline effect
    if (u_outline_width > 0.0) {
        float outline_threshold = u_threshold - u_outline_width;
        float outline_alpha = smoothstep(outline_threshold - eps, outline_threshold + eps, dist);

        // Blend outline with main text
        vec3 final_color = mix(u_outline_color, color.rgb, alpha);
        float final_alpha = max(alpha, outline_alpha * (1.0 - alpha));

        return vec4(final_color, color.a * final_alpha);
    }

    return vec4(color.rgb, color.a * alpha);
}

#endif