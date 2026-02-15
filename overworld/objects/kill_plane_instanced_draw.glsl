#define TRUE 1u
#define FALSE 0u

#ifdef VERTEX

layout (location = 3) in vec2 particle_position;
layout (location = 4) in float particle_radius;
layout (location = 5) in vec4 particle_rotation;
layout (location = 6) in uint is_outline;

uniform vec2 player_position;

vec3 rotate_by_quaternion(vec3 vertex, vec4 quaternion)
{
    vec3 t = 2.0 * cross(quaternion.xyz, vertex);
    return vertex + quaternion.w * t + cross(quaternion.xyz, t);
}

uniform float outline_thickness = 1;

out float opacity;
flat out uint use_color_override;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vec3 rotated = rotate_by_quaternion(vertex_position.xyz, normalize(particle_rotation));
    float scale = particle_radius;

    use_color_override = is_outline;

    if (is_outline == TRUE)
        scale = scale + outline_thickness;

    vec2 offset = particle_position;
    vertex_position.xy = rotated.xy * scale + offset;
    vertex_position.z = rotated.z;
    opacity = (rotated.z + 1) / 2;

    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

flat in uint use_color_override;
in float opacity;

uniform vec4 outline_color = vec4(1, 1, 1, 1);
uniform vec4 black = vec4(0, 0, 0, 1);

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    if (use_color_override == TRUE)
        return vec4(outline_color.rgba);
    else
        return vec4(vec4(vec3(mix(0, 1.5, opacity)), 1) * color);
}

#endif