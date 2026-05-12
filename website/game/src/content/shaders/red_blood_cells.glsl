#version 300 es
precision highp float;

uniform float elapsed;
const vec4 color_a = 0.3 * vec4(1, 0.11372549019608, 0.46666666666667, 1);
const vec4 color_b = 0.9 * vec4(1, 0.11372549019608, 0.46666666666667, 1);

vec3 random_3d(vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6))
    )) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);
    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix(
    mix(
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,0,0)), v - vec3(0,0,0)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,0,0)), v - vec3(1,0,0)), u.x),
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,1,0)), v - vec3(0,1,0)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,1,0)), v - vec3(1,1,0)), u.x), u.y),
    mix(
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,0,1)), v - vec3(0,0,1)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,0,1)), v - vec3(1,0,1)), u.x),
    mix(dot(-1.0 + 2.0 * random_3d(i + vec3(0,1,1)), v - vec3(0,1,1)),
    dot(-1.0 + 2.0 * random_3d(i + vec3(1,1,1)), v - vec3(1,1,1)), u.x), u.y),
    u.z);
}

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    return 5.81894409826698685315796808094 * min(a, b);
}

float cell_hash(vec3 c) {
    return fract(sin(dot(c, vec3(41.37, 27.17, 73.21))) * 43758.5453);
}

float sparse_worley_noise(vec3 p, float density) {
    vec3 n = floor(p);
    vec3 f = fract(p);
    float dist = 1.0;
    bool found = false;

    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 cell = n + vec3(float(i), float(j), float(k));

                if (cell_hash(cell) > density) continue;

                found = true;

                vec3 p2 = fract(cell * vec3(0.1031, 0.1030, 0.0973));
                p2 += dot(p2, p2.yxz + 19.19);
                vec3 o = fract((p2.xxy + p2.yzz) * p2.zyx);

                vec3 g = vec3(float(i), float(j), float(k));
                dist = min(dist, length(g + o - f));
            }
        }
    }

    if (!found) return 0.0;
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

const vec4 black = vec4(0.043137, 0.043137, 0.062745, 1.0);

uniform vec2 rt_ScreenSize;
in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

void main() {
    vec2 uv = rt_VertexPosition / rt_ScreenSize;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    vec2 screen_coords = uv * rt_ScreenSize;
    vec2 world_position = uv * 20.0;

    float time = elapsed / 2.0;

    float body = 1.0;
    float noise = dirac(smoothstep(0.0, 1.0 - 0.3, sparse_worley_noise(vec3(world_position, time / 5.0), 0.25)));
    float background_noise = gradient_noise(vec3(world_position / 12.0, time / 4.0));

    vec3 surface_texture = noise * lch_to_rgb(vec3(0.8, 1., background_noise + mix(0.2, 0.3, noise))) * (1. - clamp(background_noise, 0., 1.));

    rt_FragColor = black + vec4(surface_texture, 1.);
}