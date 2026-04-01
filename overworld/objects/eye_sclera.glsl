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

#define MODE_HIGHLIGHT 0
#define MODE_SHADING 1

#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

uniform vec4 color;

#if MODE == MODE_HIGHLIGHT
uniform vec3 direction = vec3(-1.0, -1.0, 2.0);
#elif MODE == MODE_SHADING
uniform vec3 direction = vec3(-1.0, -1.0, 2.0);

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

#endif

uniform float elapsed = 0;

vec4 effect(vec4 vertex_color, sampler2D image, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = texture_coords;

    float noise = 0;
    #if MODE == MODE_SHADING
        noise = gradient_noise(vec3(4 * to_world_position(vertex_position) / love_ScreenSize.xy, elapsed / 8));
    #endif

    vec3 normal = normalize(vec3(uv.x, uv.y, sqrt(max(0.0, 1.0 - dot(uv - noise, uv + noise)))));
    float value = 0;

    #if MODE == MODE_HIGHLIGHT

        value = specular_shape(max(0.0, dot(normal, normalize(direction))));

    #elif MODE == MODE_SHADING

        value = max(0.0, dot(normal, normalize(direction)));

    #endif

    return color * value;
}

#endif