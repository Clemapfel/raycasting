uniform bool love_StencilActive = false;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords)
{
    // the default love shader does not make textures affect the stencil buffer

    vec4 data = color * texture(img, texture_coords);
    if (love_StencilActive && data.a == 0) discard; // 8-bit zero maps to float zero  losslessly
    return data;
}