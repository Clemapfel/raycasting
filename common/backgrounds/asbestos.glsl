#define PI 3.1415926535897932384626433832795

vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

#ifdef PIXEL

uniform float elapsed;
uniform vec4 color_a;
uniform vec4 color_b;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = vertex_position / love_ScreenSize.xy;
    float aspect_ratio = love_ScreenSize.x / love_ScreenSize.y;
    uv.x = uv.x * aspect_ratio + 0.5 * aspect_ratio;
    float time = elapsed / 16.0;

    uv += vec2(time / 2.0);
    uv *= 10;

    const float n_steps = 10.0;
    float lacunarity = 0.5;
    float step_multiplier = 1.1;

    vec2 start = uv;
    vec2 prev_uv = uv; // Track the previous UV position
    for (int i = 1; i < int(n_steps); i++) {
        float step_time = time * (1.0 + float(i) / n_steps * (n_steps / 30.0));
        vec2 delta_uv;
        delta_uv.x = lacunarity / float(i) * cos(float(i) * prev_uv.y * 2.0 * step_multiplier + 2.0 * step_time) + 0.5 * float(i);
        delta_uv.y = lacunarity / float(i) * sin(float(i) * prev_uv.x * 2.0 * step_multiplier - 2.0 * step_time) - 0.5 * float(i);

        float angle = atan(delta_uv.y, delta_uv.x);
        float max_angle = (n_steps - float(i)) / PI / 1;
        angle = clamp(angle, -max_angle, max_angle);
        delta_uv = length(delta_uv) * vec2(cos(angle), sin(angle));

        uv += delta_uv;
        prev_uv = uv; // Update the previous UV position
    }

    float x_bias = (cos(uv.x * 3.0) + 1.0) / 2.0;
    float y_bias = (sin((uv.y + 0.5) * 3.0) + 1.0) / 2.0;
    float value = length(vec2(x_bias, y_bias)) - 1.0;
    return vec4(mix(color_b.rgb, color_a.rgb, value), 1.0);
}

#endif