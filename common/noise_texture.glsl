// 3D Periodic Noise Compute Shader
// - Implements seamless 3D gradient (Perlin-style) and Worley (cellular) noise
// - Mirrors technique used in the provided 2D fragment shader but extended to 3D
// - Each channel (RGBA) can select an independent noise type and integer period
// - Output is in [0,1], suitable for UNORM or float textures
//
// Dispatch recommendation:
//   - Desktop: WORK_GROUP_SIZE_X = WORK_GROUP_SIZE_Y = WORK_GROUP_SIZE_Z = 8
//   - Mobile/low-end: 4 x 4 x 4
//
// Notes on periodicity:
//   We construct noise on a lattice with unit cell spacing and apply explicit toroidal
//   wrapping using a supplied integer period. Coordinates are scaled so that the full texture
//   domain spans exactly 'period' units in noise space, ensuring exact tiling on all edges.

#define NOISE_TYPE_GRADIENT 0u
#define NOISE_TYPE_WORLEY   1u

#ifndef TEXTURE_FORMAT
#error "TEXTURE_FORMAT undefined"
#endif

#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X undefined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y undefined"
#endif

#ifndef WORK_GROUP_SIZE_Z
#error "WORK_GROUP_SIZE_Z undefined"
#endif

// =====================================================================================
// Helpers
// =====================================================================================

float saturate(float x) { return clamp(x, 0.0, 1.0); }

ivec3 imodp(ivec3 a, ivec3 m) {
    // Positive modulo per component, handles negative a
    return ivec3(
    ((a.x % m.x) + m.x) % m.x,
    ((a.y % m.y) + m.y) % m.y,
    ((a.z % m.z) + m.z) % m.z
    );
}

uint hash_u32(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

// Mix 3 ints into a single 32-bit hash, deterministic across vendors
uint hash_ivec3(ivec3 p) {
    uvec3 u = uvec3(p) ^ uvec3(0x9E3779B9u, 0x7F4A7C15u, 0xF39CC060u);
    uint h = u.x;
    h = hash_u32(h ^ u.y);
    h = hash_u32(h ^ u.z);
    return h;
}

// Hash for a lattice point with wrapping by period
uint hash_lattice(ivec3 lattice, ivec3 period) {
    ivec3 w = imodp(lattice, period);
    return hash_ivec3(w);
}

// Derive a float in [0,1) from a uint
float u01(uint h) {
    // 1/2^32
    const float k = 1.0 / 4294967296.0;
    return float(h) * k;
}

// Advance a hash state (simple step)
uint hash_step(uint h) {
    return hash_u32(h ^ 0x85EBCA6Bu);
}

// Smooth fade curve (Perlin)
vec3 fade3(vec3 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Dot product of distance vector with gradient selected by hashed lattice
float dot_grad(ivec3 lattice, vec3 d, ivec3 period) {
    uint h = hash_lattice(lattice, period) & 15u; // 0..15

    // Improved Perlin's 12 gradients via bit tricks
    float u = (h < 8u) ? d.x : d.y;
    float v = (h < 4u) ? d.y : ((h == 12u || h == 14u) ? d.x : d.z);

    float gu = ((h & 1u) != 0u) ? -u : u;
    float gv = ((h & 2u) != 0u) ? -v : v;
    return gu + gv;
}

// =====================================================================================
// Periodic 3D Gradient Noise (Perlin-style)
// =====================================================================================

float gradient_noise3(vec3 P, ivec3 period) {
    // Period must be >= 1 in each component
    period = max(period, ivec3(1));

    ivec3 I = ivec3(floor(P));
    vec3  F = fract(P);
    vec3  f = fade3(F);

    // 8 corners
    float n000 = dot_grad(I + ivec3(0,0,0), F - vec3(0,0,0), period);
    float n100 = dot_grad(I + ivec3(1,0,0), F - vec3(1,0,0), period);
    float n010 = dot_grad(I + ivec3(0,1,0), F - vec3(0,1,0), period);
    float n110 = dot_grad(I + ivec3(1,1,0), F - vec3(1,1,0), period);
    float n001 = dot_grad(I + ivec3(0,0,1), F - vec3(0,0,1), period);
    float n101 = dot_grad(I + ivec3(1,0,1), F - vec3(1,0,1), period);
    float n011 = dot_grad(I + ivec3(0,1,1), F - vec3(0,1,1), period);
    float n111 = dot_grad(I + ivec3(1,1,1), F - vec3(1,1,1), period);

    // Trilinear mix
    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);

    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);

    float nxyz = mix(nxy0, nxy1, f.z);

    // Map from approx [-1,1] to [0,1]
    return saturate(nxyz * 0.5 + 0.5);
}

