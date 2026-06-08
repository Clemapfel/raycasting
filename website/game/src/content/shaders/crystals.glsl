#version 300 es
precision highp float;

uniform vec2 rt_ScreenSize;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

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

float crystal_noise(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);
    float F1 = 8.0; // Closest point distance
    float F2 = 8.0; // Second closest point distance

    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(float(i), float(j), float(k));
                vec3 o = random_3d(n + g);
                vec3 r = g + o - f;
                float d = length(r);

                if (d < F1) {
                    F2 = F1;
                    F1 = d;
                } else if (d < F2) {
                    F2 = d;
                }
            }
        }
    }

    return F2 - F1;
}

vec3 crystal_noise_gradient(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float F1 = 8.0, F2 = 8.0;
    vec3  R1 = vec3(0.0), R2 = vec3(0.0); // offset vectors to F1/F2 sites

    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(float(i), float(j), float(k));
                vec3 r = g + random_3d(n + g) - f;
                float d = length(r);

                if (d < F1) {
                    F2 = F1; R2 = R1;   // demote old winner
                    F1 = d;  R1 = r;
                } else if (d < F2) {
                    F2 = d;  R2 = r;
                }
            }
        }
    }

    // ∂F_i/∂p = (r_i / F_i) · (∂r/∂p) = -r_i / F_i
    // ∇(F2 − F1) = ∇F2 − ∇F1 = r1/F1 − r2/F2
    return R1 / F1 - R2 / F2;
}

vec3 lch_to_rgb(float l, float c, float h) {
    float L = l * 100.0;
    float C = c * 100.0;
    float H = h * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X * 3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y * 1.8758 + Z * 0.0415;
    float B = X * 0.0557 + Y * -0.2040 + Z * 1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

const vec3 light_intensity = vec3(1.0, 1.0, 1.0);
uniform float elapsed;

#define PI 3.1415926535897932384626433832795

const vec4 black = vec4(0.043137, 0.043137, 0.062745, 1.0);

void main() {
    vec2 uv = rt_VertexPosition / rt_ScreenSize;
    uv.x *= rt_ScreenSize.x / rt_ScreenSize.y;

    float time = 0.5 * elapsed;

    const float scale = 1.4;
    vec2 offset = 20.0 / rt_ScreenSize;
    vec3 p = vec3(uv * 20.0 * scale, time / 10.0);
    p.xy /= 2.0;

    float noise = crystal_noise(p);
    vec3 gradient = normalize(crystal_noise_gradient(p));
    vec3 normal = normalize(vec3(-1.0, -1.0, 0.2)) * gradient;

    float gnoise = (gradient_noise(p * vec3(2.0, 2.0, 3.0)) + 1.0) * 0.5;

    float swirl_frequency = 1.4;
    float angle = (2.0 * noise - 1.0) * 2.0 * PI * swirl_frequency;
    vec3 light_direction = normalize(vec3(cos(angle), sin(angle), fract(noise)));

    float lambertian = pow(max(dot(normal, light_direction) * noise, 0.0), 0.9);

    vec3 shadow_direction = vec3(cos(gnoise), sin(-gnoise), 0.2);
    float shadow = 0.25 * dot(normal, normalize(shadow_direction));

    const float contrast = 0.3; // decrease for more shadow fog
    float value = min(1.0, lambertian + 0.5 * noise);
    rt_FragColor = smoothstep(0.0, 1.0 - contrast, noise) * vec4(mix(
        lch_to_rgb(0.8, 1.0, noise * mix(gradient.x, gradient.y, (sin(time + gnoise) + 1.0) / 2.0)) * vec3(smoothstep(0.0, 0.6, value)),
        vec3(shadow),
        length(gradient.xy) * gnoise
    ), 1.0) + vec4(black);
}