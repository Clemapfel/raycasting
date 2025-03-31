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

    return 1 - dist;
}

#define PI 3.1415926535897932384626433832795

float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#ifdef PIXEL

uniform vec4 color_a;
uniform vec4 color_b;

uniform float elapsed;

uniform vec2 camera_offset;
uniform float camera_scale = 1;
vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

float wnoise(vec2 uv) {
    const float eps = 0.35;
    float res = worley_noise(vec3(vec2(uv.xy) * 7, elapsed));
    return smoothstep(0 - eps, 0 + eps, gaussian(1 - res, 1.3));
}

vec4 effect(vec4 vertex_color, Image image, vec2 _, vec2 frag_position) {

    vec2 uv = to_uv(frag_position);
    uv *= 1.5;
    float time = elapsed;
    vec2 pixel_size = 1 / love_ScreenSize.xy;
    float wn = wnoise(uv);

mat3 sobel_x = mat3(
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
);

mat3 sobel_y = mat3(
    -1, -2, -1,
    0, 0, 0,
    1, 2, 1
);

float gradient_x = 0.0;
float gradient_y = 0.0;

for (int i = -1; i <= 1; i++) {
    for (int j = -1; j <= 1; j++) {
        vec2 neighbor_uv = uv + vec2(i, j) * pixel_size / camera_scale;
        float neighbor_wn = wnoise(neighbor_uv);
        gradient_x += neighbor_wn * sobel_x[i + 1][j + 1];
        gradient_y += neighbor_wn * sobel_y[i + 1][j + 1];
    }
}

float sobel_magnitude = length(vec2(gradient_x, gradient_y));
wn = 1.2 * gradient_noise(vec3(vec2(uv.xy + sobel_magnitude * camera_scale) * 10, elapsed));
return vec4(mix(color_b.rgb, color_a.rgb, wn), 1);
}
#endif