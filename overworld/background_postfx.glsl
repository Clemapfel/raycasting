float derivative_v(vec4 data) {
    return max(max(data.x, data.y), max(data.y, data.z));
}

vec2 derivative(sampler2D img, vec2 position) {
    vec2 texel_size = vec2(1.0) / textureSize(img, 0);

    float s00 = derivative_v(texture(img, position + texel_size * vec2(-1.0, -1.0)));
    float s01 = derivative_v(texture(img, position + texel_size * vec2( 0.0, -1.0)));
    float s02 = derivative_v(texture(img, position + texel_size * vec2( 1.0, -1.0)));
    float s10 = derivative_v(texture(img, position + texel_size * vec2(-1.0,  0.0)));
    float s12 = derivative_v(texture(img, position + texel_size * vec2( 1.0,  0.0)));
    float s20 = derivative_v(texture(img, position + texel_size * vec2(-1.0,  1.0)));
    float s21 = derivative_v(texture(img, position + texel_size * vec2( 0.0,  1.0)));
    float s22 = derivative_v(texture(img, position + texel_size * vec2( 1.0,  1.0)));

    float dx =
        (-1.0 * s00) + ( 1.0 * s02) +
        (-2.0 * s10) + ( 2.0 * s12) +
        (-1.0 * s20) + ( 1.0 * s22);

    float dy =
        (-1.0 * s00) + (-2.0 * s01) + (-1.0 * s02) +
        ( 1.0 * s20) + ( 2.0 * s21) + ( 1.0 * s22);

    return vec2(dx, dy);
}

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_position, vec2 frag_position) {
    //return texture(img, texture_position);

    return vec4(length(derivative(img, texture_position)));
}