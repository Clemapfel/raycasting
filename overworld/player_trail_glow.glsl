#ifdef PIXEL

const float sigma = 0.35;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 centered = (texture_coords - vec2(0.5)) * 2.0;
    float dist = length(centered);
    float alpha = exp(- (dist * dist) / (2.0 * sigma * sigma));
    return vec4(color.rgb, color.a * alpha);
}

#endif