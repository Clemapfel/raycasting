uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

uniform float elapsed;
uniform float hue;
uniform float saturation;

vec4 effect(vec4 color, sampler2D image, vec2 texture_coordinates, vec2 _) {
    vec4 texel = texture(image, texture_coordinates);
    return color * vec4(lch_to_rgb(vec3(
        0.8,
        mix(0.7, 1.0, (sin(elapsed * 5.0) + 1.0) / 2.0),
        hue
    )), texel.a * color.a);
}
