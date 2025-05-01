#define MODE_DRAW_OUTLINE 0
#define MODE_DRAW_TEXT 1

#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

#if MODE == MODE_DRAW_OUTLINE
uniform vec4 outline_color;
#endif

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    #if MODE == MODE_DRAW_OUTLINE
        float dist = Texel(image, texture_coords).a;
        float outline = smoothstep(0.0, 0.02, pow(dist, 5));
        return outline * outline_color;
    #elif MODE == MODE_DRAW_TEXT
        return color * Texel(image, texture_coords);
    #endif
}