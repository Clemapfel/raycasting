uniform float elapsed;
uniform vec2 camera_offset;
uniform float camera_scale = 1;

uniform vec2 coin_position;
uniform vec4 coin_color;
//uniform int n_coins;

uniform vec2 player_position;

vec4 effect(vec4 vertex_color, Image image, vec2 _, vec2 frag_position) {

    vec2 origin = 0.5 * love_ScreenSize.xy;

    vec2 uv = frag_position;
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;

    vec4 value = vec4(1, 0, 1, 0.1);
    float eps = 0.005;
    float radius = 0.05;

    vec2 coin_positions[1];
    vec4 coin_colors[1];

    coin_positions[0] = coin_position;
    coin_colors[0] = coin_color;

    int n_coins = 1;

    for (int i = 0; i < n_coins; ++i) {
        vec4 color = coin_colors[i];

        vec2 position = coin_positions[i];
        vec2 delta = position - uv;
        delta.x *= love_ScreenSize.x / love_ScreenSize.y;
        delta /= love_ScreenSize.xy;

        value += (1 - smoothstep(radius - eps, radius + eps, length(delta))) * coin_color;
    }

    return value;
}