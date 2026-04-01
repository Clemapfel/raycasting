#ifdef PIXEL

uniform sampler3D noise_texture;
float gradient_noise(vec3 p) {
    p /= 24;
    return texture(noise_texture, p).r;
}

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

#define PI 3.1415926535897932384626433832795

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

uniform float elapsed;
uniform float hue;
uniform float hue_offset;

vec4 effect(vec4 color, sampler2D image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_world_position(vertex_position) / 60;
    float noise = gradient_noise(vec3(uv, elapsed / 4));

    float hue_eps = hue_offset;
    float alpha = 1;
    hue_eps = hue_offset * 4;

    float final_hue = mix(hue - hue_offset, hue + hue_offset, noise);
    return color * vec4(lch_to_rgb(vec3(0.8, 1, final_hue)), alpha);
}

#endif // PIXEL