#ifdef PIXEL

vec4 effect(vec4 vertex_color, Image tex, vec2 texture_coords, vec2 screen_coords) // tex is RG8
{
    vec4 data = texture(tex, texture_coords);
    float mask = data.a;
    if (mask == 0) discard;

    vec2 gradient = normalize((data.yz * 2) - 1); // normalized gradient
    float dist = data.x; // normalized distance;

    return vertex_color * mix(vec4(0), vec4(1), dist);
}

#endif