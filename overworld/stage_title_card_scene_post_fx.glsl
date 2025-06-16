vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

float blur(sampler2D img, vec2 pos) {
    vec2 texel_size = vec2(1.0) / textureSize(img, 0);
    return (
        texture(img, pos + texel_size * vec2(-1.0, -1.0)).a +
        texture(img, pos + texel_size * vec2( 0.0, -1.0)).a +
        texture(img, pos + texel_size * vec2( 1.0, -1.0)).a +
        texture(img, pos + texel_size * vec2(-1.0,  0.0)).a +
        texture(img, pos).a +
        texture(img, pos + texel_size * vec2( 1.0,  0.0)).a +
        texture(img, pos + texel_size * vec2(-1.0,  1.0)).a +
        texture(img, pos + texel_size * vec2( 0.0,  1.0)).a +
        texture(img, pos + texel_size * vec2( 1.0,  1.0)).a
    ) / 9.0;
}

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

    float s00 = blur(img, position + texel_size * vec2(-1.0, -1.0));
    float s01 = blur(img, position + texel_size * vec2( 0.0, -1.0));
    float s02 = blur(img, position + texel_size * vec2( 1.0, -1.0));
    float s10 = blur(img, position + texel_size * vec2(-1.0,  0.0));
    float s11 = blur(img, position + texel_size * vec2( 0.0,  0.0));
    float s12 = blur(img, position + texel_size * vec2( 1.0,  0.0));
    float s20 = blur(img, position + texel_size * vec2(-1.0,  1.0));
    float s21 = blur(img, position + texel_size * vec2( 0.0,  1.0));
    float s22 = blur(img, position + texel_size * vec2( 1.0,  1.0));

    float dx = sobel_x[0][0] * s00 + sobel_x[0][1] * s01 + sobel_x[0][2] * s02 +
    sobel_x[1][0] * s10 + sobel_x[1][1] * s11 + sobel_x[1][2] * s12 +
    sobel_x[2][0] * s20 + sobel_x[2][1] * s21 + sobel_x[2][2] * s22;

    float dy = sobel_y[0][0] * s00 + sobel_y[0][1] * s01 + sobel_y[0][2] * s02 +
    sobel_y[1][0] * s10 + sobel_y[1][1] * s11 + sobel_y[1][2] * s12 +
    sobel_y[2][0] * s20 + sobel_y[2][1] * s21 + sobel_y[2][2] * s22;

    return vec2(dx, dy);
}

float circular_dilation(sampler2D img, vec2 position, float radius) {
    vec2 texel_size = vec2(1.0) / textureSize(img, 0);
    float max_value = 0.0;

    for (float y = -radius; y <= radius; y++) {
        for (float x = -radius; x <= radius; x++) {
            vec2 offset = vec2(x, y) * texel_size;
            if (length(offset) <= radius * texel_size.x) { // Check if within circle
                max_value = max(max_value, texture(img, position + offset).a);
            }
        }
    }

    return max_value;
}

#ifdef PIXEL

uniform float elapsed;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    const float scale = 40;
    vec2 offset = vec2(
        gradient_noise(vec3(+texture_coordinates * scale, elapsed)),
        gradient_noise(vec3(-texture_coordinates * scale, elapsed))
    );

    vec2 dxdy = derivative(img, texture_coordinates + offset * 0.004);
    float width_offset = (gradient_noise(vec3((texture_coordinates) * 50 - elapsed, 0)) + 1) / 2;
    float edge = smoothstep(0, width_offset * 4, length(dxdy));

    return vec4(edge);
}

#endif