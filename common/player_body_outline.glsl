#ifdef PIXEL

uniform vec2 screen_size;
uniform vec4 outline_color;
uniform vec4 body_color;
uniform float texture_scale;
uniform float outline_thickness = 1;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 frag_position) {
    vec2 pixel_size = (outline_thickness + texture_scale) / vec2(textureSize(tex, 0));

    vec4 center = texture(tex, texture_coordinates);

    // cone structuring element
    const float radius = 2.0 * sqrt(2.0);
    const float cardinal = 1.0 - 1.0          / (2.0 * sqrt(2.0));
    const float diagonal = 1.0 - sqrt(2.0)    / (2.0 * sqrt(2.0));
    const float two_cardinal = 1.0 - 2.0      / (2.0 * sqrt(2.0));
    const float root_five = 1.0 - sqrt(5.0)   / (2.0 * sqrt(2.0));

    const float kernel[25] = float[25](
        0.0,          root_five,    two_cardinal, root_five,    0.0,
        root_five,    diagonal,     cardinal,     diagonal,     root_five,
        two_cardinal, cardinal,     0.0,          cardinal,     two_cardinal,
        root_five,    diagonal,     cardinal,     diagonal,     root_five,
        0.0,          root_five,    two_cardinal, root_five,    0.0
    );

    float max_alpha = 0.0;
    for (int row = 0; row < 5; row++) {
        for (int col = 0; col < 5; col++) {
            int dx = col - 2;
            int dy = row - 2;
            float weight = kernel[row * 5 + col];

            if (weight > 0) {
                vec2 offset = vec2(float(dx), float(dy)) * pixel_size;
                float neighbour_alpha = texture(tex, texture_coordinates + offset).r;
                max_alpha = max(max_alpha, neighbour_alpha * weight);
            }
        }
    }

    max_alpha -= center.a;
    max_alpha = smoothstep(0.0, 1.0, 2 * max_alpha); // mathematically unmotivated, but looks better this way

    return mix(body_color, outline_color, max_alpha) * max(max_alpha, center.a);
}

#endif