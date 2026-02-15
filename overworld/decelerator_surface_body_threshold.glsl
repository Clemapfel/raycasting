#ifdef PIXEL

uniform float threshold = 0.5;
uniform float smoothness = 0.0;

float finalize(float x) {
    return smoothstep(
        max(0, threshold - smoothness),
        min(1, threshold + smoothness),
        x
    );
}

uniform float outline_width = 1.f / 4;

vec2 derivative(sampler2D img, vec2 position) {
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

    vec2 texel_size = vec2(outline_width) / textureSize(img, 0);

    float s00 = texture(img, position + texel_size * vec2(-1.0, -1.0)).r;
    float s01 = texture(img, position + texel_size * vec2( 0.0, -1.0)).r;
    float s02 = texture(img, position + texel_size * vec2( 1.0, -1.0)).r;
    float s10 = texture(img, position + texel_size * vec2(-1.0,  0.0)).r;
    float s11 = texture(img, position + texel_size * vec2( 0.0,  0.0)).r;
    float s12 = texture(img, position + texel_size * vec2( 1.0,  0.0)).r;
    float s20 = texture(img, position + texel_size * vec2(-1.0,  1.0)).r;
    float s21 = texture(img, position + texel_size * vec2( 0.0,  1.0)).r;
    float s22 = texture(img, position + texel_size * vec2( 1.0,  1.0)).r;

    s01 = finalize(s01);
    s02 = finalize(s02);
    s10 = finalize(s10);
    s11 = finalize(s11);
    s12 = finalize(s12);
    s20 = finalize(s20);
    s21 = finalize(s21);
    s22 = finalize(s22);

    float dx = sobel_x[0][0] * s00 + sobel_x[0][1] * s01 + sobel_x[0][2] * s02 +
    sobel_x[1][0] * s10 + sobel_x[1][1] * s11 + sobel_x[1][2] * s12 +
    sobel_x[2][0] * s20 + sobel_x[2][1] * s21 + sobel_x[2][2] * s22;

    float dy = sobel_y[0][0] * s00 + sobel_y[0][1] * s01 + sobel_y[0][2] * s02 +
    sobel_y[1][0] * s10 + sobel_y[1][1] * s11 + sobel_y[1][2] * s12 +
    sobel_y[2][0] * s20 + sobel_y[2][1] * s21 + sobel_y[2][2] * s22;

    return vec2(dx, dy);
}

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


float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}


// Extra hash helpers derived from same cell
vec3 cellHash3(vec3 c) {
    return fract(sin(vec3(
    dot(c, vec3(41.37, 27.17, 73.21)),
    dot(c, vec3(17.13, 37.41, 19.91)),
    dot(c, vec3(29.31, 11.97, 59.33))
    )) * 43758.5453);
}

// Fast hash based on integer cell coordinate
float cellHash(vec3 c) {
    // very cheap deterministic hash
    return fract(sin(dot(c, vec3(41.37, 27.17, 73.21))) * 43758.5453);
}

float sparse_worley_noise(vec3 p, float density) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float dist = 1.0;
    bool found = false;

    // Same 3x3x3 neighborhood as classic Worley
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {

                vec3 g = vec3(i, j, k);
                vec3 cell = n + g;

                // ---- SPARSITY TEST ----
                // If this cell is not "active", skip all heavy math
                if (cellHash(cell) > density)
                continue;

                found = true;

                // ----- original feature point code -----
                vec3 p2 = cell;
                p2 = fract(p2 * vec3(0.1031, 0.1030, 0.0973));
                p2 += dot(p2, p2.yxz + 19.19);
                vec3 o = fract((p2.xxy + p2.yzz) * p2.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);
                dist = min(dist, d);
            }
        }
    }

    // If no nearby active cells, return empty space
    if (!found)
    return 0.0;

    return 1.0 - dist;
}

float net_texture(vec2 uv, float elapsed) {
    return dirac(smoothstep(0, 1 - 0.3, sparse_worley_noise(vec3(uv, elapsed), 0.1)));
}

uniform mat4x4 screen_to_world_transform;
uniform float elapsed;

vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform vec4 outline_color = vec4(1, 1, 1, 1);
uniform vec4 body_color = vec4(0.3, 0.3, 0.3, 1);

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 screen_coords)
{
    // threshold
    vec4 data = texture(tex, texture_coordinates);
    float body = finalize(data.r);
    float mask = data.g;
    float outline = smoothstep(0, 0.5, min(1, length(derivative(tex, texture_coordinates))));

    // texture
    const float noise_scale = 1.f / 12;
    vec2 world_position = to_world_position(screen_coords);
    float noise = mask * net_texture(world_position * noise_scale, elapsed / 2);

    vec3 texture = mix(body_color.rgb, outline_color.rgb, noise);

    float background_noise = gradient_noise(vec3(world_position / 30, elapsed / 4));

    return 0.25 * mask * mix(body_color, outline_color, background_noise) + min(vec4(1), vec4(vec4(texture, 1) * body + outline_color * outline));
}

#endif