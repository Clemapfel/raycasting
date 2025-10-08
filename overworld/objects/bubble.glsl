#ifdef PIXEL
#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform float pop_fraction; // current spread radius [0..1]
uniform vec2 player_position; // in radial coordinates relative to center
uniform vec4 player_color;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords; // 0, 0 in center -1, 1 u, -1, 1 v

    const vec2 center = vec2(0);

    vec4 body_color, static_highlight_color, player_highlight_color;

    // shadow
    float shadow_offset = -1. / 3.5;
    float body = max(0.05, 1 - gaussian(distance(uv, vec2(shadow_offset)), 0.6));
    body_color = body * color;
    body_color.a = 0.1;

    // static highlight
    {
        float dist = distance(pow(distance(uv, center), 1.5) * uv, vec2(-1. / 3.2, -1. / 2.7));
        float highlight = gaussian(dist, 1.2) * gaussian(distance(uv, center), 0.2);
        static_highlight_color = vec4(vec3(1), distance(uv, center)) * highlight;
        static_highlight_color = mix(static_highlight_color, highlight * color, 0.4);
    }

    // player reflectance
    {
        vec2 player_dir = normalize(player_position);
        float player_dist = length(player_position);
        float intensity = clamp(8.0 / (player_dist * player_dist), 0.0, 2.0);
        vec2 highlight_pos = player_dir * 0.4;
        float dist = distance(pow(distance(uv, center), 1.5) * uv, highlight_pos);
        float highlight = gaussian(1 - dist, 1.3) * gaussian(1 - distance(uv, center), 0.25);
        player_highlight_color = player_color * highlight * min(intensity, 1);
    }

    float alpha = pop_fraction;

    return (body_color + static_highlight_color + player_highlight_color) * vec4(vec3(1), alpha);
}

#endif