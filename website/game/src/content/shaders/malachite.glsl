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

    float result = mix( mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );

    return (result + 1.0) * 0.5;
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

vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

uniform vec2 rt_ScreenSize;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

uniform float elapsed;

const vec4 black = vec4(0.043137, 0.043137, 0.062745, 1.0);

#define USE_WORLEY_NOISE 0 // 0 or 1

void main() {
    vec2 uv = rt_TextureCoords;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;
    uv *= 0.8;
    float time = elapsed / 13.0;

    #if USE_WORLEY_NOISE == 1
    const float noise_scale = 8.0;
    float noise_x = worley_noise(vec3(noise_scale * uv.xy, time / 3.0));
    #else
    const float noise_scale = 10.0;
    float noise_x = gradient_noise(vec3(noise_scale * uv.xy, time / 3.0));
    #endif

    uv.xy += vec2(noise_x, -noise_x);

    const float cell_size = 0.3;
    vec2 cell_id = floor(uv / cell_size);
    float hue = fract(sin(dot(cell_id, normalize(vec2(127.1, 311.7))) + time / 80000.0) * 43758.5453123);

    vec2 q = mod(uv, cell_size);
    vec2 d = min(q, cell_size - q);
    float gradient = 1.0 - min(d.x, d.y) / (cell_size * 0.5);

    const float threshold = 0.88;
    float eps = fwidth(gradient);
    float value = smoothstep(threshold - eps, threshold + eps, gradient);

    vec3 color = lch_to_rgb(vec3(0.8, 1.0, hue));

    vec3 bloom = 0.2 * color * vec3(smoothstep(0.79, 1.0, gradient));
    color.r = max(color.r * value, max(black.r, bloom.r));
    color.g = max(color.g * value, max(black.g, bloom.g));
    color.b = max(color.b * value, max(black.b, bloom.b));

    rt_FragColor = vec4(color, 1.0);
}