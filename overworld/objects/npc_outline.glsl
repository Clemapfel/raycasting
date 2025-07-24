    #ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform vec2 player_position; // screen_cords
uniform vec4 player_color;

vec4 effect(vec4 color, sampler2D _img, vec2 _uv, vec2 screen_coords)
{
    vec2 player_uv = player_position / love_ScreenSize.xy;
    vec2 screen_uv = screen_coords / love_ScreenSize.xy;

    float attenuation = gaussian(distance(player_uv, screen_uv) * 2, 3);
    return vec4(mix(color.rgb, player_color.rgb, attenuation), color.a * player_color.a);
}

#endif