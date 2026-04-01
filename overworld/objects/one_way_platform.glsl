#ifdef PIXEL

uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

uniform float hue;
uniform float player_hue;
uniform vec2 player_position;

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {

    float self_dist = length(texture_coords);
    self_dist = gaussian(self_dist, 0.6);
    return color * self_dist;

    vec2 screen_uv = screen_coords / love_ScreenSize.xy;
    vec2 player_uv = player_position / love_ScreenSize.xy;

    float aspect_correction = love_ScreenSize.x / love_ScreenSize.y;
    screen_uv.x *= aspect_correction;
    player_uv.x *= aspect_correction;

    float player_dist = min(11.5 * distance(player_uv, screen_uv), 1);

    vec3 self_color = lch_to_rgb(vec3(0.8, 1, hue));
    vec3 player_color = lch_to_rgb(vec3(0.8, 1, player_hue));
    return color * vec4(mix(player_color, self_color, player_dist), self_dist);
}

#endif