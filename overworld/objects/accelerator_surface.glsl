#ifdef PIXEL

#define MODE_BODY 0
#define MODE_OUTLINE 1

#ifndef MODE
#error "Mode undefined"
#endif

uniform vec2 camera_offset;
uniform float camera_scale = 1;
uniform float elapsed;
uniform vec2 shape_centroid; // world coords


uniform vec2 player_position;
uniform float player_hue;

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

#if MODE == MODE_BODY

uniform float outline_width;
uniform vec4 outline_color;

// src: https://www.shadertoy.com/view/Xc23Wd

#define PI 3.1415926535897932384626433832795

vec2 random2(vec2 st) {
    st = vec2(
    dot(st, vec2(121.1, 311.7) * PI * 10e5),
    dot(st, vec2(269.5, 183.3) * PI * 10e5)
    );
    return fract(sin(st) * 43758.5453123);
}

float worley_sdf(vec2 uv) {
    vec2 cell_idx = floor(uv);
    vec2 cell_uv = fract(uv);

    vec2 dist = vec2(1.0);
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 neighbor_idx_delta = vec2(i, j);
            vec2 neighbor_point = random2(cell_idx + neighbor_idx_delta);
            vec2 relative_shift = neighbor_point + neighbor_idx_delta - cell_uv;

            float dist_squared = dot(relative_shift, relative_shift);
            dist.y = max(dist.x, min(dist.y, dist_squared));
            dist.x = min(dist.x, dist_squared);
        }
    }

    return dist.y - dist.x;
}

void worley_with_data(vec2 uv, out float sdf_value, out vec2 gradient, out vec2 closest_point, out vec2 second_closest_point) {
    vec2 cell_idx = floor(uv);
    vec2 cell_uv = fract(uv);

    vec2 dist = vec2(1.0);
    closest_point = vec2(0.0);
    second_closest_point = vec2(0.0);

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 neighbor_idx_delta = vec2(i, j);
            vec2 neighbor_point = random2(cell_idx + neighbor_idx_delta);
            vec2 relative_shift = neighbor_point + neighbor_idx_delta - cell_uv;

            float dist_squared = dot(relative_shift, relative_shift);

            if (dist_squared < dist.x) {
                // New closest point
                dist.y = dist.x;
                second_closest_point = closest_point;
                dist.x = dist_squared;
                closest_point = relative_shift;
            } else if (dist_squared < dist.y) {
                // New second closest point
                dist.y = dist_squared;
                second_closest_point = relative_shift;
            }
        }
    }

    sdf_value = dist.y - dist.x;

    // Gradient of (second_dist - first_dist)
    vec2 grad_closest = 2.0 * closest_point;
    vec2 grad_second_closest = 2.0 * second_closest_point;
    gradient = grad_second_closest - grad_closest;
}

float worley_outlines(vec2 uv, float borderWidth) {
    float sdf_value;
    vec2 gradient, closest_point, second_closest_point;
    worley_with_data(uv, sdf_value, gradient, closest_point, second_closest_point);

    // Create outlines based on the SDF value
    // When sdf_value is near 0, we're close to cell boundaries
    float outline = smoothstep(borderWidth + 0.01, borderWidth - 0.01, sdf_value);

    return outline;
}

// Alternative approach using the perpendicular bisector between closest points
float worley_outlines_bisector(vec2 uv, float borderWidth) {
    float sdf_value;
    vec2 gradient, closest_point, second_closest_point;
    worley_with_data(uv, sdf_value, gradient, closest_point, second_closest_point);

    // Calculate the perpendicular bisector between the two closest points
    vec2 midpoint = (closest_point + second_closest_point) * 0.5;
    vec2 direction = normalize(second_closest_point - closest_point);

    // Distance to the bisector line
    float bisector_distance = abs(dot(midpoint, direction));

    float eps = 1 / camera_scale * 0.05;
    float outline = smoothstep(borderWidth + eps, borderWidth - eps, bisector_distance);

    return outline;
}

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 screen_uv = to_uv(screen_coords);
    vec2 player_uv = to_uv(player_position);

    const float noise_scale = 31;
    // Get Worley data using new functions
    float sdf_value;
    vec2 gradient, closest_point, second_closest_point;
    worley_with_data(screen_uv * noise_scale , sdf_value, gradient, closest_point, second_closest_point);

    // Get outlines using new technique
    float outline = worley_outlines_bisector(screen_uv * noise_scale, outline_width / 100);

    float shadow = sdf_value * 0.3;

    // Texture - iridescent color based on gradient direction
    vec2 direction = normalize(gradient - camera_offset / love_ScreenSize.x);
    float angle = (atan(direction.y, direction.x) + PI) / (2.0 * PI);
    float hue_noise = gradient_noise(vec3(screen_uv.xyx * noise_scale / 2));
    vec3 iridescent_color = lch_to_rgb(vec3(0.8 - shadow, 1, fract(hue_noise + elapsed / 5)));

    gradient = rotate(gradient, elapsed);

    // Lighting - Camera-relative lighting setup
    // The light source moves with the camera to simulate viewing angle changes
    vec2 camera_center = to_uv(10 * camera_offset + 0.5 * love_ScreenSize.xy);

    // Light position relative to camera (simulates light source moving with viewer)
    vec3 light_pos = vec3(camera_center, 1); // Slightly offset and elevated

    // Surface position in world space
    vec3 surface_pos = vec3(screen_uv, 0.0);

    // View position (camera position elevated above the 2D plane)
    vec3 view_pos = vec3(camera_center, 1.0); // Camera elevated above the surface

    // Calculate surface normal from gradient (pointing up from the 2D surface)
    vec3 surface_normal = normalize(vec3(gradient * 0.1, 1.0)); // Small gradient influence, mostly pointing up

    // Light direction (from surface to light)
    vec3 light_dir = normalize(light_pos - surface_pos);

    // View direction (from surface to camera)
    vec3 view_dir = normalize(view_pos - surface_pos);

    // Reflection vector
    vec3 reflect_dir = reflect(-light_dir, surface_normal);

    // Specular lighting (Phong model)
    float specular = pow(max(dot(view_dir, reflect_dir), 0.0), 8.0);

    // Distance-based attenuation from player (for gameplay lighting)
    float player_distance = distance(player_uv, screen_uv);
    float attenuation = 1.0 - gaussian(player_distance, 1.7);

    // Camera-based lighting alignment (how well the surface reflects toward the camera)
    vec3 camera_to_surface = normalize(surface_pos - vec3(camera_center, 0));
    float camera_alignment = abs(dot(normalize(vec3(gradient, 0)), camera_to_surface));
    float camera_reflection = pow(camera_alignment, 5.0);

    // Combine lighting effects
    vec3 final_color = mix(
    mix(iridescent_color, vec3(1), specular * 0.8),
    vec3(0.1), 1.0 - camera_reflection
    );

    return vec4(final_color, 1.0);
}

#elif MODE == MODE_OUTLINE

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 screen_uv = to_uv(screen_coords);
    return vec4(lch_to_rgb(vec3(0.8, 1, gradient_noise(vec3(screen_uv * 5, elapsed / 2)))), 1);
}

#endif


#endif // PIXEL