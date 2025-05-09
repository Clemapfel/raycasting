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

#ifdef PIXEL

uniform float elapsed;

uniform vec2 camera_offset;
uniform float camera_scale = 1;
vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float gaussian_2d(vec2 pos, float sigma) {
    float coeff = 1.0 / (2.0 * 3.14159265 * sigma * sigma);
    float exponent = -dot(pos, pos) / (2.0 * sigma * sigma);
    return coeff * exp(exponent);
}

vec2 derivative_of_gaussian_2d(vec2 pos, float sigma) {
    // ∇G = (-x/σ², -y/σ²) * G(x, y)
    float g = gaussian_2d(pos, sigma);
    return -pos / (sigma * sigma) * g;
}

float project(float value, float a, float b) {
    return clamp(a + (b - a) * value, a, b);
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

uniform vec4 color = vec4(1, 1, 1, 1);
uniform vec2 player_position;
uniform float player_radius;
uniform vec2 size;

vec4 effect(vec4 vertex_color, Image image, vec2 texture_position, vec2 frag_position) {
    vec2 uv = to_uv(frag_position);
    float time = elapsed / 2;

    vec2 normalization = vec2(size.x / size.y, 1);
    float player_weight = (distance(
    player_position * normalization,
    texture_position * normalization
    ));
    vec2 player_offset = vec2(dFdx(player_weight), dFdy(player_weight)) * 10;

    uv.x -= elapsed / 50;

    float distortion_ramp = 2;

    float fade_out = gaussian(texture_position.x, 1);
    float boost = gaussian(texture_position.x, 8) * 0.5;

    float distortion_strength = 0.14;
    float distortion_scale = 20;
    float distortion_speed = 1 / 2.0;
    vec2 distortion = vec2(
    gradient_noise(vec3(uv * distortion_scale, elapsed * distortion_speed)),
    gradient_noise(vec3(uv * distortion_scale, elapsed * distortion_speed))
    ) * distortion_strength;

    uv += distortion;

    const float eps = 0.2;
    float balls = (gaussian((gradient_noise(vec3(uv * 10, 1)) + 1) / 2, 0.7) + boost) * fade_out;

    return vec4(min(balls, 1)) * color;
}

#endif