#ifdef VERTEX

layout(location = 3) in vec4 position_velocity;
layout(location = 4) in vec4 color_magnitude;

varying vec4 color;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    color = vec4(color_magnitude.rgb, 1);
    vertex_position.xy += position_velocity.xy;
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