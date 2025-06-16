#ifdef VERTEX

layout(location = 3) in vec4 position_velocity_buffer;
layout(location = 4) in vec3 color_buffer;
layout(location = 5) in vec2 magnitude_radius_buffer;

varying vec4 color;
uniform vec2 center;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    color = vec4(color_buffer.rgb, 1);
    float radius = magnitude_radius_buffer.y;
    vertex_position.xy = center + normalize(vertex_position.xy - center) * radius;
    vertex_position.xy += position_velocity_buffer.xy;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

varying vec4 color;

vec4 effect(vec4 vertex_color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 texel = texture(img, texture_coordinates);
    return texel * color * vertex_color;
}
#endif