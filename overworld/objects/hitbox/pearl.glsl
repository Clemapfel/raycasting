//
// Initialize particle mesh texture, will be used for drawing particles using metaballs
//

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

    float result = mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );

    return (result + 1) / 2.;
}

#define PI 3.1415926535897932384626433832795

// Light properties
const vec3 light_color = vec3(1);

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

const float min_density = 1;

float density_falloff(float x) {
    return (min_density + 1.0 + log(max(x, 0.0001)) / 2.0);
}

float light_falloff(float x) {
    const float ramp = 0.15;
    const float peak = 2;
    return (1 - exp(-2 * ramp * x * x)) * peak;
}

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}


uniform vec3 red;

// Function to create a rotation matrix for the x-axis
mat3 rotation_x(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat3(
    1.0, 0.0, 0.0,
    0.0, c, -s,
    0.0, s, c
    );
}

// Function to create a rotation matrix for the y-axis
mat3 rotation_y(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat3(
    c, 0.0, s,
    0.0, 1.0, 0.0,
    -s, 0.0, c
    );
}

// Function to create a rotation matrix for the z-axis
mat3 rotation_z(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat3(
    c, -s, 0.0,
    s, c, 0.0,
    0.0, 0.0, 1.0
    );
}

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

uniform vec2 player_position;
uniform float player_hue;

uniform float elapsed;

vec4 effect(vec4 color, Image density_image, vec2 texture_coords, vec2 screen_coords) {
    // Compute world position of this fragment in the same space as player_position
    vec2 uv = to_uv(screen_coords) * 22.0;
    vec2 pixel_size = 1.0 / love_ScreenSize.xy * 10.0; // scale pixel size to match uv scaling

    float n00 = gradient_noise(vec3(uv + pixel_size * vec2(-1.0, -1.0), elapsed));
    float n10 = gradient_noise(vec3(uv + pixel_size * vec2( 0.0, -1.0), elapsed));
    float n20 = gradient_noise(vec3(uv + pixel_size * vec2( 1.0, -1.0), elapsed));
    float n01 = gradient_noise(vec3(uv + pixel_size * vec2(-1.0,  0.0), elapsed));
    float n11 = gradient_noise(vec3(uv + pixel_size * vec2( 0.0,  0.0), elapsed));
    float n21 = gradient_noise(vec3(uv + pixel_size * vec2( 1.0,  0.0), elapsed));
    float n02 = gradient_noise(vec3(uv + pixel_size * vec2(-1.0,  1.0), elapsed));
    float n12 = gradient_noise(vec3(uv + pixel_size * vec2( 0.0,  1.0), elapsed));
    float n22 = gradient_noise(vec3(uv + pixel_size * vec2( 1.0,  1.0), elapsed));

    float sobel_x =
    -1.0 * n00 + 0.0 * n10 + 1.0 * n20 +
    -2.0 * n01 + 0.0 * n11 + 2.0 * n21 +
    -1.0 * n02 + 0.0 * n12 + 1.0 * n22;

    float sobel_y =
    -1.0 * n00 + -2.0 * n10 + -1.0 * n20 +
    0.0 * n01 +  0.0 * n11 +  0.0 * n21 +
    1.0 * n02 +  2.0 * n12 +  1.0 * n22;

    float dx = sobel_x / 8.0;
    float dy = sobel_y / 8.0;

    dx *= 20;
    dy *= 20;

    float density = n11;

    // Compute light direction from fragment to player position (in world space)
    // Assume fragment world position is uv (already in world scale)
    vec3 frag_world = vec3(screen_coords, 0.0);
    vec3 player_world = vec3(player_position, 20.0); // Light above the surface for better shading
    vec3 light_dir = normalize(player_world - frag_world);

    vec3 normal = normalize(vec3(-dx, -dy, 1.0));
    float diffuse = dot(normal, light_dir);

    // ---- LCH IRIDESCENCE EFFECT ----
    float iridescence_angle = clamp(dot(normal, light_dir), 0.0, 1.0);

    // Animate the rainbow pattern with elapsed time and some spatial variation
    float rainbow_shift = min(distance(player_position / love_ScreenSize.xy, screen_coords / love_ScreenSize.xy), 0.5) * 2 / camera_scale;

    // L: Lightness, C: Chroma, H: Hue
    // We'll modulate H (hue) for rainbow, C for vividness, L for brightness
    float lch_L = 0.7 + 0.3 * iridescence_angle; // Brighter at facing angles
    float lch_C = 0.1 * pow(1.0 - iridescence_angle, 0.5); // More chroma at grazing
    float lch_H = mod(0.6 + 0.5 * sin(8.0 * acos(iridescence_angle) + rainbow_shift), 1.0);
    lch_H = mod(lch_H + player_hue, 1.0);


    vec3 iridescence_rgb = lch_to_rgb(vec3(lch_L, lch_C, lch_H));
    float iridescence_strength = 1.0 * pow(1.0 - iridescence_angle, 1.5);

    // ---- END LCH IRIDESCENCE ----

    // For specular, use the same light direction
    float shininess = 128.0;
    float specular_intensity = 2.0;
    float specular = pow(max(dot(normal, light_dir), 0.9), shininess);
    specular = specular * specular_intensity * density;

    // Subsurface scattering effect (reacts to light angle)
    float subsurface_scattering = 0.3 * (density) * max(dot(normal, light_dir), 0.0);

    const float ambient = 0.1;
    float value = (ambient + diffuse + subsurface_scattering) - light_falloff(density);

    const float water_surface_eps = 0.15;
    // Blend iridescence with white for specular
    vec3 base_color = mix(iridescence_rgb, vec3(1), specular);

    vec4 soap = vec4(base_color, smoothstep(0.1, 0.1 + water_surface_eps, min(density_falloff(density), 1.0)));
    return vec4(base_color, 1);
}

#endif