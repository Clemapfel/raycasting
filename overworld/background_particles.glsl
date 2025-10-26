#ifdef VERTEX

// sic, locations start at 3
layout (location = 3) in vec3 offset;
layout (location = 4) in float scale;
layout (location = 5) in vec4 rotation; // quaternion, normalized

vec3 rotate(vec3 vector, vec4 quaternion)
{
    vec3 u = quaternion.xyz;
    float s = quaternion.w;

    vec3 uv = cross(u, vector);
    vec3 uuv = cross(u, uv);
    return vector + 2.0 * (s * uv + uuv);
}

varying vec3 world_position;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vec3 dxyz = vertex_position.xyz; // local position (around origin)

    dxyz *= scale;
    dxyz = rotate(dxyz, rotation);
    dxyz += offset;

    world_position = dxyz;
    return transform_projection * vec4(dxyz, vertex_position.w);
}

#endif

#ifdef PIXEL

varying vec3 world_position;
varying vec3 world_normal;

uniform vec3 light_direction = vec3(0.2, -0.7, -0.5); // Direction TO the light
uniform vec3 light_color = vec3(1.0, 0.95, 0.9);
uniform vec3 ambient_color = vec3(0.3, 0.35, 0.4);
uniform float ambient_strength = 0.2;
uniform vec3 base_color = vec3(0.8, 0.8, 0.8);

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec3 normal = normalize(cross(dFdx(world_position), dFdy(world_position)));


    vec3 light_dir = normalize(-light_direction);

    // Lambertian diffuse lighting
    float diffuse_factor = max(dot(normal, light_dir), 0.0);

    // Ambient lighting
    vec3 ambient = ambient_strength * ambient_color;

    // Diffuse lighting
    vec3 diffuse = diffuse_factor * light_color;

    // Combine lighting
    vec3 lighting = ambient + diffuse;

    // Apply lighting to base color
    vec3 final_color = base_color * lighting * color.rgb;

    return vec4(final_color, color.a);
}

#endif