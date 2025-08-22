#define PI 3.1415926535897932384626433832795
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

    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );
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

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

#define MODE_FRAME 0
#define MODE_MASK 1

#ifndef MODE
#error "In overworld/result_screen.glsl: `MODE` unset, should be 0 or 1"
#endif

#ifdef PIXEL

uniform float elapsed;

#if MODE == MODE_FRAME


#endif

uniform vec4 black;

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 vertex_position) {

    float mask = 1 - smoothstep(0, 0.4, texture_coords.y);

    #if MODE == MODE_MASK

    return black * mask;

    #elif MODE == MODE_FRAME

    vec2 uv = texture_coords.xy;

    const float noise_scale = 20;
    float time = elapsed / 20;
    float inner_noise = gradient_noise(noise_scale * vec3(vec2(symmetric(uv.x)), time));
    float outer_noise = gradient_noise(noise_scale * vec3(vec2(symmetric(uv.x)), 10 + time));

    const float noise_strength = 0.5;
    uv.y += noise_strength * 0.25 * mix(inner_noise, outer_noise, texture_coords.y);

    const float frame_thickness = 0.2;
    float inner = smoothstep(0.05, 0.2, 1 - 1.5 * symmetric(uv.y));
    float outer = smoothstep(0.05, 0.2, 1 - 1.15 * symmetric(uv.y));

    vec4 foreground = vec4(lch_to_rgb(vec3(0.8, 1, 2 * uv.x + elapsed / 4)), 1);

    float alpha = max(inner, outer);

    // mask away lower alpha artifacts in inner region
    float inner_mask = 1 - smoothstep(0, 0.08, texture_coords.y);
    alpha -= inner_mask;

    return vec4(mix(black, foreground, 1 - inner).rgb, alpha);
    #endif
}

#endif