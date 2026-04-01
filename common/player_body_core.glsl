uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}

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

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

uniform float elapsed;
uniform float hue;
uniform float saturation = 1;

vec4 effect(vec4 color, sampler2D image, vec2 texture_coordinates, vec2 _) {
    vec4 texel = texture(image, texture_coordinates);
    vec2 uv = texture_coordinates - vec2(1);

    float time = elapsed / 2.0;
    float scale = 3.0;
    float n_octaves = 2.0;
    vec2 step = vec2(0, 1);
    float persistence = 1.0;

    for (int i = 0; i < int(n_octaves); ++i) {
        uv = uv + step * gradient_noise(vec3(uv * persistence * scale, time));
        step = rotate(step, (n_octaves - float(i)) * 2.0 * PI);
        persistence *= distance(uv, texture_coordinates) * 0.4;
    }

    float hue_eps = 0.05;
    float noise = gradient_noise(vec3(uv * distance(uv, texture_coordinates), 0.0));

    float chroma = 1;
    float lightness = mix(0.4, 1, (noise + 1) / 2);
    float hue_adj = fract(hue + mix(-hue_eps, +hue_eps, noise)); // intentional overflow of mixed, noise in -1, 1

    vec3 rgb = lch_to_rgb(vec3(lightness, chroma * saturation, fract(hue_adj)));
    return color * vec4(rgb, texel.a * color.a);
}
