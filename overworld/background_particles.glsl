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

uniform vec3 light_direction = vec3(0.2, -1.0, 0.0);
uniform float ambient_strength = 0.35;
uniform float shadow_falloff = 1;

#ifndef IS_BLOOM
#error "IS_BLOOM undefined, should be 0 or 1"
#endif

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {

    float edge = gaussian(length(texture_coords), 2.5);
    float edge_threshold = 0.5;
    float edge_eps = 0.2;
    edge = smoothstep(edge_threshold - edge_eps, edge_threshold + edge_eps, edge);

    const float intensity = 0.4;

    #if IS_BLOOM == 1
        vec4 result = color * vertex_color * texture(tex, texture_coords);
        return result;
    #else
        vec3 normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
        vec3 light_dir = normalize(-light_direction);

        float diffuse_dot = max(dot(normal, light_dir), 0.0);
        float diffuse = pow(diffuse_dot, shadow_falloff);
        float front_light = 0.6 * min(ambient_strength + diffuse, 1.0);
        return color * vec4(intensity * (edge + front_light) * vertex_color.rgb, 1);
    #endif
}

#endif
