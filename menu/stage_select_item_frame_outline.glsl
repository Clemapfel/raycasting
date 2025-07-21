#define MODE_OUTLINE 0
#define MODE_BASE 1

#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

#if MODE == MODE_OUTLINE

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

mat3 sobel_x = mat3(
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
);

mat3 sobel_y = mat3(
    -1, -2, -1,
     0, 0, 0,
     1, 2, 1
);

uniform float elapsed;
uniform float hue;

#endif

vec4 effect(vec4 color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {

    vec2 pixel_size = vec2(4.0 / textureSize(img, 0));

    float threshold = 0.5; // metaball threshold
    float smoothness = 0.4; // smoothness factor for blending

    #if MODE == MODE_OUTLINE

        float outline_thickness = 0.5;
        float gradient_x = 0.0;
        float gradient_y = 0.0;

        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                vec2 neighbor_uv = texture_coordinates + vec2(i, j) * pixel_size * outline_thickness;
                float value = texture(img, neighbor_uv).a;
                value = smoothstep(threshold - smoothness, threshold + smoothness, value);

                gradient_x += value * sobel_x[i + 1][j + 1];
                gradient_y += value * sobel_y[i + 1][j + 1];
            }
        }

        float magnitude = length(vec2(gradient_x, gradient_y));
        float alpha = smoothstep(0.0, 1.0, magnitude);

        float noise = 0.25 * (gradient_noise(vec3(texture_coordinates * 5, elapsed / 2)));
        vec3 hue = lch_to_rgb(vec3(0.8, 1, hue + noise));

        return vec4(hue * alpha, alpha);

    #elif MODE == MODE_BASE
        float value = texture(img, texture_coordinates).a;
        return vec4(smoothstep(threshold - smoothness, threshold + smoothness, value)) * color;

    #endif
}