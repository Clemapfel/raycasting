#ifdef VERTEX

// sic, locations start at 3
layout (location = 3) in vec3 offset;
layout (location = 4) in float scale;
layout (location = 5) in vec4 rotation; // quaternion, normalized
layout (location = 6) in vec4 color;

vec3 rotate(vec3 vector, vec4 quaternion)
{
    vec3 u = quaternion.xyz;
    float s = quaternion.w;

    vec3 uv = cross(u, vector);
    vec3 uuv = cross(u, uv);
    return vector + 2.0 * (s * uv + uuv);
}

varying vec3 world_position;
varying vec4 vertex_color;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vec3 dxyz = vertex_position.xyz;

    dxyz *= scale;
    dxyz = rotate(dxyz, rotation);
    dxyz += offset;

    world_position = dxyz;
    vertex_color = color;

    return transform_projection * vec4(dxyz, vertex_position.w);
}

#endif

#ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

varying vec3 world_position;
varying vec4 vertex_color;

uniform vec3 light_direction = vec3(0.2, -1, 0);
uniform float ambient_strength = 0.35;
uniform float point_light_intensity = 0.2;
uniform float shadow_falloff = 1;

#ifndef MAX_N_POINT_LIGHTS
#define MAX_N_POINT_LIGHTS 32
#endif

uniform vec3 camera_offset;
uniform vec3 point_lights[MAX_N_POINT_LIGHTS];
uniform int n_point_lights;

const vec3 light_position = vec3(0, 0, 150);

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec3 normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
    vec3 light_dir = normalize(-light_direction);

    float diffuse_dot = max(dot(normal, light_dir), 0.0);
    float diffuse = pow(diffuse_dot, shadow_falloff);

    float front_light = min(ambient_strength + diffuse, 1.0);

    vec3 light_direction = light_position - camera_offset;
    vec3 frag_pos = world_position - camera_offset;

    float dist = distance(light_direction, frag_pos);
    float attenuation = gaussian(dist, 1.0 / 500.0);

    vec3 to_light = normalize(light_direction - frag_pos);
    float alignment = max(dot(-normal, to_light), 0.0);

    float point_light = point_light_intensity * alignment * attenuation;

    vec4 texel = texture(tex, texture_coords);
    texel.xyz = vec3(max(max(texel.x, texel.y), max(texel.y, texel.z)));

    return vec4((mix(front_light, front_light + point_light, 0.6)) * color.rgb * vertex_color.rgb, 1);
}

#endif