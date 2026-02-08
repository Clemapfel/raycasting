#ifdef PIXEL

uniform float threshold = 0.4;
uniform float smoothness = 0.0;
uniform float outline_thickness = 2.0;

float finalize(float x) {
    return smoothstep(
        threshold - smoothness,
        threshold + smoothness,
        x
    );
}

uniform vec4 outline_color = vec4(1);

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 screen_coords)
{
    return color * vec4(finalize(texture(tex, texture_coordinates).r));
}

#endif