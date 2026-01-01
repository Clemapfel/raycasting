#define MODE_THRESHOLD 0
#define MODE_OUTLINE 1

#ifndef MODE
#error "`MODE` undefined, should be 0 or 1"
#endif

#if MODE == MODE_THRESHOLD

uniform float threshold = 0.5;
uniform float smoothness = 0.05;

vec4 effect(vec4 color, Image img, vec2 texture_coordinates, vec2 frag_position) {

    vec4 data = texture(img, texture_coordinates);
    float value = smoothstep(
        threshold - smoothness,
        threshold + smoothness,
        data.a
    );

    return vec4(value) * color;
}

#elif MODE == MODE_OUTLINE

uniform float sensitivy = 0.05;

vec4 effect(vec4 color, Image image, vec2 texture_coordinates, vec2 frag_position) {
    vec2 pixel_size = vec2(1 / 750.0);

    float tl = texture(image, texture_coordinates + vec2(-1, -1) * pixel_size).a;
    float tm = texture(image, texture_coordinates + vec2( 0, -1) * pixel_size).a;
    float tr = texture(image, texture_coordinates + vec2( 1, -1) * pixel_size).a;
    float ml = texture(image, texture_coordinates + vec2(-1,  0) * pixel_size).a;
    float mr = texture(image, texture_coordinates + vec2( 1,  0) * pixel_size).a;
    float bl = texture(image, texture_coordinates + vec2(-1,  1) * pixel_size).a;
    float bm = texture(image, texture_coordinates + vec2( 0,  1) * pixel_size).a;
    float br = texture(image, texture_coordinates + vec2( 1,  1) * pixel_size).a;

    float gradient_x = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
    float gradient_y = -tl - 2.0 * tm - tr + bl + 2.0 * bm + br;

    float magnitude = length(vec2(gradient_x, gradient_y));
    float alpha = smoothstep(0.1, 1, magnitude);

    return vec4(alpha) * color;
}

#endif


