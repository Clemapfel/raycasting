#define PI 3.1415926535897932384626433832795
vec3 random_3d(in vec3 p) {
    return fract(sin(vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))
    ) * 43758.5453123);
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 v = fract(p);

    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

#ifdef PIXEL

uniform float value; // 1 fully opaque, 0 fully transparent
uniform float direction; // +1 going from transparent to opaque, -1 otherwise
vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 vertex_position) {
    //if (direction > 0) return vec4(color.rgb, color.a * value); // trivial fade during attack phase

    vec2 screen_size = love_ScreenSize.xy;

    const int n_octaves = 3;
    float noise_scale = 10;
    vec2 pos = texture_coords;

    float step_size = 0.5;
    for (int i = 0; i < n_octaves; ++i) {
        float dist = distance(pos.xy, texture_coords.xy);

        vec2 seed = texture_coords.xy * noise_scale;
        vec2 offset = vec2(
            gradient_noise(vec3(seed.x, dist, seed.y)),
            gradient_noise(vec3(dist, seed.y, seed.x))
        );

        pos.xy = pos.xy + offset * step_size;

        step_size = step_size * 0.5;
        noise_scale = noise_scale * 1;
    }

    float noise = distance(pos.x, texture_coords.x);
    float eps = 0.02;
    float opacity = 1 - smoothstep(value - eps, value + eps, clamp(1 - (texture_coords.y / 1.6 + noise), 0, 1));
    return vec4(color.rgb, color.a * opacity);
}

#endif