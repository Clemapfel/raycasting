#define MODE_TRIANGLE 0
#define MODE_SQUARE 1

#ifndef MODE
#error "MODE should be 0 or 1"
#endif

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

float discontinous_noise(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float smax(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float butterworth(float x, float ramp, float order) {
    // Map ramp parameter to bandwidth (inverse relationship)
    float bandwidth = 2.0 / max(ramp, 0.1);
    float center = 0.0;

    // Normalize frequency relative to center
    float normalized_freq = abs(x - center) / (bandwidth * 0.5);

    // Avoid division by zero
    if (normalized_freq < 0.001) {
        return 1.0;
    }

    // Butterworth bandpass response
    return 1.0 / (1.0 + pow(normalized_freq, 2.0 * float(order)));
}

uniform float elapsed;

float sigmoid(float x) {
    // Generalized logistic function (sigmoid)
    // Maps [0,1] to [0,1] with S-shaped curve
    float k = 12.0;  // Steepness parameter (adjust as needed)
    return 1.0 / (1.0 + exp(-k * (x - 0.5)));
}

void triangle_tiling(in vec2 p, out float sdf, out float tile_id) {
    const vec2 basis_a = vec2(1.0, 0.0);
    const vec2 basis_b = vec2(0.5, sqrt(3.0) * 0.5);

    // Transform to lattice coordinates
    mat2 lattice_to_world = mat2(basis_a, basis_b);
    mat2 world_to_lattice = inverse(lattice_to_world);
    vec2 lattice_coords = world_to_lattice * p;

    // Find the nearest lattice point
    vec2 base_point = floor(lattice_coords);
    vec2 fract_part = lattice_coords - base_point;

    // The fundamental parallelogram is divided into two triangles
    vec2 candidates[3];
    int triangle_type = 0;

    if (fract_part.x + fract_part.y < 1.0) {
        // Lower-left triangle
        candidates[0] = base_point;
        candidates[1] = base_point + vec2(1.0, 0.0);
        candidates[2] = base_point + vec2(0.0, 1.0);
        triangle_type = 0;
    } else {
        // Upper-right triangle
        candidates[0] = base_point + vec2(1.0, 0.0);
        candidates[1] = base_point + vec2(0.0, 1.0);
        candidates[2] = base_point + vec2(1.0, 1.0);
        triangle_type = 1;
    }

    // Generate unique tile ID based on base lattice point and triangle type
    tile_id = base_point.x + base_point.y * 2000.0 + float(triangle_type) * 0.5;

    // Get triangle vertices in world space
    vec2 v0 = lattice_to_world * candidates[0];
    vec2 v1 = lattice_to_world * candidates[1];
    vec2 v2 = lattice_to_world * candidates[2];

    // Calculate triangle centroid for circle center
    vec2 triangle_center = (v0 + v1 + v2) / 3.0;

    // Barycentric coordinates to point p
    vec2 e0 = v1 - v0;
    vec2 e1 = v2 - v0;
    vec2 d = p - v0;

    float denom = e0.x * e1.y - e1.x * e0.y;
    // Compute barycentric coordinates
    float u = (d.x * e1.y - e1.x * d.y) / denom;
    float v = (e0.x * d.y - d.x * e0.y) / denom;
    float w = 1.0 - u - v;

    // For edge SDF, compute distance to each edge
    float d0 = abs(u);
    float d1 = abs(v);
    float d2 = abs(w);
    float triangle_sdf = min(d0, min(d1, d2));

    // Use smooth maximum to blend triangle and circle SDFs
    sdf = triangle_sdf * 3;

    float top = mix(1.5, 2.2, sigmoid((sin(elapsed / 1.5) + 1) / 2)); //1.5 + 1.4 * (sin(elapsed) + 1) / 2;
    sdf = 1 - smoothstep(sdf, butterworth(2 * distance(p, triangle_center), top, 2), 0.3);
    sdf = clamp(sdf, 0, 1);
}

vec2 rotate(vec2 v, vec2 origin, float angle) {
    float s = sin(angle);
    float c = cos(angle);

    v -= origin;
    v = v * mat2(c, -s, s, c);
    v += origin;
    return v;
}

void square_tiling(in vec2 p, out float sdf, out float tile_id) {
    // For square tiling, we use a simple orthogonal grid
    const vec2 basis_a = vec2(1.0, 0.0);
    const vec2 basis_b = vec2(0.0, 1.0);

    // Transform to lattice coordinates (for squares, this is just the identity)
    mat2 lattice_to_world = mat2(basis_a, basis_b);
    mat2 world_to_lattice = inverse(lattice_to_world);
    vec2 lattice_coords = world_to_lattice * p;

    // Find the nearest lattice point (grid cell)
    vec2 base_point = floor(lattice_coords);
    vec2 fract_part = lattice_coords - base_point;

    // For squares, we only have one type of tile per grid cell
    vec2 candidates[4];
    int square_type = 0;

    // Square vertices in lattice coordinates
    candidates[0] = base_point;                    // Bottom-left
    candidates[1] = base_point + vec2(1.0, 0.0);  // Bottom-right
    candidates[2] = base_point + vec2(1.0, 1.0);  // Top-right
    candidates[3] = base_point + vec2(0.0, 1.0);  // Top-left

    // Generate unique tile ID based on base lattice point
    tile_id = base_point.x + base_point.y * 2000.0;

    // Get square vertices in world space
    vec2 v0 = lattice_to_world * candidates[0];
    vec2 v1 = lattice_to_world * candidates[1];
    vec2 v2 = lattice_to_world * candidates[2];
    vec2 v3 = lattice_to_world * candidates[3];

    // Calculate square center
    vec2 square_center = (v0 + v1 + v2 + v3) / 4.0;

    // For square SDF, compute distance to edges
    // Distance to each edge of the square
    vec2 local_p = p - v0; // Point relative to bottom-left corner
    vec2 square_size = v2 - v0; // Size of the square

    // Normalize to [0,1] square
    vec2 normalized_p = local_p / square_size;

    // Distance to edges in normalized space
    float d_left = normalized_p.x;
    float d_right = 1.0 - normalized_p.x;
    float d_bottom = normalized_p.y;
    float d_top = 1.0 - normalized_p.y;

    // Minimum distance to any edge
    float square_sdf = min(min(d_left, d_right), min(d_bottom, d_top));

    // Use smooth maximum to blend square and circle SDFs
    sdf = square_sdf;

    float top = mix(0.8, 1.75, sigmoid((sin(elapsed / 1.5) + 1) / 2));
    sdf = 1 - smoothstep(sdf, gaussian(distance(p, square_center), top), 0.3);
    sdf = clamp(sdf, 0, 1);
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

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

uniform vec4 black = vec4(vec3(0), 1);


vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    texture_coords *= love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);
    vec2 center = vec2(0.5) * love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);

    float sdf;
    float tile_id;

    // Parameters for smooth max blending and circle size
    float scroll_offset = elapsed / 12.0;

    #if MODE == MODE_TRIANGLE
    triangle_tiling(
    texture_coords * 5.0 + scroll_offset,
    sdf,
    tile_id
    );

    #elif MODE == MODE_SQUARE

    square_tiling(
    rotate(texture_coords * 5 + scroll_offset, vec2(0.5), 0.25 * PI),
    sdf,
    tile_id
    );

    #endif

    // Use smoothstep tok create rounded corners
    float eps = 0.001;
    float threshold = 0.7;
    float mask = smoothstep(
    threshold - eps,
    threshold + eps,
    sdf
    );

    vec3 tile_color = lch_to_rgb(vec3(
    0.8,
    1,
    gradient_noise(vec3(2 * texture_coords.xy + scroll_offset, elapsed / 10 + 5 * sqrt(2) * mask))
    ));

    return vec4(mix(tile_color - vec3(0.1), black.rgb, mask), 1.0);
}