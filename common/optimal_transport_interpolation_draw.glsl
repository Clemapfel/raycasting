#ifdef PIXEL

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
{
    float dist = Texel(tex, tc).r;
    float eps = 1 * length(vec2(dFdx(dist), dFdy(dist)));
    float threshold = 0.5;
    float opacity = smoothstep(threshold - eps, threshold + eps, dist);
    return vec4(color.rgb, color.a * opacity);
}
#endif