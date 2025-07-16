#ifdef PIXEL

// src: https://www.shadertoy.com/view/Xc23Wd

#define PI 3.1415926535897932384626433832795
vec2 random2(vec2 st)
{
    st = vec2(
    dot(st, vec2(121.1, 311.7) * PI * 10e5),
    dot(st, vec2(269.5, 183.3) * PI * 10e5)
    );
    return fract(sin(st) * 43758.5453123);
}

float worley_sdf(vec2 uv)
{
    vec2 cell_idx = floor(uv);   // 2d cell index
    vec2 cell_uv = fract(uv);    // in-cell coords

    vec2 dist = vec2(1.0f);    // x - min distance, y - second min distance
    for (int i= -1; i <= 1; i++)
    for (int j= -1; j <= 1; j++)
    {
        // Determining the position of the neighboring cell in the grid
        vec2 neighbor_idx_delta = vec2(i, j);
        vec2 neighbor_point = random2(cell_idx + neighbor_idx_delta);

        // Calculating distances in cell space to preserve accuracy
        vec2 relative_shift = neighbor_point + neighbor_idx_delta - cell_uv;

        // Calculating min distances
        float dist_squared = dot(relative_shift, relative_shift);
        dist.y = max(dist.x, min(dist.y, dist_squared));
        dist.x = min(dist.x, dist_squared);
    }

    // The difference yields sharper pattern
    return dist.y - dist.x;
}

vec2 worley_sdf_gradient(vec2 uv)
{
    vec2 cell_idx = floor(uv);
    vec2 cell_uv = fract(uv);

    vec2 dist = vec2(1.0f);
    vec2 closest_point = vec2(0.0f);
    vec2 second_closest_point = vec2(0.0f);

    // Find the two closest points and their distances
    for (int i = -1; i <= 1; i++)
    for (int j = -1; j <= 1; j++)
    {
        vec2 neighbor_idx_delta = vec2(i, j);
        vec2 neighbor_point = random2(cell_idx + neighbor_idx_delta);
        vec2 relative_shift = neighbor_point + neighbor_idx_delta - cell_uv;

        float dist_squared = dot(relative_shift, relative_shift);

        if (dist_squared < dist.x)
        {
            // New closest point
            dist.y = dist.x;
            second_closest_point = closest_point;
            dist.x = dist_squared;
            closest_point = relative_shift;
        }
        else if (dist_squared < dist.y)
        {
            // New second closest point
            dist.y = dist_squared;
            second_closest_point = relative_shift;
        }
    }

    // Compute gradients of the two closest distances
    // Gradient of distance squared d² is 2d, so gradient of distance is d/|d|
    // But since we're working with squared distances, we use 2d directly
    vec2 grad_closest = 2.0f * closest_point;
    vec2 grad_second_closest = 2.0f * second_closest_point;

    // The gradient of (second_dist - first_dist) is grad_second - grad_first
    return grad_second_closest - grad_closest;
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

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform float time = 0;

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

uniform vec2 player_position;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 screen_uv = to_uv(screen_coords);
    vec2 player_uv = to_uv(player_position);

    const float noise_scale = 20;
    float height = worley_sdf(screen_uv * noise_scale);
    vec2 gradient = worley_sdf_gradient(screen_uv * noise_scale);

    // texutre

    vec2 direction = normalize(gradient - camera_offset / love_ScreenSize.x);
    float angle = (atan(direction.y, direction.x) + PI) / (2 * PI);
    vec3 iridescent_color = lch_to_rgb(vec3(0.8, 1, fract(angle * 2.5)));

    // lighting

    vec2 light_direction = normalize(0.3 * camera_offset - screen_uv);
    float attenuation = 1 - gaussian(distance(player_uv, screen_uv), 1.7);
    float alignment = 0.5 * abs(dot(normalize(gradient), normalize(light_direction)));

    float reflection = pow(alignment * (1 - attenuation), 1);

    vec3 base = vec3(0);
    return vec4(vec3(iridescent_color * reflection), 1);
}

#endif