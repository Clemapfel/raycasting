

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

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

/*
#ifdef VERTEX

uniform float elapsed;
uniform float n_vertices;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    const float magnitude = 2.0;
    vec2 scale = 1.0 / love_ScreenSize.xy * 10.0;
    float fraction = float(gl_VertexID) / n_vertices;

    vec2 pos = vertex_position.xy;
    vec2 offset = vec2(
        gradient_noise(vec3(pos.xy * scale, elapsed)),
        gradient_noise(vec3(pos.yx * scale, elapsed))
    );

    vertex_position.xy += offset * magnitude;
    return transform_projection * vertex_position;
}

#endif
*/

#ifdef PIXEL

uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform float elapsed;
uniform float hue;

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
vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

#define MODE_BASE 0
#define MODE_OUTLINE 1

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_uv(vertex_position);
    uv += elapsed / 20;
    uv = rotate(uv, -0.25 * PI);
    uv *= 2;
    float noise = gradient_noise(vec3(vec2(4, 1) * uv, 0));

    #if MODE == MODE_BASE
        const float hue_offset = 0.1;
        return vec4(lch_to_rgb(vec3(0.8, 1, fract(mix(hue - hue_offset, hue + hue_offset, (noise + 1) / 2)))), 0.4 * (noise + 1) / 2);
    #elif MODE == MODE_OUTLINE
        const float hue_offset = 0.4;
        return vec4(lch_to_rgb(vec3(0.8, 1, fract(mix(hue - hue_offset, hue + hue_offset, (noise + 1) / 2)))), 1);
    #endif
}

#endif

