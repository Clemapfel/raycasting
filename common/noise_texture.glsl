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

uint pcg_hash(uint v) {
    v = v * 747796405u + 2891336453u;
    uint r = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u;
    r ^= r >> 22u;
    return r;
}

uint hash3(uvec3 v) {
    uint h = v.x ^ pcg_hash(v.y) ^ pcg_hash(v.z);
    return pcg_hash(h);
}

float u32_to_norm(uint x) {
    return float(x) * (1.0 / 4294967296.0);
}

vec3 random3(uvec3 v) {
    uint h1 = hash3(v);
    uint h2 = pcg_hash(h1);
    uint h3 = pcg_hash(h2);
    return vec3(u32_to_norm(h1), u32_to_norm(h2), u32_to_norm(h3));
}

uint wrap_index(int i, uint period) {
    int p = int(period);
    int m = i % p;
    if (m < 0) m += p;
    return uint(m);
}

const vec3 grad_3d[12] = vec3[](
vec3( 1, 1, 0), vec3(-1, 1, 0), vec3( 1,-1, 0), vec3(-1,-1, 0),
vec3( 1, 0, 1), vec3(-1, 0, 1), vec3( 1, 0,-1), vec3(-1, 0,-1),
vec3( 0, 1, 1), vec3( 0,-1, 1), vec3( 0, 1,-1), vec3( 0,-1,-1)
);

vec3 fade(vec3 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float lerp1(float a, float b, float t) {
    return a + t * (b - a);
}

float gradient_noise_periodic(vec3 uvw, uvec3 period) {
    vec3 p = uvw * vec3(period);
    ivec3 i0 = ivec3(floor(p));
    vec3 f  = fract(p);

    uvec3 i000 = uvec3(wrap_index(i0.x + 0, period.x), wrap_index(i0.y + 0, period.y), wrap_index(i0.z + 0, period.z));
    uvec3 i100 = uvec3(wrap_index(i0.x + 1, period.x), wrap_index(i0.y + 0, period.y), wrap_index(i0.z + 0, period.z));
    uvec3 i010 = uvec3(wrap_index(i0.x + 0, period.x), wrap_index(i0.y + 1, period.y), wrap_index(i0.z + 0, period.z));
    uvec3 i110 = uvec3(wrap_index(i0.x + 1, period.x), wrap_index(i0.y + 1, period.y), wrap_index(i0.z + 0, period.z));
    uvec3 i001 = uvec3(wrap_index(i0.x + 0, period.x), wrap_index(i0.y + 0, period.y), wrap_index(i0.z + 1, period.z));
    uvec3 i101 = uvec3(wrap_index(i0.x + 1, period.x), wrap_index(i0.y + 0, period.y), wrap_index(i0.z + 1, period.z));
    uvec3 i011 = uvec3(wrap_index(i0.x + 0, period.x), wrap_index(i0.y + 1, period.y), wrap_index(i0.z + 1, period.z));
    uvec3 i111 = uvec3(wrap_index(i0.x + 1, period.x), wrap_index(i0.y + 1, period.y), wrap_index(i0.z + 1, period.z));

    vec3 g000 = normalize(grad_3d[hash3(i000) % 12u]);
    vec3 g100 = normalize(grad_3d[hash3(i100) % 12u]);
    vec3 g010 = normalize(grad_3d[hash3(i010) % 12u]);
    vec3 g110 = normalize(grad_3d[hash3(i110) % 12u]);
    vec3 g001 = normalize(grad_3d[hash3(i001) % 12u]);
    vec3 g101 = normalize(grad_3d[hash3(i101) % 12u]);
    vec3 g011 = normalize(grad_3d[hash3(i011) % 12u]);
    vec3 g111 = normalize(grad_3d[hash3(i111) % 12u]);

    vec3 d000 = vec3( f.x,  f.y,  f.z);
    vec3 d100 = vec3( f.x-1.0,  f.y,      f.z);
    vec3 d010 = vec3( f.x,      f.y-1.0,  f.z);
    vec3 d110 = vec3( f.x-1.0,  f.y-1.0,  f.z);
    vec3 d001 = vec3( f.x,      f.y,      f.z-1.0);
    vec3 d101 = vec3( f.x-1.0,  f.y,      f.z-1.0);
    vec3 d011 = vec3( f.x,      f.y-1.0,  f.z-1.0);
    vec3 d111 = vec3( f.x-1.0,  f.y-1.0,  f.z-1.0);

    float n000 = dot(g000, d000);
    float n100 = dot(g100, d100);
    float n010 = dot(g010, d010);
    float n110 = dot(g110, d110);
    float n001 = dot(g001, d001);
    float n101 = dot(g101, d101);
    float n011 = dot(g011, d011);
    float n111 = dot(g111, d111);

    vec3 w = fade(f);

    float nx00 = lerp1(n000, n100, w.x);
    float nx10 = lerp1(n010, n110, w.x);
    float nx01 = lerp1(n001, n101, w.x);
    float nx11 = lerp1(n011, n111, w.x);

    float nxy0 = lerp1(nx00, nx10, w.y);
    float nxy1 = lerp1(nx01, nx11, w.y);

    float nxyz = lerp1(nxy0, nxy1, w.z);

    return 0.5 * (nxyz + 1.0);
}

float worley_noise_periodic(vec3 uvw, uvec3 period) {
    vec3 p = uvw * vec3(period);
    ivec3 base_cell = ivec3(floor(p));
    vec3 f = fract(p);

    float min_d2 = 1e9;

    for (int dz = -1; dz <= 1; ++dz) {
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                ivec3 o = ivec3(dx, dy, dz);
                ivec3 neigh = base_cell + o;

                uvec3 cw = uvec3(
                wrap_index(neigh.x, period.x),
                wrap_index(neigh.y, period.y),
                wrap_index(neigh.z, period.z)
                );

                vec3 rp = random3(cw);
                vec3 d = (vec3(o) + rp) - f;

                float d2 = dot(d, d);
                min_d2 = min(min_d2, d2);
            }
        }
    }

    float d = sqrt(min_d2);
    float val = 1.0 - clamp(d / sqrt(3), 0.0, 1.0);
    return val;
}

