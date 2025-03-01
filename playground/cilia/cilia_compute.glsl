vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

float worley_noise(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float dist = 1.0;
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(i, j, k);

                vec3 p = n + g;
                p = fract(p * vec3(0.1031, 0.1030, 0.0973));
                p += dot(p, p.yxz + 19.19);
                vec3 o = fract((p.xxy + p.yzz) * p.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);
                dist = min(dist, d);
            }
        }
    }

    return 1 - dist;
}

#define MODE_UPDATE_NOISE 0
#define MODE_UPDATE_DERIVATIVE 1

#ifndef MODE
#error "MODE"
#endif

#if MODE == MODE_UPDATE_NOISE

uniform float elapsed;
layout(r32f) uniform writeonly image2D noise_texture;

#elif MODE == MODE_UPDATE_DERIVATIVE

layout(r32f) uniform readonly image2D noise_texture;
layout(rgba32f) uniform image2D derivative_texture;

#endif

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in; // dispatch with texture_width / 16, texture_height / 16
void computemain() {
    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    #if MODE == MODE_UPDATE_NOISE

    vec2 size = imageSize(noise_texture);
    float worley_scale = 1 / 100.0;
    float gradient_scale = 1 / 10.;

    vec2 position_offset = vec2(
        worley_noise(vec3(position / size * worley_scale, elapsed)),
        worley_noise(vec3(position / size * worley_scale, -1 * elapsed))
    );
    float value = 10 * position_offset.x * position_offset.y * (gradient_noise(vec3(vec2(position) * gradient_scale, elapsed)) + 1) / 2;

    imageStore(noise_texture, position, vec4(value, 0, 0, 0.5));

    #elif MODE == MODE_UPDATE_DERIVATIVE

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

    ivec2 size = imageSize(noise_texture);

    float x_gradient = 0.0;
    float y_gradient = 0.0;
    float noise_value;

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            ivec2 current_position = position + ivec2(i, j);

            current_position = clamp(current_position, ivec2(0), ivec2(size.x - 1, size.y - 1));
            float value = imageLoad(noise_texture, current_position).r;

            x_gradient += value * sobel_x[j + 1][i + 1];
            y_gradient += value * sobel_y[j + 1][i + 1];

            if (i == 0 && j == 0) // skips one texture read after loop
            noise_value = value;
        }
    }

    imageStore(derivative_texture, position, vec4(
        x_gradient,
        y_gradient,
        length(vec2(x_gradient, y_gradient)),
        noise_value
    ));

    #endif
}