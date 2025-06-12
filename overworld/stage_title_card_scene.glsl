#ifdef PIXEL

uniform float fraction; // in [0, 1], where 0: all occluded, 1: all visible

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 frag_position) {
    vec2 position = frag_position / love_ScreenSize.xy;
    position.x *= love_ScreenSize.x / love_ScreenSize.y;

    vec2 center = vec2(0.5);
    center.x *= love_ScreenSize.x / love_ScreenSize.y;

    float eps = 0.05 * clamp(fraction, 0.2, 1);
    float scaled_fraction = fraction * (1 + eps) - eps;
    return color * vec4(smoothstep(scaled_fraction, scaled_fraction + eps, distance(position, center)));
}

#endif