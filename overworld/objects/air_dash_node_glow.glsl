#ifdef PIXEL

uniform sampler3D noise_texture;
float noise(vec3 xyz) {
    return texture(noise_texture, xyz).r;
}

uniform float elapsed;
uniform vec4 color;

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec4 texel = texture(img, texture_coords);

    float density = vertex_color.x;
    float arc_length = vertex_color.y;
    float opacity = vertex_color.z;

    const float noise_scale = 3.5;
    float offset = 0.5 * (1 + noise(vec3(texture_coords, elapsed / noise_scale)));
    density -= offset - 0.15;

    return color * vec4(vec3(1), color.a * opacity * density);
}

#endif