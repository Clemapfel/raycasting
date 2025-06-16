#ifdef VERTEX

layout(location = 3) in vec4 position_velocity_buffer;
layout(location = 4) in vec3 color_buffer;
layout(location = 5) in vec4 velocity_magnitude_scale_scale_direction_scale_speed;

varying vec4 color;
varying float fraction;
uniform float min_scale;
uniform float max_scale;

uniform float radius;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    color = vec4(color_buffer.rgb, 1);
    const vec2 center = vec2(0);
    float scale = velocity_magnitude_scale_scale_direction_scale_speed.y;
    vertex_position.xy = center + normalize(vertex_position.xy - center) * scale * radius;
    vertex_position.xy += position_velocity_buffer.xy;

    fraction = (scale - min_scale) / (max_scale - min_scale);
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

varying vec4 color;
varying float fraction;

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 texel = texture(img, texture_coordinates);
    return texel * mix(vec4(1), color, min(3 * fraction, 1)) * vertex_color;
}
#endif