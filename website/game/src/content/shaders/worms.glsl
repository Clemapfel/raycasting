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
#define PI 3.1415926535897932384626433832795

// ... [Keep your random_3d, gradient_noise, worley_noise, lch_to_rgb functions exactly as they are] ...

// 1. Encapsulate the height generation into a dedicated function
float get_surface_height(vec2 p, float time) {
    vec2 uv = p;
    vec2 uv_raw = p;

    const float scale = 2.0;
    float gradient_noise_scale = 3.0 * scale;
    float worley_noise_scale = 1.5 * scale;

    float lacunarity = 1.0;

    for (int i = 0; i < 1; ++i) {
        vec2 offset = vec2(
            lacunarity * gradient_noise(vec3(gradient_noise_scale * uv.xy, time)),
            lacunarity * gradient_noise(vec3(-gradient_noise_scale * uv.y, time, gradient_noise_scale * uv.x))
        );

        uv.xy += offset;

        lacunarity = lacunarity / 4.0;
        worley_noise_scale *= 1.2;
    }

    float value = distance(uv.xy, uv_raw.xy);
    value *= worley_noise(vec3(worley_noise_scale * uv.xy, value));

    return value;
}

const vec4 black = vec4(0.043137, 0.043137, 0.062745, 1.0);

void main() {
    vec2 uv = rt_TextureCoords;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    float time = elapsed / 20.0;

    // 1. Evaluate the height at the current point (this is your original value)
    float value = get_surface_height(uv, time);

    // 2. Compute the gradient numerically using a small epsilon offset
    vec2 e = vec2(1.0 / rt_ScreenSize.x, 0);
    float hx = get_surface_height(uv + e.xy, time);
    float hy = get_surface_height(uv + e.yx, time);

    // Partial derivatives: (dh/dx, dh/dy)
    vec2 grad = vec2(hx - value, hy - value) / e.x;

    // 3. Construct the mathematically robust 3D normal
    // Increase normal_strength to flatten the appearance, decrease to accentuate bumps.
    float normal_strength = 1.0;
    vec3 normal = normalize(vec3(-grad.x, -grad.y, normal_strength));

    float gnoise = gradient_noise(vec3(4.0 * uv.xy, time));
    float angle = 2.0 * 3.14159 + elapsed * 2.0;
    vec3 light_dir = normalize(vec3(cos(angle), sin(angle), 1.0));
    float lambertian = max(0.0, dot(light_dir, normal));

    float specular = pow(lambertian, 32.0);
    vec3 color_a = lch_to_rgb(vec3(0.8, lambertian, gnoise));
    vec3 color_b = lch_to_rgb(vec3(0.8, 1.0, 1.0 - gnoise));
    vec3 color = mix(color_a, color_b, lambertian);

    vec4 result = vec4(mix(
        vec3(specular * mix(0.2, 1.0, value)),
        color * vec3(smoothstep(0.0, 0.24, value) * mix(0.7, 1.0, lambertian)),
        0.7
    ), 1.0);

    rt_FragColor = vec4(
        max(black.r, result.r),
        max(black.g, result.g),
        max(black.b, result.b),
        result.a
    );
}