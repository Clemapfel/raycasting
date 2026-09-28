#ifndef TEXTURE_FORMAT
#error "TEXTURE_FORMAT undefined"
#endif

#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X not defined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y not defined"
#endif

precision highp float;

precision highp float;

// ---- Derived constants (nothing magic-number-rounded) ----

// D65 white point from its chromaticity (x=0.3127, y=0.3290), Y=1
const vec3 WHITE_D65 = vec3(0.3127 / 0.3290,
1.0,
(1.0 - 0.3127 - 0.3290) / 0.3290);

// CIE Lab exact constants
const float LAB_DELTA   = 6.0 / 29.0;                       // 0.2068965...
const float LAB_DELTA_2 = 3.0 * LAB_DELTA * LAB_DELTA;      // 3*(6/29)^2 = 1/7.787...

// XYZ (D65) -> linear sRGB, computed from the sRGB primaries + D65 white
// (inverse of the exact RGB->XYZ matrix, so white maps exactly to 1,1,1).
// GLSL is column-major, so each vec3 below is a column.
const mat3 XYZ_TO_LINEAR_SRGB = mat3(
vec3( 3.2409699419045226, -0.9692436362808796,  0.0556300796969936),
vec3(-1.5373831775700939,  1.8759675015077202, -0.2039769588889765),
vec3(-0.4986107602930034,  0.0415550574071756,  1.0569715142428784)
);

// sRGB transfer function, using the exactly-continuous threshold
const float SRGB_LIN_THRESHOLD = 0.04045 / 12.92;           // 0.0031308049...

float lab_f_inv(float t) {
    return (t > LAB_DELTA) ? t * t * t
    : LAB_DELTA_2 * (t - 4.0 / 29.0);
}

float srgb_encode(float c) {
    c = max(c, 0.0);
    return (c > SRGB_LIN_THRESHOLD)
    ? 1.055 * pow(c, 1.0 / 2.4) - 0.055
    : 12.92 * c;
}

// LCH(ab) in natural units (L 0..100, C 0..~150, H radians) -> linear sRGB (unclamped)
vec3 lch_to_linear_srgb(float L, float C, float h) {
    float fy = (L + 16.0) / 116.0;
    float fx = fy + (C * cos(h)) / 500.0;
    float fz = fy - (C * sin(h)) / 200.0;

    vec3 xyz = WHITE_D65 * vec3(lab_f_inv(fx), lab_f_inv(fy), lab_f_inv(fz));
    return XYZ_TO_LINEAR_SRGB * xyz;
}

bool in_gamut(vec3 rgb) {
    const float EPS = 1e-5;
    return all(greaterThanEqual(rgb, vec3(-EPS))) &&
    all(lessThanEqual(rgb, vec3(1.0 + EPS)));
}

vec4 lcha_to_rgba(vec4 lcha) {
    float L = lcha.x * 100.0;
    float C = max(lcha.y * 100.0, 0.0);
    float h = radians(lcha.z * 360.0);
    float alpha = clamp(lcha.a, 0.0, 1.0);

    // Trivial endpoints
    if (L <= 0.0)   return vec4(0.0, 0.0, 0.0, alpha);
    if (L >= 100.0) return vec4(1.0, 1.0, 1.0, alpha);

    vec3 lin = lch_to_linear_srgb(L, C, h);

    // Gamut mapping: reduce chroma at constant L and H instead of per-channel clipping
    if (!in_gamut(lin)) {
        float lo = 0.0, hi = C;
        for (int i = 0; i < 24; i++) {
            float mid = 0.5 * (lo + hi);
            if (in_gamut(lch_to_linear_srgb(L, mid, h))) lo = mid; else hi = mid;
        }
        lin = lch_to_linear_srgb(L, lo, h);
    }

    vec3 rgb = vec3(srgb_encode(lin.r), srgb_encode(lin.g), srgb_encode(lin.b));
    return vec4(clamp(rgb, 0.0, 1.0), alpha);
}

// src: https://github.com/KhronosGroup/ToneMapping/blob/main/PBR_Neutral/README.md#pbr-neutral-specification

const float fresnel_90 = 0.025;
const float compression_start = 1.0 - fresnel_90;
const float desaturation_speed = 0.15;

float relu(float x, float eps) {
    // smoothed version of max(x, 0)
    return 0.5 * (x + sqrt(x * x + eps));
}

