#ifdef PIXEL

#define NOISE_TYPE_GRADIENT 0u
#define NOISE_TYPE_WORLEY   1u
#define NOISE_TYPE_SIMPLEX  2u
#define PI 3.141592653589793

// -------------------- Hash Utilities --------------------
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
    float f = clamp(d / 1.41421356237, 0.0, 1.0); // normalize by sqrt(2)
    return 1.0 - f; // bright at cell centers
}

// -------------------- Periodic Simplex Noise (via 4D torus mapping) --------------------
// We implement 4D simplex noise (non-periodic in 4D), and drive it with a 2D->4D torus
// mapping using sin/cos so the resulting 2D field is perfectly periodic on both axes.

vec4 grad4_from_hash(vec4 ip) {
    // Random 4D vector in [-1,1], normalized to unit length
    vec4 r = hash44(ip) * 2.0 - 1.0;
    // Avoid zero-length; add tiny bias
    r += 1e-4;
    return normalize(r);
}

// 4D simplex noise adapted for GLSL, gradients via hash above.
// Returns value in approximately [-1,1].
float simplex4(vec4 v) {
    // Skewing/Unskewing factors for 4D
    const float F4 = 0.30901699437494745; // (sqrt(5)-1)/4
    const float G4 = 0.1381966011250105;  // (5 - sqrt(5))/20

    // Skew the input space to determine which simplex cell we're in
    float s = (v.x + v.y + v.z + v.w) * F4;
    vec4 i = floor(v + s);
    float t = (i.x + i.y + i.z + i.w) * G4;
    vec4 x0 = v - i + t; // The unskewed distance from cell origin

    // Rank order the components to find offsets for other corners
    // Based on Stefan Gustavson's algorithm
    vec4 rank = vec4(0.0);
    rank += step(x0.yzwx, x0.xyyy);
    rank += step(x0.zwxx, x0.yxxy);
    rank += step(x0.wxyz, x0.zzxx);
    // rank now contains how many components are greater than each

    vec4 i1 = step(vec4(2.5), rank);                       // rank >= 3 -> 1
    vec4 i2 = step(vec4(1.5), rank) * (1.0 - i1);          // rank == 2 -> 1
    vec4 i3 = step(vec4(0.5), rank) * (1.0 - i1 - i2);     // rank == 1 -> 1
    // Offsets for remaining corners
    vec4 x1 = x0 - i1 + vec4(G4);
    vec4 x2 = x0 - i2 + vec4(2.0 * G4);
    vec4 x3 = x0 - i3 + vec4(3.0 * G4);
    vec4 x4 = x0 - 1.0 + vec4(4.0 * G4);

    // Compute hashed gradients for the five corners
    vec4 ip0 = i;
    vec4 ip1 = i + i1;
    vec4 ip2 = i + i2;
    vec4 ip3 = i + i3;
    vec4 ip4 = i + 1.0;

    // Contribution from each corner
    float n0 = 0.0, n1 = 0.0, n2 = 0.0, n3 = 0.0, n4 = 0.0;

    float t0 = 0.5 - dot(x0, x0);
    if (t0 > 0.0) {
        vec4 g0 = grad4_from_hash(ip0);
        t0 *= t0;
        n0 = t0 * t0 * dot(g0, x0);
    }

    float t1 = 0.5 - dot(x1, x1);
    if (t1 > 0.0) {
        vec4 g1 = grad4_from_hash(ip1);
        t1 *= t1;
        n1 = t1 * t1 * dot(g1, x1);
    }

    float t2 = 0.5 - dot(x2, x2);
    if (t2 > 0.0) {
        vec4 g2 = grad4_from_hash(ip2);
        t2 *= t2;
        n2 = t2 * t2 * dot(g2, x2);
    }

    float t3 = 0.5 - dot(x3, x3);
    if (t3 > 0.0) {
        vec4 g3 = grad4_from_hash(ip3);
        t3 *= t3;
        n3 = t3 * t3 * dot(g3, x3);
    }

    float t4 = 0.5 - dot(x4, x4);
    if (t4 > 0.0) {
        vec4 g4 = grad4_from_hash(ip4);
        t4 *= t4;
        n4 = t4 * t4 * dot(g4, x4);
    }

    // Scale factor to bring approximate range to [-1,1]
    float value = 27.0 * (n0 + n1 + n2 + n3 + n4);
    return clamp(value, -1.0, 1.0);
}

// 2D periodic simplex via 4D torus embedding.
// 'p' is in "tiles" space; 'period' is the integer tile count along each axis.
float simplex_noise(vec2 p, float period) {
    // Map to a 4D torus using sin/cos so adding 'period' to p.x or p.y leaves the input invariant.
    vec2 ang = (2.0 * PI / period) * p;
    vec4 q = vec4(cos(ang.x), sin(ang.x), cos(ang.y), sin(ang.y));
    float n = simplex4(q);
    return clamp(0.5 + 0.5 * n, 0.0, 1.0);
}

// -------------------- Noise Router --------------------
float noise(uint type, vec2 texture_coords, float period) {
    if (type == NOISE_TYPE_GRADIENT)
    return gradient_noise(texture_coords, period);
    else if (type == NOISE_TYPE_WORLEY)
    return worley_noise(texture_coords, period);
    else if (type == NOISE_TYPE_SIMPLEX)
    return simplex_noise(texture_coords, period);
    else
    return 0.0;
}

// -------------------- Uniforms --------------------
// up to four types / scales stored as vec4s
uniform uint n_scales = 4u;
uniform vec4 scales;
uniform uvec4 types;

vec4 effect(vec4 _01, sampler2D _02, vec2 texture_coords, vec2 _03) {
    vec4 period4 = max(vec4(1.0), floor(max(scales, vec4(0.0)) + 0.5));
    vec4 result = vec4(1);

    if (n_scales > 0u)
        result.r = noise(types.x, texture_coords * period4.r, period4.r);

    if (n_scales > 1u)
        result.g = noise(types.y, texture_coords * period4.g, period4.g);

    if (n_scales > 2u)
        result.b = noise(types.z, texture_coords * period4.b, period4.b);

    if (n_scales > 3u)
        result.a = noise(types.w, texture_coords * period4.a, period4.a);

    return result;
}

#endif