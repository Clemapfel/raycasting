//
// use JFA to construct SDF, then post-process gradient of SDF
//

#define MODE_INITIALIZE 0        // initialize jump flood fill
#define MODE_JUMP 1              // step jump flood fill
#define MODE_POST_PROCESS 2      // modify sdf
#define MODE_CONVERT 3           // convert from jfa to final normal map

#ifndef MODE
#error "In normal_map_compute.glsl: MODE is undefined, must be 0, 1, or 2"
#endif

#define MASK_TEXTURE_FORMAT rgba8
#define JFA_TEXTURE_FORMAT rgba32f
#define NORMAL_MAP_TEXTURE_FORMAT rg8

#if MODE == MODE_INITIALIZE

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2D input_texture;  // xy: nearest wall pixel coords, z: distance, w: sign of distance
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

#elif MODE == MODE_JUMP

layout(JFA_TEXTURE_FORMAT) uniform readonly image2D input_texture;
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

#elif MODE == MODE_POST_PROCESS

#elif MODE == MODE_CONVERT

layout(JFA_TEXTURE_FORMAT) uniform readonly image2D input_texture;
layout(NORMAL_MAP_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

#endif

uniform int jump_distance; // k / 2, k / 2 / 2, ..., 1, where k = max(size(input_texture))

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

    vec4 pixel = imageLoad(mask_texture, position);
    if (pixel.a > threshold) {
        uint n_others = 0;
        for (uint i = 0; i < 8; ++i) {
            ivec2 neighbor_position = position + directions[i];
            if (neighbor_position.x < 0 || neighbor_position.x >= image_size.x || neighbor_position.y < 0 || neighbor_position.y >= image_size.y)
            continue;

            vec4 other = imageLoad(mask_texture, neighbor_position);
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

    vec4 best = self;
    for (int i = 0; i < 8; ++i) {
        ivec2 neighbor_position = position + directions[i] * jump_distance;

        // if outside, skip
        if (neighbor_position.x < 0 ||
        neighbor_position.x >= image_size.x ||
        neighbor_position.y < 0 ||
        neighbor_position.y >= image_size.y
        )
        continue;

        vec4 neighbor = imageLoad(input_texture, neighbor_position);
        if (neighbor.x < 0 || neighbor.y < 0) // is uninitialized
        continue;

        float dist = distance(vec2(position), vec2(neighbor.xy));
        if (dist <= best.z)
        best = vec4(neighbor.xy, dist, self.w);
    }

    imageStore(output_texture, position, best);

    #elif MODE == MODE_POST_PROCESS

    // compute gradient

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

    // convert rgba32f to rg8
    imageStore(output_texture, vec4(gradient.xy, 1, 1));

    #endif
}