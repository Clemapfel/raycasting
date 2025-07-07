#ifdef VERTEX

layout(location = 3) in vec2 offset;
layout(location = 4) in vec3 color;
layout(location = 5) in float radius;
layout(location = 6) in vec2 scale;
layout(location = 7) in float rotation;

varying vec4 vertex_color;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vertex_color = vec4(color.rgb, 1);

    vec2 center = vec2(0);
    vec2 dxy = normalize(vertex_position.xy - center);

    vec2 pos = center + offset + dxy * radius * scale;


    pos -= (center + offset);
    float cos_theta = cos(rotation);
    float sin_theta = sin(rotation);
    pos *= mat2(cos_theta, -sin_theta, sin_theta, cos_theta);
    pos += (center + offset);

    vertex_position.xy = pos;

    return transform_projection * vertex_position;
}

#endif // VERTEX

#ifdef PIXEL

varying vec4 vertex_color;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coordinates, vec2 frag_position) {
    vec4 texel = texture(img, texture_coordinates);
    return color * vertex_color * texel;
}

#endif // PIXEL