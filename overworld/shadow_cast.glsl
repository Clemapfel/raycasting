uniform vec2 player_position; // screen coords
uniform float player_radius; // screen px

uniform sampler2D mask;

float gaussian(float x, float steepness) {
    return exp(-steepness * x * x);
}

vec4 effect(vec4 color, sampler2D _1, vec2 _2, vec2 frag_position) {
    float aspect = love_ScreenSize.x / love_ScreenSize.y;

    vec2 uv = frag_position / love_ScreenSize.xy;
    uv.x *= aspect;

    vec2 pxy = player_position / love_ScreenSize.xy;
    pxy.x *= aspect;

    float d = distance(pxy, uv);

    // normalize player_radius into the same uv-space units as `d`
    float r = player_radius / love_ScreenSize.y;

    float dist = clamp(1.0 - d, 0.0, 1.0);

    // subtract a gaussian centered on the player; steepness controls
    // how sharply the hole falls off with distance
    float hole = gaussian(d / r, 1.0 / 8.0);
    dist = clamp(dist - hole, 0.0, 1.0);

    return texture(mask, frag_position / love_ScreenSize.xy).rrrr * vec4(color.rgb * dist, color.a);
}