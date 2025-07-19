#define MODE_INNER 0
#define MODE_OUTER 1

#ifndef MODE
#error "MODE not set, should be 0 or 1"
#endif

// Triangle wave function centered at zero
float triangle(float x) {
    return 2.0 * abs(fract(x) - 0.5) - 1.0;
}

// Noise function using summed triangle waves
float triangle_noise(float x, int octaves, float persistence) {
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float maxAmp = 0.0;

    for (int i = 0; i < octaves; ++i) {
        sum += amp * triangle(x * freq);
        maxAmp += amp;
        freq *= 2.0;
        amp *= persistence;
    }

    // Normalize to [-1, 1]
    return sum / maxAmp;
}

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

uniform float elapsed;

#if MODE == MODE_INNER

vec4 effect(vec4 color, sampler2D img, vec2 _, vec2 frag_position) {

    return color;
}

#elif MODE == MODE_OUTER

vec4 effect(vec4 color, sampler2D img, vec2 _, vec2 frag_position) {
    return color;
}

#endif // MODE
