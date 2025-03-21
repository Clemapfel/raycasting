#define PI 3.1415926535897932384626433832795

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

#ifdef PIXEL

uniform float elapsed;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = vertex_position / love_ScreenSize.xy;
    float aspect_ratio = love_ScreenSize.x / love_ScreenSize.y;
    uv.x = uv.x * aspect_ratio + 0.5 * aspect_ratio;
    float time = elapsed / 16.0;

    uv += vec2(time / 2.0);
    uv *= 1.5;

    const float n_steps = 12.0;
    float lacunarity = 0.5;
    float step_multiplier = 1.1;

    vec2 start = uv;
    for (int i = 1; i < int(n_steps); i++) {
        float step_time = time * (1.0 + float(i) / n_steps * (n_steps / 30.0));
        uv.x += lacunarity / float(i) * cos(float(i) * uv.y * 2.0 * step_multiplier + 2.0 * step_time) + 0.5 * float(i);
        uv.y += lacunarity / float(i) * sin(float(i) * uv.x * 2.0 * step_multiplier - 2.0 * step_time) - 0.5 * float(i);
        uv = rotate(uv, float(i) / n_steps * 2.0 * PI);
    }

    float x_bias = (cos(uv.x * 3.0) + 1.0) / 2.0;
    float y_bias = (sin((uv.y + 0.5) * 3.0) + 1.0) / 2.0;
    float value = length(vec2(x_bias, y_bias)) - 1.0;
    return vec4(mix(vec3(0), vec3(1), value), 1.0);
}

#endif