float noise_periodic(uint type, vec3 uvw, uvec3 period) {
    if (type == NOISE_TYPE_GRADIENT) {
        return gradient_noise_periodic(uvw, period);
    } else if (type == NOISE_TYPE_WORLEY) {
        return worley_noise_periodic(uvw, period);
    } else {
        return 0.0;
    }
}

layout(TEXTURE_FORMAT) uniform writeonly image3D noise_texture;

uniform vec4 scales = vec4(1.0);
uniform uvec4 types = uvec4(NOISE_TYPE_GRADIENT);
uniform uint n_components = 4u;

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain()
{
    ivec3 size = imageSize(noise_texture);
    uvec3 gid  = gl_GlobalInvocationID.xyz;

    if (gid.x >= uint(size.x) || gid.y >= uint(size.y) || gid.z >= uint(size.z)) {
        return;
    }

    vec3 uvw = (vec3(gid) + vec3(0.5)) / vec3(size);

    uint px = max(1u, uint(round(scales.x)));
    uint py = max(1u, uint(round(scales.y)));
    uint pz = max(1u, uint(round(scales.z)));
    uint pw = max(1u, uint(round(scales.w)));

    vec4 result = vec4(1);

    if (n_components > 0u)
    result.x = noise_periodic(types.x, uvw, uvec3(px));

    if (n_components > 1u)
    result.y = noise_periodic(types.y, uvw, uvec3(py));

    if (n_components > 2u)
    result.z = noise_periodic(types.z, uvw,  uvec3(pz));

    if (n_components > 3u)
    result.w = noise_periodic(types.w, uvw, uvec3(pw));

    imageStore(noise_texture, ivec3(gid), result);
}
