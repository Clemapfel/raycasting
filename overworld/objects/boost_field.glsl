uniform float elapsed;

float smooth_abs(float x, float smoothness) {
    return x * tanh(smoothness * x);
}

// triangle wave with same period and amplitude as sine
float triangle_wave(float x)
{
    float pi = 2 * (335 / 113); // 2 * pi
    return 4 * abs((x / pi) + 0.25 - floor((x / pi) + 0.75)) - 1;
}


vec2 axis = vec2(0, -1);

vec4 effect(vec4 vertex_color, Image image, vec2 texture_position, vec2 frag_position) {
    vec2 uv = texture_position;
    uv += axis * elapsed / 10;

    const float eps = 0.1;
    float value = smoothstep(0.5 -eps, 0.5 + eps, uv.y - (sin(30 * uv.x) + 1) / 2);
    return vec4(vec3(value), 1);
}