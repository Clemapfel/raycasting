//
// use JFA to construct SDF, then post-process gradient of SDF
//

#define MODE_INITIALIZE 0        // initialize jump flood fill
#define MODE_JUMP 1              // step jump flood fill
#define MODE_EXPORT 2            // compute gradient, convert rgba32f to rg8
#define MODE_CLEAR 3             // clear array texture

#ifndef MODE
#error "In normal_map_compute.glsl: MODE is undefined, must be 0, 1, 2, or 3"
#endif

#define MASK_TEXTURE_FORMAT rgba8
#define JFA_TEXTURE_FORMAT rgba32f
#define NORMAL_MAP_TEXTURE_FORMAT rgb10_a2

#if MODE == MODE_INITIALIZE

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2DArray jfa_texture_array;

#elif MODE == MODE_JUMP

uniform int jump_distance; // k / 2, k / 2 / 2, ..., 1, where k = max(size(input_texture))
uniform int input_layer;   // which layer to read from (0 or 1)
uniform int output_layer;  // which layer to write to (0 or 1)

layout(JFA_TEXTURE_FORMAT) uniform readonly image2DArray jfa_texture_array;
layout(JFA_TEXTURE_FORMAT) uniform writeonly image2DArray jfa_texture_array_out;

#elif MODE == MODE_EXPORT

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
layout(JFA_TEXTURE_FORMAT) uniform readonly image2DArray jfa_texture_array;
layout(NORMAL_MAP_TEXTURE_FORMAT) uniform writeonly image2D output_texture;

uniform int final_layer;  // which layer contains the final JFA result

#elif MODE == MODE_CLEAR

layout(JFA_TEXTURE_FORMAT) uniform writeonly image2DArray jfa_texture_array;

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

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = 1) in;
void computemain() {
    ivec3 array_size = imageSize(jfa_texture_array);
    ivec2 image_size = array_size.xy;
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
            if (other.a > threshold)
                n_others += 1;
        }

        if (n_others >= 8) {
            // Write to layer 0 (initial state)
            imageStore(jfa_texture_array, ivec3(position, 0), inner_wall);
        }
        else {
            // Write to both layers since this is a boundary
            imageStore(jfa_texture_array, ivec3(position, 0), wall);
            imageStore(jfa_texture_array, ivec3(position, 1), wall);
        }
    } else {
        // Write to layer 0 (initial state)
        imageStore(jfa_texture_array, ivec3(position, 0), non_wall);
    }

    #elif MODE == MODE_JUMP

    vec4 self = imageLoad(jfa_texture_array, ivec3(position, input_layer));

    if (self.z == 0) // is outer wall
    return;

    vec4 best = self;
    for (int i = 0; i < 8; ++i) {
        ivec2 neighbor_position = position + directions[i] * jump_distance;

        // if outside, skip
        if (!all(greaterThanEqual(neighbor_position, ivec2(0))) || any(greaterThanEqual(neighbor_position, image_size)))
        continue;

        vec4 neighbor = imageLoad(jfa_texture_array, ivec3(neighbor_position, input_layer));
        if (any(lessThan(neighbor.xy, vec2(0)))) // is uninitialized
        continue;

        float dist = distance(vec2(position), vec2(neighbor.xy));
        if (dist <= best.z)
        best = vec4(neighbor.xy, dist, self.w);
    }

    imageStore(jfa_texture_array_out, ivec3(position, output_layer), best);

    #elif MODE == MODE_EXPORT

    // compute gradient (optimized Sobel operator - only non-zero terms)

    float v00 = imageLoad(jfa_texture_array, ivec3(position + ivec2(-1, -1), final_layer)).z;
    float v02 = imageLoad(jfa_texture_array, ivec3(position + ivec2( 1, -1), final_layer)).z;
    float v10 = imageLoad(jfa_texture_array, ivec3(position + ivec2(-1,  0), final_layer)).z;
    float v11 = imageLoad(jfa_texture_array, ivec3(position + ivec2( 0,  0), final_layer)).z;
    float v12 = imageLoad(jfa_texture_array, ivec3(position + ivec2( 1,  0), final_layer)).z;
    float v20 = imageLoad(jfa_texture_array, ivec3(position + ivec2(-1,  1), final_layer)).z;
    float v22 = imageLoad(jfa_texture_array, ivec3(position + ivec2( 1,  1), final_layer)).z;

    // Only load center column for y-gradient
    float v01 = imageLoad(jfa_texture_array, ivec3(position + ivec2( 0, -1), final_layer)).z;
    float v21 = imageLoad(jfa_texture_array, ivec3(position + ivec2( 0,  1), final_layer)).z;

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
    vec4 current = imageLoad(jfa_texture_array, ivec3(position, final_layer));

    imageStore(output_texture, position, vec4(
    current.z / max_distance,  // normalized distance
    gradient.x, gradient.y,    // gradient in [0, 1]
    mask.a                     // mask (2 bits of precision)
    ));

    #elif MODE == MODE_CLEAR

    // Clear both layers
    imageStore(jfa_texture_array, ivec3(position, 0), vec4(0, 0, 0, 0));
    imageStore(jfa_texture_array, ivec3(position, 1), vec4(0, 0, 0, 0));

    #endif
}