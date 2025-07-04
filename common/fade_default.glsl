#ifdef PIXEL

uniform float value; // 1 fully opaque, 0 fully transparent
uniform vec4 color;

vec4 effect(vec4 _, Image image, vec2 texture_coords, vec2 vertex_position) {
    return vec4(color.rgb, color.a * value);
}

#endif