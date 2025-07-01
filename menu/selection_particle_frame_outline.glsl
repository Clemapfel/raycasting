#define MODE_OUTLINE 0
#define MODE_BASE 1

#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

mat3 sobel_x = mat3(
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
);

mat3 sobel_y = mat3(
    -1, -2, -1,
     0, 0, 0,
     1, 2, 1
);

vec4 effect(vec4 color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {

    vec2 pixel_size = vec2(1 / 400.0);

    float threshold = 0.5; // metaball threshold
    float smoothness = 0.2; // smoothness factor for blending

    #if MODE == MODE_OUTLINE

        float outline_thickness = 1.5;
        float gradient_x = 0.0;
        float gradient_y = 0.0;

        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                vec2 neighbor_uv = texture_coordinates + vec2(i, j) * pixel_size * outline_thickness;
                float value = texture(img, neighbor_uv).a;
                value = smoothstep(threshold - smoothness, threshold + smoothness, value);

                gradient_x += value * sobel_x[i + 1][j + 1];
                gradient_y += value * sobel_y[i + 1][j + 1];
            }
        }

        float magnitude = length(vec2(gradient_x, gradient_y));
        float alpha = smoothstep(0.0, 1.0, magnitude); // Adjust alpha blending
        return vec4(vec3(1.0), alpha) * color;

    #elif MODE == MODE_BASE
        float value = texture(img, texture_coordinates).a;
        return vec4(smoothstep(threshold - smoothness, threshold + smoothness, value)) * color;

    #endif
}