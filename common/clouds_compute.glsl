#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

#define MODE_FILL 0
#define MODE_RAYMARCH 1

#if MODE == MODE_FILL

const int perm[256] = int[256](
151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
);

int hash(int x, int y, int z, int w) {
    return perm[(perm[(perm[(perm[x & 255] + y) & 255] + z) & 255] + w) & 255];
}

// 4d gradient
vec4 gradient_4d(int hash_val) {
    int h = hash_val & 31;

    float a = (h < 24) ? ((h & 1) == 0 ? 1.0 : -1.0) : 0.0;
    float b = (h < 16) ? ((h & 2) == 0 ? 1.0 : -1.0) : ((h < 24) ? ((h & 1) == 0 ? 1.0 : -1.0) : 0.0);
    float c = (h < 8) ? ((h & 4) == 0 ? 1.0 : -1.0) : ((h < 24) ? ((h & 2) == 0 ? 1.0 : -1.0) : 0.0);
    float d = (h < 24) ? ((h & 8) == 0 ? 1.0 : -1.0) : 0.0;

    return vec4(a, b, c, d);
}

// quintinc interpolation
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 4d perlin noise
float perlin_4d(vec4 p) {
    ivec4 grid_coord = ivec4(floor(p));
    vec4 frac_coord = fract(p);

    vec4 fade_curve = vec4(
    fade(frac_coord.x),
    fade(frac_coord.y),
    fade(frac_coord.z),
    fade(frac_coord.w)
    );

    // hypercube corners
    int h0000 = hash(grid_coord.x,     grid_coord.y,     grid_coord.z,     grid_coord.w);
    int h0001 = hash(grid_coord.x,     grid_coord.y,     grid_coord.z,     grid_coord.w + 1);
    int h0010 = hash(grid_coord.x,     grid_coord.y,     grid_coord.z + 1, grid_coord.w);
    int h0011 = hash(grid_coord.x,     grid_coord.y,     grid_coord.z + 1, grid_coord.w + 1);
    int h0100 = hash(grid_coord.x,     grid_coord.y + 1, grid_coord.z,     grid_coord.w);
    int h0101 = hash(grid_coord.x,     grid_coord.y + 1, grid_coord.z,     grid_coord.w + 1);
    int h0110 = hash(grid_coord.x,     grid_coord.y + 1, grid_coord.z + 1, grid_coord.w);
    int h0111 = hash(grid_coord.x,     grid_coord.y + 1, grid_coord.z + 1, grid_coord.w + 1);
    int h1000 = hash(grid_coord.x + 1, grid_coord.y,     grid_coord.z,     grid_coord.w);
    int h1001 = hash(grid_coord.x + 1, grid_coord.y,     grid_coord.z,     grid_coord.w + 1);
    int h1010 = hash(grid_coord.x + 1, grid_coord.y,     grid_coord.z + 1, grid_coord.w);
    int h1011 = hash(grid_coord.x + 1, grid_coord.y,     grid_coord.z + 1, grid_coord.w + 1);
    int h1100 = hash(grid_coord.x + 1, grid_coord.y + 1, grid_coord.z,     grid_coord.w);
    int h1101 = hash(grid_coord.x + 1, grid_coord.y + 1, grid_coord.z,     grid_coord.w + 1);
    int h1110 = hash(grid_coord.x + 1, grid_coord.y + 1, grid_coord.z + 1, grid_coord.w);
    int h1111 = hash(grid_coord.x + 1, grid_coord.y + 1, grid_coord.z + 1, grid_coord.w + 1);

    // gradients
    vec4 g0000 = gradient_4d(h0000);
    vec4 g0001 = gradient_4d(h0001);
    vec4 g0010 = gradient_4d(h0010);
    vec4 g0011 = gradient_4d(h0011);
    vec4 g0100 = gradient_4d(h0100);
    vec4 g0101 = gradient_4d(h0101);
    vec4 g0110 = gradient_4d(h0110);
    vec4 g0111 = gradient_4d(h0111);
    vec4 g1000 = gradient_4d(h1000);
    vec4 g1001 = gradient_4d(h1001);
    vec4 g1010 = gradient_4d(h1010);
    vec4 g1011 = gradient_4d(h1011);
    vec4 g1100 = gradient_4d(h1100);
    vec4 g1101 = gradient_4d(h1101);
    vec4 g1110 = gradient_4d(h1110);
    vec4 g1111 = gradient_4d(h1111);

    // dot with distances from hypercube corners
    float n0000 = dot(g0000, frac_coord - vec4(0, 0, 0, 0));
    float n0001 = dot(g0001, frac_coord - vec4(0, 0, 0, 1));
    float n0010 = dot(g0010, frac_coord - vec4(0, 0, 1, 0));
    float n0011 = dot(g0011, frac_coord - vec4(0, 0, 1, 1));
    float n0100 = dot(g0100, frac_coord - vec4(0, 1, 0, 0));
    float n0101 = dot(g0101, frac_coord - vec4(0, 1, 0, 1));
    float n0110 = dot(g0110, frac_coord - vec4(0, 1, 1, 0));
    float n0111 = dot(g0111, frac_coord - vec4(0, 1, 1, 1));
    float n1000 = dot(g1000, frac_coord - vec4(1, 0, 0, 0));
    float n1001 = dot(g1001, frac_coord - vec4(1, 0, 0, 1));
    float n1010 = dot(g1010, frac_coord - vec4(1, 0, 1, 0));
    float n1011 = dot(g1011, frac_coord - vec4(1, 0, 1, 1));
    float n1100 = dot(g1100, frac_coord - vec4(1, 1, 0, 0));
    float n1101 = dot(g1101, frac_coord - vec4(1, 1, 0, 1));
    float n1110 = dot(g1110, frac_coord - vec4(1, 1, 1, 0));
    float n1111 = dot(g1111, frac_coord - vec4(1, 1, 1, 1));

    // quadrilinear interpolation along x
    float nx000 = mix(n0000, n1000, fade_curve.x);
    float nx001 = mix(n0001, n1001, fade_curve.x);
    float nx010 = mix(n0010, n1010, fade_curve.x);
    float nx011 = mix(n0011, n1011, fade_curve.x);
    float nx100 = mix(n0100, n1100, fade_curve.x);
    float nx101 = mix(n0101, n1101, fade_curve.x);
    float nx110 = mix(n0110, n1110, fade_curve.x);
    float nx111 = mix(n0111, n1111, fade_curve.x);

    // along y
    float nxy00 = mix(nx000, nx100, fade_curve.y);
    float nxy01 = mix(nx001, nx101, fade_curve.y);
    float nxy10 = mix(nx010, nx110, fade_curve.y);
    float nxy11 = mix(nx011, nx111, fade_curve.y);

    // along z
    float nxyz0 = mix(nxy00, nxy10, fade_curve.z);
    float nxyz1 = mix(nxy01, nxy11, fade_curve.z);

    // along w
    return mix(nxyz0, nxyz1, fade_curve.w);
}

