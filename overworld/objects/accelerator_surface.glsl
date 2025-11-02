#ifdef PIXEL

#define MODE_BODY 0
#define MODE_OUTLINE 1
#define MODE_PARTICLE 2

#ifndef MODE
#error "Mode undefined"
#endif

uniform float elapsed;
uniform vec2 player_position;

uniform mat4x4 screen_to_world_transform;

vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
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

vec3 random3(vec3 st)
{
    st = vec3( dot(st, vec3(127.1, 311.7, 74.7)),
    dot(st, vec3(269.5, 183.3, 246.1)),
    dot(st, vec3(113.5, 271.9, 124.6)) );
    return fract(sin(st) * 43758.5453123);
}

float height_pattern(vec3 uv, out vec3 gradient)
{
    gradient = vec3(0.0);
    float result = 0.0;

    float frequencies[3] = float[3](1.0, 2.0, 4.0);
    float weights[3] = float[3](1.0, -0.06, 0.03);

    for (int octave = 0; octave < 3; octave++)
    {
        vec3 scaled_uv = frequencies[octave] * uv;
        vec3 cell_idx = floor(scaled_uv);
        vec3 cell_uvw = fract(scaled_uv);

        float min_dist_sq = 1.0;
        float second_min_dist_sq = 1.0;
        vec3 closest_shift = vec3(0.0);
        vec3 second_shift = vec3(0.0);

        // Unrolled inner loop for better performance
        for (int i = -1; i <= 1; i++)
        {
            for (int j = -1; j <= 1; j++)
            {
                vec3 neighbor_base = cell_idx + vec3(i, j, 0.0);

                // k = -1
                vec3 neighbor_point = random3(neighbor_base - vec3(0.0, 0.0, 1.0));
                vec3 shift = neighbor_point + vec3(i, j, -1.0) - cell_uvw;
                float dist_sq = dot(shift, shift);

                if (dist_sq < min_dist_sq)
                {
                    second_min_dist_sq = min_dist_sq;
                    second_shift = closest_shift;
                    min_dist_sq = dist_sq;
                    closest_shift = shift;
                }
                else if (dist_sq < second_min_dist_sq)
                {
                    second_min_dist_sq = dist_sq;
                    second_shift = shift;
                }

                // k = 0
                neighbor_point = random3(neighbor_base);
                shift = neighbor_point + vec3(i, j, 0.0) - cell_uvw;
                dist_sq = dot(shift, shift);

                if (dist_sq < min_dist_sq)
                {
                    second_min_dist_sq = min_dist_sq;
                    second_shift = closest_shift;
                    min_dist_sq = dist_sq;
                    closest_shift = shift;
                }
                else if (dist_sq < second_min_dist_sq)
                {
                    second_min_dist_sq = dist_sq;
                    second_shift = shift;
                }

                // k = 1
                neighbor_point = random3(neighbor_base + vec3(0.0, 0.0, 1.0));
                shift = neighbor_point + vec3(i, j, 1.0) - cell_uvw;
                dist_sq = dot(shift, shift);

                if (dist_sq < min_dist_sq)
                {
                    second_min_dist_sq = min_dist_sq;
                    second_shift = closest_shift;
                    min_dist_sq = dist_sq;
                    closest_shift = shift;
                }
                else if (dist_sq < second_min_dist_sq)
                {
                    second_min_dist_sq = dist_sq;
                    second_shift = shift;
                }
            }
        }

        float inv_d1 = inversesqrt(min_dist_sq);
        float inv_d2 = inversesqrt(second_min_dist_sq);

        vec3 grad = second_shift * inv_d2 - closest_shift * inv_d1;
        float weight_freq = weights[octave] * frequencies[octave];

        result += weights[octave] * (second_min_dist_sq - min_dist_sq);
        gradient += weight_freq * grad;
    }

    return result;
}

const float noise_scale = 1. / 75;
const float time_scale = 1. / 2;

#if MODE == MODE_BODY

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_pos = to_world_position(screen_coords);

    vec3 gradient;
    float noise = height_pattern(vec3(world_pos / 20, elapsed / 20), gradient);
    gradient = normalize(gradient);

    const vec3 light_direction = vec3(0.2, -1.0, 0.0);
    const float ambient_strength = 0.35;
    const float shadow_falloff = 1;

    vec3 normal = normalize(vec3(-gradient.x, -gradient.y, 0));
    vec3 light_dir = normalize(-light_direction);

    float diffuse_dot = max(dot(normal, light_dir), 0.0);
    float diffuse = pow(diffuse_dot, shadow_falloff);
    float light = min(ambient_strength + diffuse, 1.0);

    vec3 rgb = lch_to_rgb(vec3(0.8, 1, gradient_noise(vec3(world_pos * noise_scale, elapsed * time_scale))));

    return vec4(vec3(light) * rgb, 1);
}

#elif MODE == MODE_OUTLINE

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_pos = to_world_position(screen_coords);
    return texture(tex, texture_coords) * vec4(
        lch_to_rgb(vec3(0.8, 1, gradient_noise(vec3(world_pos * noise_scale, elapsed * time_scale)))),
        1
    );
}

#elif MODE == MODE_PARTICLE

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 world_pos = to_world_position(screen_coords);

    return texture(tex, texture_coords) * vec4(
        lch_to_rgb(vec3(0.8, 1, gradient_noise(vec3(world_pos * noise_scale, elapsed * time_scale))))
    , color.a);
}

#endif


#endif // PIXEL