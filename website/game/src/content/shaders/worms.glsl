#version 300 es
precision highp float;

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

    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

float worley_noise(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float dist = 1.0;
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(i, j, k);

                vec3 p = n + g;
                p = fract(p * vec3(0.1031, 0.1030, 0.0973));
                p += dot(p, p.yxz + 19.19);
                vec3 o = fract((p.xxy + p.yzz) * p.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);
                dist = min(dist, d);
            }
        }
    }

    return 1.0 - dist;
}

uniform vec2 rt_ScreenSize;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

uniform float elapsed;
#define PI 3.1415926535897932384626433832795

void main() {
    vec2 uv = rt_TextureCoords;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    float time = elapsed / 20.0;

    const float scale = 2.0;
    const float gradient_noise_scale = 5.0 * scale;
    const float worley_noise_scale = 5.0 * scale;

    float lacunarity = 1.0;
    float time_scale = 1.0;
    for (int i = 0; i < 2; ++i) {
        uv.xy += vec2(
            lacunarity * gradient_noise(vec3(gradient_noise_scale * uv.xy, time)),
            lacunarity * gradient_noise(vec3(-gradient_noise_scale * uv.y, time, gradient_noise_scale * uv.x))
        ) * worley_noise(vec3(worley_noise_scale * uv.xy, time));

        lacunarity = lacunarity / 10.0;
    }

    float value = worley_noise(vec3(worley_noise_scale * uv.xy, time));
    rt_FragColor = vec4(vec3(value), 1);
}