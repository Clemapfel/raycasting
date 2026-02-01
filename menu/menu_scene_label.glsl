
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


vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

uniform float elapsed;
#define PI 3.1415926535897932384626433832795

#ifdef VERTEX

vec4 position(mat4 transform, vec4 vertex_position) {
    int letter_index = gl_VertexID / 4;
    vec2 offset = vec2(
        gradient_noise(vec3(vec2(vertex_position), elapsed)),
        gradient_noise(vec3(vec2(-vertex_position), elapsed))
    );
    vertex_position.xy += 3 * offset;

    return transform * vertex_position;
}
#endif

#ifdef PIXEL

#define MODE_NO_SDF 0
#define MODE_SDF 1

uniform vec4 black;

#if MODE == MODE_SDF

vec4 effect(vec4 color, Image img, vec2 texture_coords, vec2 vertex_position) {
    float dist = texture(img, texture_coords).a;
    const float thickness = 1 - 0.05;
    return vec4(vec3(smoothstep(0.0, 1 - thickness, dist)), 1) * black;
}

#elif MODE == MODE_NO_SDF

vec2 clamped_coords(vec2 base_coords, vec2 offset, vec2 texel_size) {
    return clamp(base_coords + texel_size * offset, vec2(0.0 + 2 * texel_size), vec2(1.0 - 2 * texel_size));
}

uniform float hue;
uniform vec2 camera_offset;
uniform float camera_scale = 1;
vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 color, Image img, vec2 texture_coords, vec2 vertex_position) {
    vec2 seed = to_uv(vertex_position) * 140;
    vec2 seed_magnitude = 3.5 * 1 / love_ScreenSize.xy;
    texture_coords += vec2(
        gradient_noise(vec3(seed, elapsed)) * seed_magnitude.x,
        gradient_noise(vec3(-seed.yx, elapsed)) * seed_magnitude.y
    );

    // Sobel kernels
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

    // Texture coordinate offsets
    vec2 texel_size = vec2(1.0) / textureSize(img, 0);

    // Sample the image at the 3x3 neighborhood
    float s00 = Texel(img, clamped_coords(texture_coords, vec2(-1, -1), texel_size)).a;
    float s01 = Texel(img, clamped_coords(texture_coords, vec2( 0, -1), texel_size)).a;
    float s02 = Texel(img, clamped_coords(texture_coords, vec2( 1, -1), texel_size)).a;
    float s10 = Texel(img, clamped_coords(texture_coords, vec2(-1,  0), texel_size)).a;
    float s11 = Texel(img, clamped_coords(texture_coords, vec2( 0,  0), texel_size)).a;
    float s12 = Texel(img, clamped_coords(texture_coords, vec2( 1,  0), texel_size)).a;
    float s20 = Texel(img, clamped_coords(texture_coords, vec2(-1,  1), texel_size)).a;
    float s21 = Texel(img, clamped_coords(texture_coords, vec2( 0,  1), texel_size)).a;
    float s22 = Texel(img, clamped_coords(texture_coords, vec2( 1,  1), texel_size)).a;

    // Apply Sobel kernels
    float gx = sobel_x[0][0] * s00 + sobel_x[0][1] * s01 + sobel_x[0][2] * s02 +
    sobel_x[1][0] * s10 + sobel_x[1][1] * s11 + sobel_x[1][2] * s12 +
    sobel_x[2][0] * s20 + sobel_x[2][1] * s21 + sobel_x[2][2] * s22;

    float gy = sobel_y[0][0] * s00 + sobel_y[0][1] * s01 + sobel_y[0][2] * s02 +
    sobel_y[1][0] * s10 + sobel_y[1][1] * s11 + sobel_y[1][2] * s12 +
    sobel_y[2][0] * s20 + sobel_y[2][1] * s21 + sobel_y[2][2] * s22;

    float edge_threshold_low = 0;  // Lower threshold for smoothstep
    float edge_threshold_high = 1.5; // Higher threshold for smoothstep

    float magnitude = length(vec2(gx, gy));
    magnitude = smoothstep(edge_threshold_low, edge_threshold_high, magnitude);

    vec2 uv = to_uv(vertex_position);
    uv += vec2(elapsed / 20);
    uv = rotate(uv, 0.33 * PI);
    uv.x /= 2;
    uv.y *= 1;
    uv = rotate(uv, -0.33 * PI);

    float noise = gradient_noise(vec3(uv * 15, elapsed / 2));

    vec3 hue = lch_to_rgb(vec3(0.8, 1, hue + noise));
    return vec4(hue, magnitude);
}

#endif

#endif