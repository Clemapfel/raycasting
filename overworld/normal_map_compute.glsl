//
// use JFA to construct SDF, then post-process gradient of SDF
//

#define MODE_INITIALIZE 0        // initialize jump flood fill
#define MODE_JUMP 1              // step jump flood fill
#define MODE_EXPORT 2            // compute gradient, convert rgba32f to rg8

#ifndef MODE
#error "In normal_map_compute.glsl: MODE is undefined, must be 0, 1, or 2"
#endif

#define MASK_TEXTURE_FORMAT rgba8
#define JFA_TEXTURE_FORMAT rgba32f
#define NORMAL_MAP_TEXTURE_FORMAT rgb10_a2

#if MODE == MODE_INITIALIZE

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2D input_texture;  // xy: nearest wall pixel coords, z: distance, w: sign of distance
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

#elif MODE == MODE_JUMP

uniform int jump_distance; // k / 2, k / 2 / 2, ..., 1, where k = max(size(input_texture))

layout(JFA_TEXTURE_FORMAT) uniform readonly image2D input_texture;
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

#elif MODE == MODE_EXPORT

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
layout(JFA_TEXTURE_FORMAT) uniform readonly image2D input_texture;
layout(NORMAL_MAP_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

#endif

const float infinity = 1 / 0.f;

uniform float threshold = 0;
uniform float max_distance = 32;

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

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = 1) in; // dispatch with area_w / 32, area_h / 32
void computemain() {
    ivec2 image_size = imageSize(input_texture);
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    if (any(greaterThanEqual(position, image_size))) return;

    #if MODE == MODE_INITIALIZE

    const vec4 inner_wall = vec4(-1, -1, infinity, -1);      // inside walled area
    const vec4 wall = vec4(position.x, position.y, -1, 0);   // boundary of walled area
    const vec4 non_wall = vec4(-1, -1, infinity, 1);         // free space

    vec4 pixel = imageLoad(mask_texture, position);

    if (pixel.a > threshold) {
        uint n_others = 0;
        for (uint i = 0; i < 8; ++i) {
            ivec2 neighbor_position = position + directions[i];
            if (!all(greaterThanEqual(neighbor_position, ivec2(0))) || any(greaterThanEqual(neighbor_position, image_size)))
            continue;

            vec4 other = imageLoad(mask_texture, neighbor_position);
            if (other.a > threshold) n_others += 1;
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
        if (!all(greaterThanEqual(neighbor_position, ivec2(0))) || any(greaterThanEqual(neighbor_position, image_size)))
        continue;

        vec4 neighbor = imageLoad(input_texture, neighbor_position);
        if (any(lessThan(neighbor.xy, vec2(0)))) // is uninitialized
        continue;

        float dist = distance(vec2(position), vec2(neighbor.xy));
        if (dist <= best.z)
        best = vec4(neighbor.xy, dist, self.w);
    }

    imageStore(output_texture, position, best);

    #elif MODE == MODE_EXPORT

    // compute gradient (optimized Sobel operator - only non-zero terms)

    float v00 = imageLoad(input_texture, position + ivec2(-1, -1)).z;
    float v02 = imageLoad(input_texture, position + ivec2( 1, -1)).z;
    float v10 = imageLoad(input_texture, position + ivec2(-1,  0)).z;
    float v11 = imageLoad(input_texture, position + ivec2( 0,  0)).z;
    float v12 = imageLoad(input_texture, position + ivec2( 1,  0)).z;
    float v20 = imageLoad(input_texture, position + ivec2(-1,  1)).z;
    float v22 = imageLoad(input_texture, position + ivec2( 1,  1)).z;

    // Only load center column for y-gradient
    float v01 = imageLoad(input_texture, position + ivec2( 0, -1)).z;
    float v21 = imageLoad(input_texture, position + ivec2( 0,  1)).z;

    float x_gradient = -v00 + v02 - 2.0 * v10 + 2.0 * v12 - v20 + v22;
    float y_gradient = -v00 - 2.0 * v01 - v02 + v20 + 2.0 * v21 + v22;

    vec2 gradient = vec2(x_gradient, y_gradient);

    gradient.x = -1 * sign(x_gradient) - x_gradient;
    gradient.y = -1 * sign(y_gradient) - y_gradient;

    // map to rg8, encode normalized distance in vector length

    gradient = normalize(gradient);
    gradient *= clamp(abs(v11) / max_distance, 0, 1);
    gradient = (gradient + 1) / 2; // project into 0, 1

    vec4 mask = imageLoad(mask_texture, position);
    vec4 current = imageLoad(input_texture, position);

    imageStore(output_texture, position, vec4(
    current.z / max_distance,  // normalized distance
    gradient.x, gradient.y,    // gradient in [0, 1]
    mask.a                     // mask (2 bits of precision)
    ));

    #endif
}