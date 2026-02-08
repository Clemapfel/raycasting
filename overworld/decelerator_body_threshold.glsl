#ifdef PIXEL

uniform float threshold = 0.5;
uniform float smoothness = 0.0;

float finalize(float x) {
    return smoothstep(
        max(0, threshold - smoothness),
        min(1, threshold + smoothness),
        x
    );
}

uniform float outline_width = 1.f / 4;

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

    vec2 texel_size = vec2(outline_width) / textureSize(img, 0);

    float s00 = texture(img, position + texel_size * vec2(-1.0, -1.0)).r;
    float s01 = texture(img, position + texel_size * vec2( 0.0, -1.0)).r;
    float s02 = texture(img, position + texel_size * vec2( 1.0, -1.0)).r;
    float s10 = texture(img, position + texel_size * vec2(-1.0,  0.0)).r;
    float s11 = texture(img, position + texel_size * vec2( 0.0,  0.0)).r;
    float s12 = texture(img, position + texel_size * vec2( 1.0,  0.0)).r;
    float s20 = texture(img, position + texel_size * vec2(-1.0,  1.0)).r;
    float s21 = texture(img, position + texel_size * vec2( 0.0,  1.0)).r;
    float s22 = texture(img, position + texel_size * vec2( 1.0,  1.0)).r;

    s01 = finalize(s01);
    s02 = finalize(s02);
    s10 = finalize(s10);
    s11 = finalize(s11);
    s12 = finalize(s12);
    s20 = finalize(s20);
    s21 = finalize(s21);
    s22 = finalize(s22);

    float dx = sobel_x[0][0] * s00 + sobel_x[0][1] * s01 + sobel_x[0][2] * s02 +
    sobel_x[1][0] * s10 + sobel_x[1][1] * s11 + sobel_x[1][2] * s12 +
    sobel_x[2][0] * s20 + sobel_x[2][1] * s21 + sobel_x[2][2] * s22;

    float dy = sobel_y[0][0] * s00 + sobel_y[0][1] * s01 + sobel_y[0][2] * s02 +
    sobel_y[1][0] * s10 + sobel_y[1][1] * s11 + sobel_y[1][2] * s12 +
    sobel_y[2][0] * s20 + sobel_y[2][1] * s21 + sobel_y[2][2] * s22;

    return vec2(dx, dy);
}

uniform vec4 outline_color = vec4(1, 1, 1, 1);
uniform vec4 body_color = vec4(0, 0, 0.5, 1);

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 screen_coords)
{
    // threshold
    float body = finalize(texture(tex, texture_coordinates).r);

    float outline = smoothstep(0, 0.5, min(1, length(derivative(tex, texture_coordinates))));

    return min(vec4(1), vec4(body_color * body + outline_color * outline));
}

#endif