#ifdef PIXEL

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = texture(tex, texture_coords) * color;
    texel += fwidth(texel.a) * 100;
    return texel;
}

#endif