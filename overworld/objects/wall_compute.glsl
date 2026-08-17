#define PATTERN_TYPE_FLAT 1
#define PATTERN_TYPE_SPHERES 2
#define PATTERN_TYPE_TRIANGLES 3
#define PATTERN_TYPE_SQUARES 4

#ifndef PATTERN_TYPE
#error "PATTERN_TYPE undefined, should be 1, 2, 3, or 4"
#endif

#ifndef TEXTURE_FORMAT
#error "TEXTURE_FORMAT undefined"
#define PATTERN_TYPE rgba8
#endif

#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X not defined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y not defined"
#endif

layout(TEXTURE_FORMAT) uniform writeonly image2D texture;

#if PATTERN_TYPE == PATTERN_TYPE_FLAT

void pattern(
in vec2 position,
out float height,
out vec3 normal
) {
    height = 0.0;
    normal = vec3(0.0, 0.0, 1.0);
}

#elif PATTERN_TYPE == PATTERN_TYPE_SPHERES

float hexagonal_dome_sdf(vec2 position, out vec3 surface_normal) {
    const float radius = 1.0;
    const float height = 1.0;
    const float sqrt3 = 1.7320508075688772;

    float q = position.x * sqrt3 / 3.0 - position.y / 3.0;
    float r = position.y * 2.0 / 3.0;
    float s = -q - r;

    float rq = round(q);
    float rr = round(r);
    float rs = round(s);

    float q_diff = abs(rq - q);
    float r_diff = abs(rr - r);
    float s_diff = abs(rs - s);

    if (q_diff > r_diff && q_diff > s_diff) {
        rq = -rr - rs;
    } else if (r_diff > s_diff) {
        rr = -rq - rs;
    } else {
        rs = -rq - rr;
    }

    vec2 hex_center = vec2(sqrt3 * rq + sqrt3 / 2.0 * rr, 3.0 / 2.0 * rr);
    vec2 offset = position - hex_center;
    float horizontal_dist_sq = dot(offset, offset);
    float radius_sq = radius * radius;

    if (horizontal_dist_sq >= radius_sq) {
        surface_normal = normalize(vec3(0.0, 0.0, 1.0));
        return distance(position, hex_center) / radius;
    }

    float sphere_radius = (radius_sq + height * height) / (2.0 * height);
    float sphere_center_z = sphere_radius - height;
    float z = sphere_center_z + sqrt(sphere_radius * sphere_radius - horizontal_dist_sq);

    vec3 surface_point = vec3(offset.x, offset.y, z);
    vec3 sphere_center = vec3(0.0, 0.0, sphere_center_z);

    surface_normal = normalize(surface_point - sphere_center);
    return distance(position, hex_center) / radius;
}

void pattern(
in vec2 position,
out float height,
out vec3 normal
) {
    int tiling_repeats = 20;

    vec2 period = vec2(sqrt(3.0), 3.0);
    vec2 p = position * float(tiling_repeats) * period;

    height = hexagonal_dome_sdf(p, normal);
}

#elif PATTERN_TYPE == PATTERN_TYPE_TRIANGLES

void triangle_tiling(vec2 p, out float height, out vec3 normal) {
    const float H_half = 0.5;
    const float sqrt3_2 = sqrt(3.0) / 2.0;

    p = p / sqrt(3.0);

    float u1 = fract(p.y + H_half) - H_half;
    float d1 = abs(u1);
    vec2 grad1 = vec2(0.0, sign(u1));

    float v2 = p.x * sqrt3_2 + p.y * 0.5;
    float u2 = fract(v2 + H_half) - H_half;
    float d2 = abs(u2);
    vec2 grad2 = vec2(sqrt3_2, 0.5) * sign(u2);

    float v3 = -p.x * sqrt3_2 + p.y * 0.5;
    float u3 = fract(v3 + H_half) - H_half;
    float d3 = abs(u3);
    vec2 grad3 = vec2(-sqrt3_2, 0.5) * sign(u3);

    height = 1.0 - min(d1, min(d2, d3));

    vec2 active_grad = grad1;
    if (d2 < d1 && d2 < d3) active_grad = grad2;
    else if (d3 < d1 && d3 < d2) active_grad = grad3;

    const float steepness = 0.5;
    normal = normalize(vec3(-active_grad * steepness, 1.0));
}

void pattern(
in vec2 position,
out float height,
out vec3 normal
) {
    int tiling_repeats = 17;

    vec2 period = vec2(2.0, 2.0 * sqrt(3.0));
    vec2 p = position * float(tiling_repeats) * period;

    triangle_tiling(p, height, normal);
}

#elif PATTERN_TYPE == PATTERN_TYPE_SQUARES

void square_tiling(vec2 p, out float height, out vec3 normal) {
    const float H_half = 0.5;

    vec2 u = fract(p + H_half) - H_half;
    vec2 d = abs(u);
    float max_d = max(d.x, d.y);

    // Peak (height = 1) at the cell center, falling to 0 at the cell edges,
    // matching the orientation of the triangle/sphere patterns.
    height = 2.0 * max_d;

    // The dominant axis (the one farther from center) determines which pair
    // of pyramid faces we're on, and thus the slope direction.
    vec2 active_grad;
    if (d.x > d.y) {
        active_grad = vec2(sign(u.x), 0.0);
    } else {
        active_grad = vec2(0.0, sign(u.y));
    }

    // steepness = 2.0 to match d(height)/d(u) = -2*sign(u) along the active axis
    const float steepness = 2.0;
    normal = normalize(vec3(-active_grad * steepness, 1.0));
}

vec2 rotate(vec2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c) * p;
}

void pattern(
in vec2 position,
out float height,
out vec3 normal
) {
    int tiling_repeats = 25;

    vec2 period = vec2(sqrt(2.0), sqrt(2.0));
    vec2 p = position * float(tiling_repeats) * period;

    p = rotate(p, radians(45.0));
    square_tiling(p, height, normal);
}

#else
#error "Unhandled PATTERN_TYPE, should be 1, 2, 3, or 4"
#endif

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = 1) in;
void computemain() {
    vec2 image_size = vec2(imageSize(texture).xy);
    ivec2 pixel_position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(pixel_position, image_size))) return;

    vec2 position = vec2(pixel_position) / vec2(image_size);

    float height; // in [ 0, 1]
    vec3 normal; // in [-1, 1]
    pattern(position, height, normal);

    // project normal into [0, 1]
    normal = normalize(normal);
    normal = (normal + 1.0) / 2.0;

    // write to texture
    imageStore(texture, pixel_position, vec4(
        normal.xyz,
        height
    ));
}