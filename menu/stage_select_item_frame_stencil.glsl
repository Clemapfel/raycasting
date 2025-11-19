#ifdef PIXEL

uniform float stencil_opacity_cutoff = 0.1;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 texel = texture(img, texture_coordinates);
    if (texel.a < stencil_opacity_cutoff) discard;
    return vec4(1);
}

#endif