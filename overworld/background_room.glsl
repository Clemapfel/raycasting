#ifdef PIXEL

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

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

float merge(float x, float y) {
    return x - y;
}

float box_sdf(vec2 position, vec2 halfSize, float cornerRadius) {
    // src: https://www.shadertoy.com/view/Nlc3zf
    position = abs(position) - halfSize + cornerRadius;
    return length(max(position, 0.0)) + min(max(position.x, position.y), 0.0) - cornerRadius;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}


uniform vec2 player_position;
uniform float flow;

vec4 effect(vec4 vertex_color, Image img, vec2 texture_position, vec2 frag_position) {
    vec2 uv = to_uv(frag_position);

    float weight = distance(
        texture_position * vec2(love_ScreenSize.x / love_ScreenSize.y, 1),
        (player_position / love_ScreenSize.xy) * vec2(love_ScreenSize.x / love_ScreenSize.y, 1)
    );

    float player_weight = gaussian(weight, 2) * flow;

    float aspect_ratio = love_ScreenSize.x / love_ScreenSize.y;
    vec2 pixel_size = 1 / love_ScreenSize.xy;

    float tile_size = 32.0;
    float scale = love_ScreenSize.x / tile_size;
    uv = uv * scale;
    uv = fract(uv);

    float tile_noise_frequency = 1. / 60 * tile_size;

    float tile_noise_b = (worley_noise(vec3(
    floor(to_uv(frag_position.xy) * love_ScreenSize.x / tile_size).xy * tile_noise_frequency,
    elapsed) / 10
    ));

    float tile_noise_a = (gradient_noise(vec3(
    floor(to_uv(frag_position.xy) * love_ScreenSize.x / tile_size).xy * tile_noise_frequency,
    elapsed) / 10
    ) + 1) / 2;

    float tile_noise = mix(tile_noise_a, tile_noise_b, smoothstep(0.4, 1, tile_noise_b));

    float eps = 0.125;
    float line_width = mix(0, eps, tile_noise);
    float box = 1 - smoothstep(0, eps, box_sdf(
    uv - vec2(0.5),
    vec2(0.5, 0.5) - line_width, // - player_weight * 0.4,
    tile_noise * 0.05 // + player_weight
    ));

    vec2 noise_uv = texture_position * 10;
    const int n_octaves = 1;
    float noise_value = 0.0;
    float amplitude = 2.0;
    float frequency = 1.0;
    float persistence = 0.5;

    for (int i = 0; i < n_octaves; ++i) {
        noise_value += amplitude * gradient_noise(vec3(noise_uv * frequency , i * amplitude * elapsed / 4));
        frequency *= 2;
        amplitude *= persistence;
    }

    float intensity = 1; // - mix(0.2, 1, gaussian(weight, 2.5) * flow);
    vec3 rainbow = lch_to_rgb(vec3(0.8, 1, noise_value));
    return vec4(0, 0, 0, 1);
    return vec4(vec3(mix(vec3(noise_value), vec3(0.1), rainbow)), 1);
}

#endif