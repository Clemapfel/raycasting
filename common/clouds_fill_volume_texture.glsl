#ifndef VOLUME_TEXTURE_FORMAT
#define VOLUME_TEXTURE_FORMAT r32f
#endif

#ifndef WORK_GROUP_SIZE_X
#define WORK_GROUP_SIZE_X 8
#endif

#ifndef WORK_GROUP_SIZE_Y
#define WORK_GROUP_SIZE_Y 8
#endif

#ifndef WORK_GROUP_SIZE_Z
#define WORK_GROUP_SIZE_Z 4
#endif

layout(VOLUME_TEXTURE_FORMAT) uniform writeonly image3D volume_texture;

uniform vec3 offset;
uniform ivec3 volume_size;

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;

// Permutation table for deterministic noise
const int perm[256] = int[256](
151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
);

// Hash function for deterministic noise
int hash(int x, int y, int z) {
    return perm[(perm[(perm[x & 255] + y) & 255] + z) & 255];
}

// 3D gradient vectors
vec3 grad3d(int hash) {
    int h = hash & 15;
    float u = h < 8 ? 1.0 : -1.0;
    float v = (h < 4) ? 1.0 : ((h == 12 || h == 14) ? 1.0 : -1.0);
    float w = (h < 2) ? 1.0 : ((h == 12 || h == 13) ? 1.0 : -1.0);
    return vec3(u, v, w);
}

// Smooth interpolation function (quintic)
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 3D Perlin noise
float perlin3d(vec3 p) {
    // Grid cell coordinates
    ivec3 p0 = ivec3(floor(p));
    vec3 pf = fract(p);

    // Fade curves
    vec3 u = vec3(fade(pf.x), fade(pf.y), fade(pf.z));

    // Hash coordinates of 8 cube corners
    int aaa = hash(p0.x, p0.y, p0.z);
    int aba = hash(p0.x, p0.y + 1, p0.z);
    int aab = hash(p0.x, p0.y, p0.z + 1);
    int abb = hash(p0.x, p0.y + 1, p0.z + 1);
    int baa = hash(p0.x + 1, p0.y, p0.z);
    int bba = hash(p0.x + 1, p0.y + 1, p0.z);
    int bab = hash(p0.x + 1, p0.y, p0.z + 1);
    int bbb = hash(p0.x + 1, p0.y + 1, p0.z + 1);

    // Gradient vectors at cube corners
    vec3 g000 = grad3d(aaa);
    vec3 g001 = grad3d(aab);
    vec3 g010 = grad3d(aba);
    vec3 g011 = grad3d(abb);
    vec3 g100 = grad3d(baa);
    vec3 g101 = grad3d(bab);
    vec3 g110 = grad3d(bba);
    vec3 g111 = grad3d(bbb);

    // Distances from cube corners
    float n000 = dot(g000, pf - vec3(0, 0, 0));
    float n001 = dot(g001, pf - vec3(0, 0, 1));
    float n010 = dot(g010, pf - vec3(0, 1, 0));
    float n011 = dot(g011, pf - vec3(0, 1, 1));
    float n100 = dot(g100, pf - vec3(1, 0, 0));
    float n101 = dot(g101, pf - vec3(1, 0, 1));
    float n110 = dot(g110, pf - vec3(1, 1, 0));
    float n111 = dot(g111, pf - vec3(1, 1, 1));

    // Trilinear interpolation
    float nx00 = mix(n000, n100, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx11 = mix(n011, n111, u.x);

    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);

    return mix(nxy0, nxy1, u.z);
}

// Fractal Brownian Motion (FBM) - multiple octaves of noise
float fbm(vec3 p, int octaves, float lacunarity, float gain) {
    float sum = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (int i = 0; i < octaves; i++) {
        sum += amplitude * perlin3d(p * frequency);
        maxValue += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return sum / maxValue;
}

void computemain() {
    ivec3 gid = ivec3(gl_GlobalInvocationID.xyz);

    // Check bounds
    if (any(greaterThanEqual(gid, volume_size))) {
        return;
    }

    imageStore(volume_texture, gid, vec4(1, 1, 1, 1));

    /*

    // Normalize coordinates to [0, 1]
    vec3 uv = (vec3(gid) + 0.5) / vec3(volume_size);

    // Apply offset for animation/variation
    vec3 pos = uv + offset;

    // Generate multi-octave fractal noise
    // Base noise at different frequencies for cloud-like appearance
    float baseFreq = 4.0;
    float noise1 = fbm(pos * baseFreq, 4, 2.0, 0.5);

    // Detail noise at higher frequency
    float detailFreq = 16.0;
    float noise2 = fbm(pos * detailFreq, 3, 2.0, 0.5);

    // Combine noises with different weights
    float finalNoise = noise1 * 0.75 + noise2 * 0.25;

    // Remap from [-1, 1] to [0, 1]
    finalNoise = finalNoise * 0.5 + 0.5;

    // Optional: add vertical gradient for cloud layers
    float heightGradient = smoothstep(0.0, 0.3, uv.y) * (1.0 - smoothstep(0.7, 1.0, uv.y));
    finalNoise *= mix(0.5, 1.0, heightGradient);

    // Write to volume texture
    imageStore(volume_texture, gid, finalNoise);

    */
}