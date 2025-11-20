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

#define MODE_THRESHOLD 0
#define MODE_OUTLINE 1

#ifndef MODE
#error "In player_body_outline.glsl: `MODE` undefined"
#endif

#if MODE == MODE_THRESHOLD

vec4 effect(vec4 color, Image img, vec2 texture_coordinates, vec2 frag_position) {

    float threshold = 0.6; // Metaball threshold
    float smoothness = 0.05; // Smoothness factor for blending
    float outline_thickness = 2; // Increase this value to thicken the outline

    vec4 data = texture(img, texture_coordinates);
    float value = smoothstep(
        threshold - smoothness,
        threshold + smoothness,
        data.a
    );

    return vec4(value);
}

#elif MODE == MODE_OUTLINE

vec4 effect(vec4 color, Image image, vec2 texture_coordinates, vec2 frag_position) {
    vec2 pixel_size = vec2(1 / 250.0);

    // Sample only the 6 texels where Sobel kernels have non-zero values
    // Sobel X kernel non-zero positions: (-1,-1)=-1, (-1,1)=1, (0,-1)=-2, (0,1)=2, (1,-1)=-1, (1,1)=1
    // Sobel Y kernel non-zero positions: (-1,-1)=-1, (-1,0)=-2, (-1,1)=-1, (1,-1)=1, (1,0)=2, (1,1)=1

    float tl = texture(image, texture_coordinates + vec2(-1, -1) * pixel_size).a; // top-left
    float tm = texture(image, texture_coordinates + vec2( 0, -1) * pixel_size).a; // top-middle
    float tr = texture(image, texture_coordinates + vec2( 1, -1) * pixel_size).a; // top-right
    float ml = texture(image, texture_coordinates + vec2(-1,  0) * pixel_size).a; // middle-left
    float mr = texture(image, texture_coordinates + vec2( 1,  0) * pixel_size).a; // middle-right
    float bl = texture(image, texture_coordinates + vec2(-1,  1) * pixel_size).a; // bottom-left
    float bm = texture(image, texture_coordinates + vec2( 0,  1) * pixel_size).a; // bottom-middle
    float br = texture(image, texture_coordinates + vec2( 1,  1) * pixel_size).a; // bottom-right

    float gradient_x = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
    float gradient_y = -tl - 2.0 * tm - tr + bl + 2.0 * bm + br;

    float magnitude = length(vec2(gradient_x, gradient_y));
    float alpha = smoothstep(0.0, 1, magnitude);

    return vec4(vec3(1.0), alpha) * color;
}

#endif


