#ifdef PIXEL

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 data = texture(tex, texture_coords);
    data.rgb = vec3(1);
    return data;
}

#endif