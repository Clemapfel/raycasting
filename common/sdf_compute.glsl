//
// use JFA to construct SDF, then post-process gradient of SDF
//

#define MODE_INITIALIZE 0        // initialize jump flood fill
#define MODE_JUMP 1              // step jump flood fill
#define MODE_COMPUTE_GRADIENT 2  // modify and compute gradient of sdf

#ifndef MODE
#error "In blood_compute_sdf.glsl: MODE is undefined, it be one of [0, 1, 2]"
#endif

#if MODE == MODE_INITIALIZE
layout(rgba8) uniform readonly image2D hitbox_texture;
layout(rgba32f) uniform writeonly image2D input_texture;  // xy: nearest wall pixel coords, z: distance, w: sign of distance
layout(rgba32f) uniform writeonly image2D output_texture;
#elif MODE == MODE_JUMP
layout(rgba32f) uniform readonly image2D input_texture;
layout(rgba32f) uniform writeonly image2D output_texture;
#elif MODE == MODE_COMPUTE_GRADIENT
layout(rgba32f) uniform readonly image2D input_texture;
layout(rgba32f) uniform writeonly image2D output_texture;
uniform bool should_blur = false;
#endif

uniform int jump_distance; // k / 2, k / 2 / 2, ..., 1, where k = max(size(input_texture))

#define WALL_MODE_BOTH 0
#define WALL_MODE_INSIDE 1
#define WALL_MODE_OUTSIDE 2
uniform int wall_mode = 0;

const float infinity = 1 / 0.f;
uniform float threshold = 0;

const ivec2 directions[8] = ivec2[](
    ivec2(0, -1),
    ivec2(1, 0),
    ivec2(0, 1),
    ivec2(-1, 0),
    ivec2(1, -1),
    ivec2(1, 1),
    ivec2(-1, 1),
    ivec2(-1, -1)
);

layout (local_size_x = 32, local_size_y = 32, local_size_z = 1) in; // dispatch with area_w / 32, area_h / 32
void computemain() {
    ivec2 image_size = imageSize(input_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (position.x >= image_size.x || position.y >= image_size.y) return;

    #if MODE == MODE_INITIALIZE
    const vec4 inner_wall = vec4(-1, -1, infinity, -1);      // inside walled area
    const vec4 wall = vec4(position.x, position.y, -1, 0);   // boundary of walled area
    const vec4 non_wall = vec4(-1, -1, infinity, 1);         // free space

    vec4 pixel = imageLoad(hitbox_texture, position);
    if (pixel.a > threshold) {
        uint n_others = 0;
        for (uint i = 0; i < 8; ++i) {
            ivec2 neighbor_position = position + directions[i];
            if (neighbor_position.x < 0 || neighbor_position.x >= image_size.x || neighbor_position.y < 0 || neighbor_position.y >= image_size.y)
                continue;

            vec4 other = imageLoad(hitbox_texture, neighbor_position);
            if (other.a > threshold)
                n_others += 1;
            else
                break;
        }

        if (n_others >= 8) {
            imageStore(input_texture, position, inner_wall);
        }
        else {
            imageStore(input_texture, position, wall);
            imageStore(output_texture, position, wall);
        }
    } else {
        imageStore(input_texture, position, non_wall);
    }

    #elif MODE == MODE_JUMP

    vec4 self = imageLoad(input_texture, position);
    if (self.z == 0) // is outer wall
        return;

    if ((wall_mode == WALL_MODE_INSIDE && self.w > 0) ||
    (wall_mode == WALL_MODE_OUTSIDE && self.w < 0)) {
        imageStore(output_texture, position, vec4(0));
        return;
    }

    vec4 best = self;
    for (int i = 0; i < 8; ++i) {
        ivec2 neighbor_position = position + directions[i] * jump_distance;

        // if outside, skip
        if (neighbor_position.x < 0 || neighbor_position.x >= image_size.x || neighbor_position.y < 0 || neighbor_position.y >= image_size.y)
            continue;

        vec4 neighbor = imageLoad(input_texture, neighbor_position);
        if (neighbor.x < 0 || neighbor.y < 0) // is uninitialized
            continue;

        if ((wall_mode == WALL_MODE_INSIDE && neighbor.w > 0) ||
            (wall_mode == WALL_MODE_OUTSIDE && neighbor.w < 0))
            continue;

        float dist = distance(vec2(position), vec2(neighbor.xy));
        if (dist <= best.z)
            best = vec4(neighbor.xy, dist, self.w);
    }

    imageStore(output_texture, position, best);

    #elif MODE == MODE_COMPUTE_GRADIENT
    const mat3 sobel_x = mat3(
        -1.0,  0.0,  1.0,
        -2.0,  0.0,  2.0,
        -1.0,  0.0,  1.0
    );
    const mat3 sobel_y = mat3(
        -1.0, -2.0, -1.0,
        0.0,  0.0,  0.0,
        1.0,  2.0,  1.0
    );

    float x_gradient = 0.0;
    float y_gradient = 0.0;

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            ivec2 current_position = position + ivec2(i, j);
            if (current_position.x < 0 || current_position.x >= image_size.x || current_position.y < 0 || current_position.y >= image_size.y)
                continue;

            float value = imageLoad(input_texture, current_position).z;
            x_gradient += value * sobel_x[j + 1][i + 1];
            y_gradient += value * sobel_y[j + 1][i + 1];
        }
    }

    vec4 current = imageLoad(input_texture, position);
    vec2 gradient = normalize(vec2(x_gradient, y_gradient));

    imageStore(output_texture, position, vec4(
        gradient, current.z, current.w
    ));
    #endif
}