vec3 tonemap(vec3 rgb) {
    float m = relu(
        min(rgb.r, min(rgb.g, rgb.b)),
        2.0 * fresnel_90 // 2.0 is empirically tuned, not mathematically motivated
    );

    vec3 offset = rgb - mix(
    fresnel_90,
    m - (m * m) / (4.0 * fresnel_90),
    step(m, 2.0 * fresnel_90)
    );

    float peak = max(offset.r, max(offset.g, offset.b));

    if (peak > compression_start) {
        float d = 1.0 - compression_start;
        float peak_new = 1.0 - (d * d) / ((peak - compression_start) + d);

        return mix(
        vec3(peak_new),
        offset * (peak_new / peak),
        1.0 / (1.0 + desaturation_speed * (peak - peak_new))
        );
    }

    return offset;
}

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

    float res = mix( mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
    mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );

    return res * 2.0 - 1.0;
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

const float ray_n_steps = 13;
const float ray_step = 0.031;

const int fbm_steps = 1;
const float fbm_lacunarity = 1;  // frequency multiplier per octave
const float fbm_gain = 1;  // amplitude multiplier per octave

float fbm(vec3 p) {
    float sum = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < fbm_steps; i++) {
        float noise = gradient_noise(p * frequency);
        sum += amplitude * noise;
        max_value += amplitude;

        frequency *= fbm_lacunarity;
        amplitude *= fbm_gain;
    }

    return sum / max_value;
}


float noise_field(vec3 p, out vec3 grad) {
    const float h = 1e-3;

    grad.x = (fbm(p + vec3(h, 0.0, 0.0)) - fbm(p - vec3(h, 0.0, 0.0))) / (2.0 * h);
    grad.y = (fbm(p + vec3(0.0, h, 0.0)) - fbm(p - vec3(0.0, h, 0.0))) / (2.0 * h);
    grad.z = (fbm(p + vec3(0.0, 0.0, h)) - fbm(p - vec3(0.0, 0.0, h))) / (2.0 * h);

    return fbm(p);
}

float fbm_worley(vec3 p) {
    float sum = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < fbm_steps; i++) {
        float noise = worley_noise(p * frequency);
        sum += amplitude * noise;
        max_value += amplitude;

        frequency *= fbm_lacunarity;
        amplitude *= fbm_gain;
    }

    return sum / max_value;
}


float noise_field_worley(vec3 p, out vec3 grad) {
    const float h = 1e-3;

    grad.x = (fbm_worley(p + vec3(h, 0.0, 0.0)) - fbm_worley(p - vec3(h, 0.0, 0.0))) / (2.0 * h);
    grad.y = (fbm_worley(p + vec3(0.0, h, 0.0)) - fbm_worley(p - vec3(0.0, h, 0.0))) / (2.0 * h);
    grad.z = (fbm_worley(p + vec3(0.0, 0.0, h)) - fbm_worley(p - vec3(0.0, 0.0, h))) / (2.0 * h);

    return fbm(p);
}

float angle(vec2 xy) {
    return atan(xy.y, xy.x);
}

uniform float elapsed;

layout(TEXTURE_FORMAT) uniform writeonly image2D texture;

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = 1) in;
void computemain() {
    vec2 size = vec2(imageSize(texture).xy);
    ivec2 pixel_position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(pixel_position, size))) return;

    vec2 position = vec2(pixel_position) / vec2(size);

    vec3 scale = vec3(10, 10, 1);
    vec3 scale_gain = vec3(1, 1, 1);
    float transmittance = 1.0;
    float sum = 0;
    vec3 lacunarity = vec3(1);
    vec3 lacunarity_gain = vec3(1, 1, 1) * 1.05;
    vec3 amp = vec3(1);
    vec3 amp_gain = vec3(1, 1, 1) * 1.1;

    vec3 lch = vec3(1);

    vec3 ray_origin = vec3((position.xy - 0.5), elapsed);
    vec3 ray_position = ray_origin;
    vec3 ray_direction = vec3(0, 0, 1);

    for (int i = 0; i < ray_n_steps; ++i) {
        vec3 gradient = vec3(0);
        float noise = noise_field(ray_position * scale, gradient);

        float alpha = 1.0 - exp(-noise * ray_step);
        sum += transmittance * alpha * noise;

        transmittance *= 1.0 - alpha;
        if (transmittance < 0.1) break; // early out

        ray_direction += gradient;
        ray_position += normalize(ray_direction) * ray_step * lacunarity * amp;

        lch.xyz += gradient.xyz;

        lacunarity *= lacunarity_gain;
        amp *= amp_gain;
        scale *= scale_gain;
    }

    float opacity = sum;

    vec4 color = vec4(smoothstep(0.2, 0.8, opacity));

    imageStore(texture, pixel_position, color);
}