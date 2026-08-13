
uniform vec2 player_position; // screen coords
uniform sampler2D mask;

float gaussian(float x) {
    return exp(-(x * x));
}

vec4 effect(vec4 color, sampler2D _1, vec2 _2, vec2 frag_position) {
    float aspect = love_ScreenSize.x / love_ScreenSize.y;

    vec2 uv = frag_position / love_ScreenSize.xy;
    uv.x *= aspect;

    vec2 pxy = player_position / love_ScreenSize.xy;
    pxy.x *= aspect;

    float dist = clamp(1.0 - distance(pxy, uv), 0.0, 1.0);
    return texture(mask, frag_position / love_ScreenSize.xy).rrrr * vec4(color.rgb * dist, color.a);
}
