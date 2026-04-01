uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

vec2 offset_uv(vec2 base_coords, vec2 offset, vec2 texel_size) {
    return clamp(base_coords + texel_size * offset, vec2(0.0 + 2 * texel_size), vec2(1.0 - 2 * texel_size));
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#ifdef PIXEL

#define MODE_NO_SDF 0
#define MODE_SDF 1
#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

uniform float opacity = 1;

#if MODE == MODE_SDF

uniform vec4 white;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {
    float dist = texture(img, texture_coords).a;
    const float thickness = 1 - 0.8;
    vec4 result = min(vec4(1.5 * smoothstep(0, 1, smoothstep(0, 1, smoothstep(0, 1 - thickness, dist)))) * white, vec4(1));
    return vec4(result.rgb, result.a * opacity);
}

#elif MODE == MODE_NO_SDF

uniform bool use_rainbow;
uniform bool use_highlight;
uniform float elapsed;
uniform float fraction;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 vertex_position) {
    vec4 texel = texture(img, texture_coords);
    vec2 uv = texture_coords;
    uv = rotate(uv, 1.75 * PI);
    float time = elapsed * 0.3;

    vec4 result;
    if (use_rainbow) {
        vec3 color = lch_to_rgb(vec3(0.8, 1.0, fract(10 * uv.x - time)));
        result = vec4(color, texel.a);
    }
    else {
        result = texel * color;
    }

    if (use_highlight) {
        float sin1 = (sin(100 * uv.x - elapsed) + 1) / 2;
        float sin2 = (sin(180 * uv.x - elapsed + 0.5 * PI) + 1) / 2;
        result.rgb += mix(sin1, sin2, 0.5) * 0.3;
    }

    const float line_width = 0.05;
    // Sweep from below 0 to above 1
    float center = mix(-line_width, 1.0 + line_width, fraction);
    float dist = abs(uv.y - center);
    float line_alpha = smoothstep(line_width, 0.0, dist);
    result.rgb = mix(result.rgb, vec3(1.0), line_alpha);

    // black inside outline
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

    vec2 texel_size = vec2(1.0) / textureSize(img, 0);
    float s00 = Texel(img, offset_uv(texture_coords, vec2(-1, -1), texel_size)).a;
    float s01 = Texel(img, offset_uv(texture_coords, vec2( 0, -1), texel_size)).a;
    float s02 = Texel(img, offset_uv(texture_coords, vec2( 1, -1), texel_size)).a;
    float s10 = Texel(img, offset_uv(texture_coords, vec2(-1,  0), texel_size)).a;
    float s11 = Texel(img, offset_uv(texture_coords, vec2( 0,  0), texel_size)).a;
    float s12 = Texel(img, offset_uv(texture_coords, vec2( 1,  0), texel_size)).a;
    float s20 = Texel(img, offset_uv(texture_coords, vec2(-1,  1), texel_size)).a;
    float s21 = Texel(img, offset_uv(texture_coords, vec2( 0,  1), texel_size)).a;
    float s22 = Texel(img, offset_uv(texture_coords, vec2( 1,  1), texel_size)).a;

    float gx = sobel_x[0][0] * s00 + sobel_x[0][1] * s01 + sobel_x[0][2] * s02 +
    sobel_x[1][0] * s10 + sobel_x[1][1] * s11 + sobel_x[1][2] * s12 +
    sobel_x[2][0] * s20 + sobel_x[2][1] * s21 + sobel_x[2][2] * s22;

    float gy = sobel_y[0][0] * s00 + sobel_y[0][1] * s01 + sobel_y[0][2] * s02 +
    sobel_y[1][0] * s10 + sobel_y[1][1] * s11 + sobel_y[1][2] * s12 +
    sobel_y[2][0] * s20 + sobel_y[2][1] * s21 + sobel_y[2][2] * s22;

    result.rgb -= vec3(0.333 * length(vec2(gx, gy)));
    result.a *= opacity;
    return result;
}

#endif

#endif