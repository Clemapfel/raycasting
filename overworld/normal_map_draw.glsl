#ifdef PIXEL

float fast_angle(vec2 dxy)
{
    float dx = dxy.x;
    float dy = dxy.y;
    float p = dx / (abs(dx) + abs(dy));
    if (dy < 0.0)
    return (3.0 - p) / 4.0;
    else
    return (1.0 + p) / 4.0;
}

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

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

uniform vec2 player_position; // in screen coords
uniform vec4 player_color;

#ifdef PIXEL

// ... [existing utility functions: fast_angle, hsv_to_rgb, etc.] ...

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) // tex is RG8
{
    vec4 data = texture(tex, texture_coords);
    if (data.x == 0 && data.y == 0) discard;

    // Normal from normal map (in tangent space, xy only)
    vec2 gradient = (data.xy * 2.0) - 1.0; // [-1,1] range

    // Add noise to the normal for surface detail
    float noise_scale = 20.0; // Controls frequency of noise
    float noise_strength = 0.0; // Controls how much the noise perturbs the normal

    // Use screen_coords as noise input for stable world-space noise
    vec2 uv = to_uv(screen_coords);
    float n = gradient_noise(vec3(uv * noise_scale, 0.0));
    float n2 = gradient_noise(vec3(uv * noise_scale, 10.0));
    vec2 noise_vec = vec2(n, n2) * 2.0 - 1.0;

    // Perturb the gradient with noise
    vec2 perturbed_gradient = normalize(gradient + noise_vec * noise_strength);

    vec3 normal = normalize(vec3(perturbed_gradient, sqrt(max(0.0, 1.0 - dot(perturbed_gradient, perturbed_gradient)))));

    // Light direction (from fragment to player_position)
    vec2 frag_pos = screen_coords;
    vec2 light_vec = player_position - frag_pos;
    float dist = length(light_vec);

    // Assume light comes from above the screen (z+)
    vec3 light_direction = normalize(vec3(light_vec, 20.0)); // 20 is arbitrary for some "height"

    // Lambertian diffuse
    float diff = max(dot(normal, light_direction), 0.0);

    // Attenuation (optional, tweak as needed)
    float attenuation = 1.0 / (0.02 * dist + 1.0);

    // Final intensity
    float intensity = diff * attenuation;

    // --- Opalescence effect ---
    // Map the normal's direction to a hue
    float angle = atan(normal.y, normal.x); // [-PI, PI]
    float hue = (angle / (2.0 * PI)) + 0.5; // [0,1]
    float sat = 0.5 + 0.5 * normal.z; // More face-on = more saturated
    float val = 1.0;

    vec3 opal_color = hsv_to_rgb(vec3(hue, sat, val));

    // Optionally, add some sparkle/noise to the hue for more realism
    //float sparkle = gradient_noise(vec3(uv * 50.0, 30.0));
    opal_color = hsv_to_rgb(vec3(hue, sat, val));

    // Blend opalescent color with lighting
    float opal_strength = 0.7; // 0 = no opal, 1 = full opal
    vec3 final_color = mix(vec3(intensity) * player_color.rgb, opal_color, opal_strength * diff);

    return vec4(final_color, 1.0);
}
#endif
#endif