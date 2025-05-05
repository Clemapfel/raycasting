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

float gaussian2d(vec2 xy, float ramp)
{
    float r2 = dot(xy, xy); // x^2 + y^2
    return exp(((-4.0 * PI) / 3.0) * (ramp * r2));
}

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

uniform float elapsed;
uniform vec2 player_position;
uniform float player_radius;
uniform vec2 size;
uniform float spawn_fraction;
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

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position) {

    vec2 uv = to_uv(vertex_position);
    vec2 center = to_uv(vec2(0.5));

    float noise = gradient_noise(vec3(uv * 4, elapsed));
    //texture_coords.x += noise * 0.5;

    // If size is not (1,1), normalize to square
    vec2 norm_player_pos = player_position * size / max(size.x, size.y);
    vec2 norm_tex_coords = texture_coords * size / max(size.x, size.y);

    float player_weight = distance(norm_player_pos, norm_tex_coords);
    const float ray_eps = 0.25;
    const float ball_eps = 0.95;

    float ray = gaussian(abs(texture_coords.x - 0.5), 10);
    float player_ball = gaussian(distance(norm_player_pos, norm_tex_coords), 20);
    player_ball *= smoothstep(0.5 - ball_eps, 0.5 + ball_eps, gaussian(abs(texture_coords.x - 0.5) * 2, 1) * spawn_fraction);
    float value = smoothstep(0.5 - ray_eps, 0.5 + ray_eps, ray + player_ball);
    return vec4(value) * vec4(color.rgb * 0.6, color.a);
}

#endif