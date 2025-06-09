vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2
    const float K2 = 0.211324865; // (3-sqrt(3))/6

    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    vec2 o = step(a.yx, a.xy);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;

    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));

    return dot(n, vec3(70.0));
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

vec3 point_on_unit_sphere(float theta, float phi, float roll) {
    float x = sin(phi) * cos(theta);
    float y = sin(phi) * sin(theta);
    float z = cos(phi);
    vec3 p = vec3(x, y, z);

    float c = cos(roll);
    float s = sin(roll);
    vec3 k = normalize(p); // axis of rotation (the point itself)
    mat3 K = mat3(
        0.0, -k.z, k.y,
        k.z, 0.0, -k.x,
        -k.y, k.x, 0.0
    );
    mat3 R = mat3(1.0) * c + (1.0 - c) * outerProduct(k, k) + K * s;
    return R * p;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#ifdef PIXEL

#define STATE_NONE -1
#define STATE_BEATEN 0
#define STATE_PERFECT 1

uniform float state;
uniform vec4 color;
uniform float elapsed;

vec4 effect(vec4 vertex_color, Image img, vec2 texture_coords, vec2 vertex_position) {

    if (state == STATE_NONE) {
        float dist = distance(texture_coords, vec2(0.5));
        float shadow = (1 - gaussian(dist, 0.8));
        return color - shadow * 0.3;
    }
    else {
        vec3 origin = point_on_unit_sphere(
            radians(45),
            radians(-45 / 2),
            radians(-45 / 2)
        );

        float dist = distance(texture_coords, (origin.xy + vec2(1)) / vec2(2));

        if (state == STATE_PERFECT) {
            dist /= 1.5;
            vec3 color = lch_to_rgb(vec3(0.8, 1.0, fract(dist - elapsed * 0.3)));
            float shadow = 1 - gaussian(dist, 0.5);
            return vec4(color - shadow * 1, 1);
        }
        else if (state == STATE_BEATEN) {
            float highlight = gaussian(dist, 2);
            float shadow = 1 - gaussian(dist, 0.6);

            return color + highlight * 0.5 - shadow * 0.2;
        }

        discard;
    }
}

#endif