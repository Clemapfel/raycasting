#ifdef PIXEL

uniform float opacity = 1;

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    const float threshold = 0.0;
    const float eps = 0.05;
    vec2 texSize = textureSize(img, 0);
    vec2 pixel = 1.0 / texSize;

    float a00 = texture(img, texture_coordinates + pixel * vec2(-1.0, -1.0)).a;
    float a01 = texture(img, texture_coordinates + pixel * vec2( 0.0, -1.0)).a;
    float a02 = texture(img, texture_coordinates + pixel * vec2( 1.0, -1.0)).a;
    float a10 = texture(img, texture_coordinates + pixel * vec2(-1.0,  0.0)).a;
    float a11 = texture(img, texture_coordinates).a;
    float a12 = texture(img, texture_coordinates + pixel * vec2( 1.0,  0.0)).a;
    float a20 = texture(img, texture_coordinates + pixel * vec2(-1.0,  1.0)).a;
    float a21 = texture(img, texture_coordinates + pixel * vec2( 0.0,  1.0)).a;
    float a22 = texture(img, texture_coordinates + pixel * vec2( 1.0,  1.0)).a;

    float v00 = smoothstep(threshold - eps, threshold + eps, a00);
    float v01 = smoothstep(threshold - eps, threshold + eps, a01);
    float v02 = smoothstep(threshold - eps, threshold + eps, a02);
    float v10 = smoothstep(threshold - eps, threshold + eps, a10);
    float value = smoothstep(threshold - eps, threshold + eps, a11);
    float v12 = smoothstep(threshold - eps, threshold + eps, a12);
    float v20 = smoothstep(threshold - eps, threshold + eps, a20);
    float v21 = smoothstep(threshold - eps, threshold + eps, a21);
    float v22 = smoothstep(threshold - eps, threshold + eps, a22);

    float gradient_x = -v00 - 2.0 * v10 - v20 + v02 + 2.0 * v12 + v22;
    float gradient_y = -v00 - 2.0 * v01 - v02 + v20 + 2.0 * v21 + v22;

    float gradient = length(vec2(gradient_x, gradient_y));

    vec4 data = texture(img, texture_coordinates);
    vec3 color = value * data.rgb / max(data.a, 10e-5);

    return opacity * vec4(color, value);
}

#endif