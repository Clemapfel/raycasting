#ifdef PIXEL

uniform float threshold;
uniform float smoothness;

float finalize(float x) {
    return smoothstep(
    max(0.0, threshold - smoothness),
    min(1.0, threshold + smoothness),
    x
    );
}

uniform vec4 body_color;
uniform vec4 outline_color;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 screen_coords)
{
    return vec4(finalize(texture(tex, texture_coordinates).r));
}

#endif