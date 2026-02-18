#ifdef PIXEL

#define NOISE_TYPE_GRADIENT 0u
#define NOISE_TYPE_WORLEY   1u

#define PI 3.141592653589793

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash22(vec2 p) {
    vec2 s = sin(vec2(
    dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3))
    )) * 43758.5453123;
    return fract(s);
}

vec3 hash32(vec2 p) {
    vec3 s = sin(vec3(
    dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3)),
    dot(p, vec2(419.2, 371.9))
    )) * 43758.5453123;
    return fract(s);
}

// 4D hash -> 4 random components in [0,1)
vec4 hash44(vec4 p) {
    vec4 q = vec4(
    dot(p, vec4(127.1, 311.7,  74.7, 419.2)),
    dot(p, vec4(269.5, 183.3, 246.1, 113.5)),
    dot(p, vec4(113.5, 271.9, 124.6, 279.1)),
    dot(p, vec4(419.2,  37.9, 122.3, 311.7))
    );
    return fract(sin(q) * 43758.5453123);
}

// Safe positive modulo for lattice wrapping
vec2 wrapLattice(vec2 lattice, float period) {
    vec2 lp = mod(lattice, period);
    lp += step(lp, vec2(0.0)) * period;
    return mod(lp, period);
}

// -------------------- Periodic Gradient (Perlin-style) Noise --------------------
float gradient_noise(vec2 p, float period) {
    vec2 pi = floor(p);
    vec2 pf = p - pi;

    vec2 wrap_pi   = wrapLattice(pi, period);
    vec2 wrap_pi10 = wrapLattice(pi + vec2(1.0, 0.0), period);
    vec2 wrap_pi01 = wrapLattice(pi + vec2(0.0, 1.0), period);
    vec2 wrap_pi11 = wrapLattice(pi + vec2(1.0, 1.0), period);

    float a00 = 2.0 * PI * hash12(wrap_pi);
    float a10 = 2.0 * PI * hash12(wrap_pi10);
    float a01 = 2.0 * PI * hash12(wrap_pi01);
    float a11 = 2.0 * PI * hash12(wrap_pi11);

    float n00 = dot(vec2(cos(a00), sin(a00)), pf);
    float n10 = dot(vec2(cos(a10), sin(a10)), pf - vec2(1.0, 0.0));
    float n01 = dot(vec2(cos(a01), sin(a01)), pf - vec2(0.0, 1.0));
    float n11 = dot(vec2(cos(a11), sin(a11)), pf - vec2(1.0, 1.0));

    vec2 u = pf * pf * pf * (pf * (pf * 6.0 - 15.0) + 10.0);
    float n = mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
    return clamp(0.5 + 0.5 * n, 0.0, 1.0);
}

// -------------------- Periodic Worley (Cellular) Noise --------------------
float worley_noise(vec2 p, float period) {
    vec2 pi = floor(p);
    float minD2 = 1e9;

    // Search neighborhood; 3x3 is enough for F1
    for (int oy = -1; oy <= 1; ++oy) {
        for (int ox = -1; ox <= 1; ++ox) {
            vec2 cell = pi + vec2(float(ox), float(oy));
            vec2 cp = wrapLattice(cell, period);
            vec2 fp = hash22(cp);
            vec2 q = cell + fp;

            // Toroidal delta for perfect tiling
            vec2 d = q - p - period * round((q - p) / period);
            minD2 = min(minD2, dot(d, d));
        }
    }

    float d = sqrt(minD2);
    float f = clamp(d / PI, 0.0, 1.0); // normalize by sqrt(2)
    return 1.0 - f; // bright at cell centers
}

// -------------------- Noise Router --------------------
float noise(uint type, vec2 texture_coords, float period) {
    if (type == NOISE_TYPE_GRADIENT)
        return gradient_noise(texture_coords, period);
    else if (type == NOISE_TYPE_WORLEY)
        return worley_noise(texture_coords, period);
    else
        return 0.0;
}


uniform uint n_scales = 4u;
uniform vec4 scales;
uniform uvec4 types;

vec4 effect(vec4 _01, sampler2D _02, vec2 texture_coords, vec2 _03) {
    vec4 period4 = max(vec4(1.0), floor(max(scales, vec4(0.0)) + 0.5));
    vec4 result = vec4(1);

    if (n_scales > 0u)
        result.r = noise(types.x, texture_coords * period4.x, period4.x);

    if (n_scales > 1u)
        result.g = noise(types.y, texture_coords * period4.y, period4.y);

    if (n_scales > 2u)
        result.b = noise(types.z, texture_coords * period4.z, period4.z);

    if (n_scales > 3u)
        result.a = noise(types.w, texture_coords * period4.w, period4.w);

    return result;
}

#endif