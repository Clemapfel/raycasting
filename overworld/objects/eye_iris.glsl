#ifdef PIXEL

uniform sampler3D noise_texture;
float gradient_noise(vec3 xyz) {
    return texture(noise_texture, xyz).r;
}

uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

uniform float elapsed;

vec4 effect(vec4 vertex_color, sampler2D image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;

    const float noise_scale = 1.5;
    uv.x *= noise_scale;
    float value = uv.y + mix(-1, 1, gradient_noise(vec3(uv.xx, elapsed / 10)));
    value = 1 - clamp(value, 0, 1);

    return vertex_color * vec4(vec3(value), 1);
}

#endif