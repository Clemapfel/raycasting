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

const float fresnel_90 = 0.02;
const float compression_start = 1.0 - fresnel_90;
const float desaturation_speed = 0.15;

float smoothmax(float x, float eps) {
    return 0.5 * (x + sqrt(x * x + eps));
}

vec3 tonemap(vec3 rgb) {
    float m = smoothmax(min(rgb.r, min(rgb.g, rgb.b)), 2.0 * fresnel_90);

    vec3 offset = rgb - mix(
    fresnel_90,
    m - (m * m) / (4.0 * fresnel_90),
    step(m, 2.0 * fresnel_90)
    );

    float peak = max(offset.r, max(offset.g, offset.b));

    if (peak > compression_start) {
        float d = 1.0 - compression_start;
        float peak_new = 1.0 - (d * d ) / ((peak - compression_start) + d);

        return mix(
        vec3(peak_new),
        offset * (peak_new / peak),
        1.0 / (1.0 + desaturation_speed * (peak - peak_new))
        );
    }

    return offset;
}

uniform float elapsed;

layout(TEXTURE_FORMAT) uniform writeonly image2D texture;

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = 1) in;
void computemain() {
    vec2 size = vec2(imageSize(texture).xy);
    ivec2 pixel_position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(pixel_position, size))) return;

    vec2 position = vec2(pixel_position) / vec2(size);

    position.y = pow(position.y, 0.9);
    vec4 color = lcha_to_rgba(vec4(0.8 * position.y, 1.0 * position.y, position.x, 1.0));

    imageStore(texture, pixel_position, vec4(position.x >= (sin(elapsed) + 1.0) / 2.0 ? tonemap(color.rgb) : color.rgb, color.a));
}