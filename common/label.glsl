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

#define MODE_DRAW_OUTLINE 0
#define MODE_DRAW_TEXT 1

#ifndef MODE
#error "In label.glsl: expected MODE to be either 0 or 1"
#endif

const float rainbow_width = 150.0;
const float shake_speed = 10.0; // steps per second
const float wave_period = 10.0;
const float wave_offset = 5.0;
const float wave_speed = 4.0;
const float anti_aliasing = 0.1; // [0, 1], where 0: maximum sharpness

uniform int n_visible_characters;
uniform bool is_effect_wave;
uniform bool is_effect_shake;
uniform float font_size;
uniform float elapsed;
uniform float opacity = 1;

#if MODE == MODE_DRAW_OUTLINE
    uniform vec4 outline_color;
#elif MODE == MODE_DRAW_TEXT
    uniform bool is_effect_rainbow;
#endif

#ifdef VERTEX

#define PI 3.1415926535897932384626433832795

flat varying int letter_index;

vec4 position(mat4 transform, vec4 vertex_position) {
    letter_index = gl_VertexID / 4;

    vec2 position = vertex_position.xy;
    if (is_effect_shake) {
        float i_offset = round(elapsed * shake_speed);
        float magnitude = max(font_size / 50, 1.0); // shake magnitude as function of font_size
        position += noise(position * vec2(i_offset)) * magnitude;
    }

    if (is_effect_wave) {
        float x = ((elapsed * wave_speed) + float(letter_index));
        position.y += sin((x * 2.0 * PI) / wave_period) * wave_offset;
    }

    vertex_position.xy = position;
    return transform * vertex_position;
}

#endif

#ifdef PIXEL

flat varying int letter_index;

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    if (letter_index >= n_visible_characters)
        discard;

    #if MODE == MODE_DRAW_OUTLINE
        // outline uses sdf font texture
        float dist = Texel(image, texture_coords).a;
        float outline = smoothstep(0.0, 0.02, pow(dist, 5));
        return outline * outline_color * opacity;

    #elif MODE == MODE_DRAW_TEXT
        // foreground uses regular font texture
        vec4 rainbow = vec4(1.0);
        if (is_effect_rainbow) {
            float time = elapsed * 0.3;
            rainbow.rgb = lch_to_rgb(vec3(0.8, 1.0, fract(vertex_position.x / rainbow_width - time)));
        }

        return rainbow * color * Texel(image, texture_coords) * opacity;
    #endif
}

#endif