// fbm
float fractal_brownian_motion(vec4 p, int octaves, float lacunarity, float gain) {
    float sum = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < octaves; i++) {
        sum += amplitude * perlin_4d(p * frequency);
        max_value += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return sum / max_value;
}

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

float continuous_step(float x, int n_steps, float smoothness) {
    // https://www.desmos.com/calculator/ggoaqtlh7c
    if (n_steps == 0) n_steps = 3;
    if (smoothness == 0.0) smoothness = 11.5;

    float h = (n_steps > 0) ? (1.0 / float(n_steps)) : 2.0;
    float a = smoothness;

    return h * ((tanh((a * x / h) - a * floor(x / h) - a / 2.0) / (2.0 * tanh(a / 2.0)) + 0.5 + floor(x / h)));
}

#endif // MODE_FILL

#ifndef WORK_GROUP_SIZE_X
#define WORK_GROUP_SIZE_X 8
#endif

#ifndef WORK_GROUP_SIZE_Y
#define WORK_GROUP_SIZE_Y 8
#endif

#ifndef WORK_GROUP_SIZE_Z
#define WORK_GROUP_SIZE_Z 4
#endif

#ifndef VOLUME_TEXTURE_FORMAT
#define VOLUME_TEXTURE_FORMAT r32f
#endif

#if MODE == MODE_FILL

layout(VOLUME_TEXTURE_FORMAT) uniform writeonly image3D volume_texture;
uniform vec3 noise_offset;
uniform float time_offset;

#elif MODE == MODE_RAYMARCH

#ifndef EXPORT_TEXTURE_FORMAT
#define EXPORT_TEXTURE_FORMAT rgba8
#endif

#ifndef MAX_N_EXPORT_TEXTURES
#define MAX_N_EXPORT_TEXTURES 1
#endif

layout(VOLUME_TEXTURE_FORMAT) uniform readonly image3D volume_texture;
layout(EXPORT_TEXTURE_FORMAT) uniform writeonly image2D export_textures[MAX_N_EXPORT_TEXTURES];
uniform int n_export_textures;

uniform int n_density_steps = 128;
uniform float density_step_size = 0.03;

uniform int n_shadow_steps = 32;
uniform float shadow_step_size = 0.06;

uniform vec3 ray_direction;

