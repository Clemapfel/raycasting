#ifdef PIXEL

uniform sampler3D noise_texture;
float gradient_noise(vec3 xyz) {
    return texture(noise_texture, xyz).r;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float specular_shape(float x) {
    return gaussian(1 - x, 5);
}

uniform vec4 highlight_color;
uniform vec4 shading_color;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;
    vec3 normal = normalize(vec3(uv.x, uv.y, sqrt(max(0.0, 1.0 - dot(uv, uv)))));

    const vec3 specular_direction = normalize(vec3(-1.0, -1.0, 2.0));
    const vec3 diffuse_direction = specular_direction; //normalize(vec3(1.0, 1.0, 2.0));

    float specular = specular_shape(max(0.0, dot(normal, specular_direction)));
    float diffuse = max(0.0, dot(normal, diffuse_direction));

    return highlight_color * specular + shading_color * diffuse;
}

#endif