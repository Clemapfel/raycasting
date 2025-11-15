#ifdef PIXEL

vec2 derivative(sampler2D img, vec2 position) {
    const mat3 sobel_x = mat3(
        -1.0,  0.0,  1.0,
        -2.0,  0.0,  2.0,
        -1.0,  0.0,  1.0
    );

    const mat3 sobel_y = mat3(
        -1.0, -2.0, -1.0,
        0.0,  0.0,  0.0,
        1.0,  2.0,  1.0
    );

    vec2 texel_size = vec2(1.0) / textureSize(img, 0);

    float s00 = texture(img, position + texel_size * vec2(-1.0, -1.0)).a;
    float s01 = texture(img, position + texel_size * vec2( 0.0, -1.0)).a;
    float s02 = texture(img, position + texel_size * vec2( 1.0, -1.0)).a;
    float s10 = texture(img, position + texel_size * vec2(-1.0,  0.0)).a;
    float s11 = texture(img, position + texel_size * vec2( 0.0,  0.0)).a;
    float s12 = texture(img, position + texel_size * vec2( 1.0,  0.0)).a;
    float s20 = texture(img, position + texel_size * vec2(-1.0,  1.0)).a;
    float s21 = texture(img, position + texel_size * vec2( 0.0,  1.0)).a;
    float s22 = texture(img, position + texel_size * vec2( 1.0,  1.0)).a;

    float dx = sobel_x[0][0] * s00 + sobel_x[0][1] * s01 + sobel_x[0][2] * s02 +
    sobel_x[1][0] * s10 + sobel_x[1][1] * s11 + sobel_x[1][2] * s12 +
    sobel_x[2][0] * s20 + sobel_x[2][1] * s21 + sobel_x[2][2] * s22;

    float dy = sobel_y[0][0] * s00 + sobel_y[0][1] * s01 + sobel_y[0][2] * s02 +
    sobel_y[1][0] * s10 + sobel_y[1][1] * s11 + sobel_y[1][2] * s12 +
    sobel_y[2][0] * s20 + sobel_y[2][1] * s21 + sobel_y[2][2] * s22;

    return vec2(dx, dy);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform vec4 black;
uniform bool draw_core;
uniform float brightness_offset;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec2 dxdy = derivative(img, texture_coordinates);

    float threshold = 0.5;
    float eps = 0.01;
    float outline = smoothstep(threshold - eps, threshold + eps, length(dxdy));

    float center = smoothstep(0, 1 - 0.1, gaussian(distance(texture_coordinates, vec2(0.5)), mix(4.5, 4, brightness_offset))) * 1.3;
    color *= mix(1, 1.2, brightness_offset);
    return float(draw_core) * center * color + outline * vec4(black.rgb, color.a);
}

#endif