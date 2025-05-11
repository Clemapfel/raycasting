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

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
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

vec4 effect(vec4 color, Image image, vec2 texture_coordinates, vec2 frag_position) {

    vec2 pixel_size = 1 / love_ScreenSize.xy;
    float gradient_x = 0.0;
    float gradient_y = 0.0;
    float eps = 0.4;

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 neighbor_uv = texture_coordinates + vec2(i, j) * pixel_size;
            float value = texture(image, neighbor_uv).a;
            value = smoothstep(0.5 - eps, 0.5 + eps, value);

            gradient_x += value * sobel_x[i + 1][j + 1];
            gradient_y += value * sobel_y[i + 1][j + 1];
        }
    }

    float magnitude = length(vec2(gradient_x, gradient_y));
    float alpha = magnitude * 2;
    float hue = (1 - magnitude) * 2;
    return vec4(vec3(1), alpha) * color;
}