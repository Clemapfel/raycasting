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

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

uniform float elapsed;

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 vertex_color, Image img, vec2 texture_position, vec2 frag_position) {
    vec2 uv = texture_position;
    float time = elapsed / 4;

    vec2 size = love_ScreenSize.xy;
    vec2 normalization = size / max(size.x, size.y); // account for aspect ratio
    float dist = distance(
    texture_position * normalization,
        vec2(0.5) * normalization
    );
    float ramp = gaussian(dist, 1);

    uv *= 6;

    float noise = 1;
    vec2 scale = vec2(2, 1);
    for (int i = 1; i < 4; ++i) {
        if (i % 2 == 0) {
            noise = (gradient_noise(vec3(time, texture_position * 6)) + 1) / 2;
            uv.xy += noise * scale.xy;
        }
        else {
            noise = smoothstep(0.7, 1, worley_noise(vec3(time, texture_position * 4 )));
            uv.xy += noise;
        }

        scale.x = scale.x * 3;
    }

    float final = worley_noise(vec3(uv.xy, time));

    return vec4(vec3(final), 1);
}

#endif