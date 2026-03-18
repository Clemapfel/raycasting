#ifdef PIXEL

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

uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture3D(lch_texture, lch).rgb;
}

uniform float fraction;
uniform vec2 size;
uniform float hue;

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {

    float distortion_ramp = 2;
    float fade_out = gaussian(texture_coords.x, 1);
    float boost = gaussian(texture_coords.x, 8) * 0.5;
    vec2 uv = texture_coords * size / max(size.x, size.y);

    float distortion_strength = 0.05;
    float distortion_scale = 20;
    float distortion_speed = 1 / 2.0;

    vec2 distortion = vec2(
        gradient_noise(vec3(texture_coords * distortion_scale, distortion_speed)),
        gradient_noise(vec3(texture_coords * distortion_scale, distortion_speed))
    ) * distortion_strength;

    uv += distortion;

    vec2 pxy = vec2(0.5) * size / max(size.x, size.y);

    float f = fraction;

    float sigma = 4;
    float outer_fraction = mix(-0.05, 1 - 0.05, f) * 0.5;
    float inner_fraction = mix(-0.02, 1 - 0.02, f) * 0.5;

    float outer = gaussian(distance(pxy, uv) - outer_fraction, sigma);
    outer *= (1 - fraction) * (1 - fraction);

    float inner = gaussian(distance(pxy, uv) - inner_fraction, sigma * 12);
    inner *= (1 - fraction) * (1 - fraction);

    float ball = gaussian(distance(pxy, uv), sigma * 4) * (1 - fraction);
    ball += gaussian(distance(texture_coords, vec2(0.5)), 2.5) * 0.4;

    const float eps = 0.5;
    float value = smoothstep(0.5 - eps, 0.5 + eps, (outer + inner + ball));

    vec2 delta = uv - pxy;
    float angle = (atan(delta.y, delta.x) + PI) / (2.0 * PI);
    float dist = distance(pxy, uv);


    float hue = mix(hue, hue + 0.1, fraction);
    vec3 outer_rgb = lch_to_rgb(vec3(mix(0.8, 0.9, inner), 1, hue));
    vec3 inner_rgb = color.rgb;

    return vec4(value) * vec4(mix(outer_rgb, inner_rgb, ball), 1);
}

#endif