#endif // MODE_RAYMARCH

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain() {
    ivec3 gid = ivec3(gl_GlobalInvocationID.xyz);
    ivec3 volume_texture_size = imageSize(volume_texture);

    vec3 uv = (vec3(gid) + 0.5) / vec3(volume_texture_size);

    #if MODE == MODE_FILL

    if (any(greaterThanEqual(gid, volume_texture_size)))
    return;

    vec4 pos = vec4(uv + noise_offset, time_offset);

    float frequency = 16;
    float noise = fractal_brownian_motion(
    pos * frequency,
    4,  // octaves
    3,  // lacunarity
    0.4 // gain
    );

    float alt_noise = noise;
    noise = 1 - (noise + 1) / 2;

    imageStore(volume_texture, gid, vec4(noise, 0, 0, 0));

    #elif MODE == MODE_RAYMARCH

    ivec2 export_texture_size = volume_texture_size.xy; // export has same width / height, 1 ray per pixel

    // only process 2D pixels, not the z dimension
    if (gid.z != 0) return;

    // ambient light - soft base illumination for cloud interior
    const float ambient_light = 0.15;
    const vec4 ambient_light_color = vec4(1, 1, 1, 1);

    // directional light - sun/moon
    const vec4 light_color = vec4(1, 1, 1, 1);
    const vec3 light_direction = normalize(vec3(0, 1, 0));

    // Beer-Lambert law coefficients for realistic atmospheric scattering
    const float absorption_intensity = 2.5;  // how much light is absorbed by cloud particles
    const float scattering_intensity = 1.8;  // how much light is scattered toward viewer

    // start ray at the beginning of the volume
    vec3 ray_position = vec3(uv.xy, 0.0);

    // accumulated transmittance (how much light passes through)
    float transmittance = 1.0;

    // accumulated radiance (final color)
    vec4 color = vec4(0.0);

    // calculate slice depth positions
    float slice_depth_step = 1.0 / float(n_export_textures);
    int next_slice_index = 0;
    float next_slice_depth = slice_depth_step * 0.5; // center of first slice

    for (int density_step_i = 0; density_step_i < n_density_steps; ++density_step_i) {
        // convert normalized position to texture coordinates
        vec3 sample_pos = ray_position * vec3(volume_texture_size);
        ivec3 sample_coord = ivec3(sample_pos);

        // bounds check
        if (any(lessThan(sample_coord, ivec3(0))) ||
        any(greaterThanEqual(sample_coord, volume_texture_size))) {
            ray_position += ray_direction * density_step_size;
            continue;
        }

        // sample cloud density at current position
        float sampled_density = imageLoad(volume_texture, sample_coord).r;

        // skip empty space for performance
        if (sampled_density > 0.01) {
            // ===== SHADOW CALCULATION =====
            // march toward light source to calculate occlusion
            float shadow_density = 0.0;
            vec3 shadow_ray_pos = ray_position;

            for (int shadow_step_i = 0; shadow_step_i < n_shadow_steps; ++shadow_step_i) {
                shadow_ray_pos += light_direction * shadow_step_size;
                vec3 shadow_sample_pos = shadow_ray_pos * vec3(volume_texture_size);
                ivec3 shadow_coord = ivec3(shadow_sample_pos);

                // exit if we leave the volume
                if (any(lessThan(shadow_coord, ivec3(0))) ||
                any(greaterThanEqual(shadow_coord, volume_texture_size))) {
                    break;
                }

                float shadow_sample = imageLoad(volume_texture, shadow_coord).r;
                shadow_density += shadow_sample * shadow_step_size;
            }

            // ===== BEER-LAMBERT LIGHT ATTENUATION =====
            // exponential falloff based on accumulated shadow density
            float light_transmittance = exp(-shadow_density * absorption_intensity);

            // ===== LIGHTING CALCULATION =====
            // combine directional light with shadow attenuation and ambient light
            vec4 directional_contribution = light_color * light_transmittance * scattering_intensity;
            vec4 ambient_contribution = ambient_light * ambient_light_color;
            vec4 total_light = directional_contribution + ambient_contribution;

            // ===== IN-SCATTERING =====
            // light scattered into the ray at this sample point
            float in_scatter = sampled_density * scattering_intensity * density_step_size;

            // add scattered light attenuated by current transmittance
            color += vec4(total_light.rgb * transmittance * in_scatter, 0.0);

            // ===== BEER-LAMBERT TRANSMITTANCE UPDATE =====
            // reduce transmittance based on absorption along this step
            float step_optical_depth = sampled_density * absorption_intensity * density_step_size;
            transmittance *= exp(-step_optical_depth);

            // ===== EARLY RAY TERMINATION =====

            if (any(greaterThan(ray_position, vec3(1.0))) || any(lessThan(ray_position, vec3(0.0))) || transmittance < 0.01) {
                break;
            }
        }

        // advance ray position
        vec3 prev_ray_position = ray_position;
        ray_position += ray_direction * density_step_size;

        // check if we crossed a slice boundary and write to that slice
        while (next_slice_index < n_export_textures && ray_position.z >= next_slice_depth) {
            // write current accumulated color/transmittance to this slice
            vec4 slice_color = color;
            slice_color.a = 1.0 - transmittance;

            imageStore(export_textures[next_slice_index], gid.xy, slice_color);

            // move to next slice
            next_slice_index++;
            next_slice_depth += slice_depth_step;
        }

        // exit if we've written to all slices or left the volume
        if (next_slice_index >= n_export_textures) {
            break;
        }
    }

    // write final state to any remaining slices (if ray terminated early)
    while (next_slice_index < n_export_textures) {
        vec4 final_color = color;
        final_color.a = 1.0 - transmittance;
        imageStore(export_textures[next_slice_index], gid.xy, final_color);
        next_slice_index++;
    }

    #endif // MODE_RAYMARCH
}