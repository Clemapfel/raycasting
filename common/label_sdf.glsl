//
// use JFA to construct SDF, then post-process gradient of SDF
//

#define MODE_INITIALIZE 0        // initialize jump flood fill
#define MODE_JUMP 1              // step jump flood fill
#define MODE_EXPORT 2            // compute gradient, convert rgba32f to rg8

#ifndef MODE
#error "In normal_map_compute.glsl: MODE is undefined, must be 0, 1, 2, or 3"
#endif

#ifndef MASK_TEXTURE_FORMAT
#error "MASK_TEXTURE_FORMAT undefined"
#endif

#ifndef JFA_TEXTURE_FORMAT
#error "JFA_TEXTURE_FORMAT undefined"
#endif

#ifndef EXPORT_TEXTURE_FORMAT
#error "EXPORT_TEXUTRE_FORMAT undefined"
#endif

#if MODE == MODE_INITIALIZE

layout(JFA_TEXTURE_FORMAT) uniform image2DArray jfa_texture_array;
layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;

#elif MODE == MODE_JUMP

uniform int jump_distance; // k / 2, k / 2 / 2, ..., 1, where k = max(size(input_texture))
uniform int input_layer;   // which layer to read from (0 or 1)
uniform int output_layer;  // which layer to write to (0 or 1)

layout(JFA_TEXTURE_FORMAT) uniform image2DArray jfa_texture_array;

#elif MODE == MODE_EXPORT

layout(MASK_TEXTURE_FORMAT) uniform readonly image2D mask_texture;
layout(JFA_TEXTURE_FORMAT) uniform readonly image2DArray jfa_texture_array;
layout(EXPORT_TEXTURE_FORMAT) uniform writeonly image2D export_texture;

uniform int layer;
uniform bool apply_mask = false;

#endif

const float infinity = 1.0 / 0.0;
const float threshold = 0;
uniform float max_distance = 16;

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

    const vec4 inner_wall = vec4(-1, -1, infinity, -1);    // inside walled area
    const vec4 wall = vec4(position.x, position.y, -1, 0); // boundary of walled area
    const vec4 non_wall = vec4(-1, -1, infinity, 1);       // free space

    vec4 pixel = imageLoad(mask_texture, ivec2(position));

    if (pixel.r > threshold) {
        uint n_others = 0;
        for (uint i = 0; i < 8; ++i) {
            ivec2 neighbor_position = position + directions[i];
            if (!all(greaterThanEqual(neighbor_position, ivec2(0))) || any(greaterThanEqual(neighbor_position, image_size)))
            continue;

            vec4 other = imageLoad(mask_texture, neighbor_position);
            if (other.r > threshold)
            n_others += 1;
        }

        if (n_others >= 8) {
            imageStore(jfa_texture_array, ivec3(position, 0), inner_wall);
        }
        else {
            imageStore(jfa_texture_array, ivec3(position, 0), wall);
            imageStore(jfa_texture_array, ivec3(position, 1), wall);
        }
    } else {
        imageStore(jfa_texture_array, ivec3(position, 0), non_wall);
    }

    #elif MODE == MODE_JUMP

    vec4 self = imageLoad(jfa_texture_array, ivec3(position, input_layer));

    if (self.z == 0) return; // is outer wall

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

    imageStore(jfa_texture_array, ivec3(position, output_layer), best);

    #elif MODE == MODE_EXPORT

    vec4 value = imageLoad(jfa_texture_array, ivec3(position, layer));
    vec4 mask = imageLoad(mask_texture, ivec2(position));

    if (apply_mask && mask.r > 0)
        value *= 0;

    imageStore(export_texture, ivec2(position), value.zzzz / max_distance);

    #endif
}