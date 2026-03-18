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

uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture3D(lch_texture, lch).rgb;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

#ifdef PIXEL

uniform float elapsed;
uniform float hue;
uniform float opacity;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    const float ray_step = 0.2;
    const int n_steps = 7;
    const float density_multiplier = 0.2;

    // uv.x: 0 to 1 left to right, uv.y: rim density weight

    float weight = 1 - 0.6 * distance(screen_coords.xy, love_ScreenSize.xy * 0.5) / (min(love_ScreenSize.x, love_ScreenSize.y) * 0.5);
    weight = 1 - weight * 10 * 0.5;
    weight *= texture_coords.y;
    if (weight < 0.01) discard;

    float angle_direction = 0.1;

    float t = texture_coords.x * 2.0 - 1.0;
    vec2 time_direction = normalize(texture_coords.x > 0.5 ? vec2(angle_direction, 1.0) : vec2(-angle_direction, 1.0));
    screen_coords.xy += time_direction * elapsed * 250;

    vec3 ray_position = vec3(screen_coords * 0.01, 0);
    vec3 ray_direction = vec3(0, 0, 1);

    float final_density = 0;
    float accumulated_alpha = 0;


    for (int i = 0; i < n_steps; ++i) {
        float offset = ray_step * float(i);
        float hue = fract(float(i) / float(n_steps) + elapsed);

        vec3 sample_pos = ray_position + ray_direction * offset;
        float density = density_multiplier * (1 + gradient_noise(sample_pos)) / 2;
        density *= weight;

        float alpha = density * (1.0 - accumulated_alpha);
        accumulated_alpha += alpha;
    }

    return vec4(lch_to_rgb(vec3(0.8, 1, hue)), accumulated_alpha * opacity);
}

#endif