// =====================================================================================
// Periodic 3D Worley (Cellular) Noise (F1: nearest feature point)
// =====================================================================================

vec3 random3_in_cell(ivec3 cellWrapped, out uint h0) {
    // Generate 3 independent uniform floats in [0,1) using stepped hashes
    uint h = hash_ivec3(cellWrapped);
    h0 = h;
    uint h1 = hash_step(h);
    uint h2 = hash_step(h1);
    uint h3 = hash_step(h2);
    return vec3(u01(h1), u01(h2), u01(h3));
}

float worley_noise3(vec3 P, ivec3 period) {
    period = max(period, ivec3(1));

    ivec3 I = ivec3(floor(P));
    vec3  F = fract(P);

    // Search 27 neighboring cells
    float minDist2 = 1e9;
    for (int dz = -1; dz <= 1; ++dz) {
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                ivec3 cell = I + ivec3(dx, dy, dz);
                ivec3 cellWrapped = imodp(cell, period);

                uint hseed;
                vec3 jitter = random3_in_cell(cellWrapped, hseed); // in [0,1)

                // Absolute position of feature point in noise space (unwrapped cell integer + jitter)
                vec3 feature = vec3(cell) + jitter;

                vec3 d = feature - P;
                float dist2 = dot(d, d);
                minDist2 = min(minDist2, dist2);
            }
        }
    }

    float minDist = sqrt(minDist2);       // 0..~sqrt(3)
    // Normalize to [0,1] by dividing by maximum possible distance within our search window.
    // For unit cells, the farthest nearest point cannot exceed sqrt(3).
    float value = minDist / 1.7320508075688772; // sqrt(3)
    return saturate(value);
}

// =====================================================================================
// Legacy placeholders (kept for compatibility with original skeleton)
// =====================================================================================

float gradient_noise(vec3 xyz) {
    // Default to period=1 in all directions for compatibility
    return gradient_noise3(xyz, ivec3(1));
}

float worley_noise(vec3 xyz) {
    // Default to period=1 in all directions for compatibility
    return worley_noise3(xyz, ivec3(1));
}

// =====================================================================================
// Texture I/O and uniforms
// =====================================================================================

layout(TEXTURE_FORMAT) uniform writeonly image3D noise_texture;

uniform vec4  scales   = vec4(1);
uniform uvec4 types    = uvec4(NOISE_TYPE_GRADIENT);

// Noise multiplexer
float noise3(uint type, vec3 coords, ivec3 period) {
    if (type == NOISE_TYPE_GRADIENT) {
        return gradient_noise3(coords, period);
    } else if (type == NOISE_TYPE_WORLEY) {
        return worley_noise3(coords, period);
    } else {
        return 0.0;
    }
}

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;

// Entry point (as provided in skeleton)
void computemain() {
    ivec3 size = imageSize(noise_texture);
    ivec3 gid  = ivec3(gl_GlobalInvocationID.xyz);

    // Guard in case dispatch exceeds texture bounds
    if (any(greaterThanEqual(gid, size))) {
        return;
    }

    // Map voxel coordinate to noise space: the full texture spans exactly 'period' integer units.
    // To strictly preserve periodicity, we quantize per-channel 'scales' to integer periods >= 1.
    // This ensures the value at the texture boundary wraps without discontinuities for REPEAT sampling.
    float sR = max(1.0, floor(scales.x + 0.5));
    float sG = max(1.0, floor(scales.y + 0.5));
    float sB = max(1.0, floor(scales.z + 0.5));
    float sA = max(1.0, floor(scales.w + 0.5));

    ivec3 periodR = ivec3(int(sR));
    ivec3 periodG = ivec3(int(sG));
    ivec3 periodB = ivec3(int(sB));
    ivec3 periodA = ivec3(int(sA));

    // Normalized local coordinates in [0,1) per voxel center
    vec3 local = (vec3(gid) + vec3(0.5)) / vec3(size);

    // Scale to integer lattice periods
    vec3 PR = local * vec3(periodR);
    vec3 PG = local * vec3(periodG);
    vec3 PB = local * vec3(periodB);
    vec3 PA = local * vec3(periodA);

    // Compute per-channel noise
    float r = noise3(types.x, PR, periodR);
    float g = noise3(types.y, PG, periodG);
    float b = noise3(types.z, PB, periodB);
    float a = noise3(types.w, PA, periodA);

    imageStore(noise_texture, gid, vec4(r, g, b, a));
}