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

#define PI 3.1415926535897932384626433832795

float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float fast_angle(vec2 dxy) {
    float dx = dxy.x;
    float dy = dxy.y;
    float p = dx / (abs(dx) + abs(dy));
    if (dy < 0.0) {
        return (3.0 - p) / 4.0;
    } else {
        return (1.0 + p) / 4.0;
    }
}

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

float triangle_rounded_sdf(vec2 p, vec2 v0, vec2 v1, vec2 v2, float radius) {
    // SDF to each edge
    vec2 e0 = v1 - v0, e1 = v2 - v1, e2 = v0 - v2;
    vec2 w0 = p - v0, w1 = p - v1, w2 = p - v2;

    // Project point onto edge, clamp to segment
    float t0 = clamp(dot(w0, e0) / dot(e0, e0), 0.0, 1.0);
    float t1 = clamp(dot(w1, e1) / dot(e1, e1), 0.0, 1.0);
    float t2 = clamp(dot(w2, e2) / dot(e2, e2), 0.0, 1.0);

    // Closest point on each edge
    vec2 c0 = v0 + t0 * e0;
    vec2 c1 = v1 + t1 * e1;
    vec2 c2 = v2 + t2 * e2;

    // Distances to edges
    float d0 = length(p - c0);
    float d1 = length(p - c1);
    float d2 = length(p - c2);

    // SDF to triangle (positive outside, negative inside)
    float edge_sdf = min(d0, min(d1, d2));

    // Barycentric test for inside
    float denom = (v1.x-v0.x)*(v2.y-v0.y)-(v2.x-v0.x)*(v1.y-v0.y);
    float u = ((p.x-v0.x)*(v2.y-v0.y)-(v2.x-v0.x)*(p.y-v0.y)) / denom;
    float v = ((v1.x-v0.x)*(p.y-v0.y)-(p.x-v0.x)*(v1.y-v0.y)) / denom;
    float w = 1.0 - u - v;
    float inside = (u >= 0.0 && v >= 0.0 && w >= 0.0) ? -1.0 : 1.0;

    // Rounded corners: subtract radius, smooth min at corners
    return edge_sdf * inside - radius;
}

void triangle_tiling(
    in vec2 p,
    out float hue,
    out float min_distance,
    out float edge_distance,
    out vec2 edge_gradient // <--- NEW
) {
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
    // We need to check different sets of 3 lattice points depending on which triangle we're in
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

    min_distance = 1e10;
    for (int i = 0; i < 3; i++) {
        vec2 world_point = lattice_to_world * candidates[i];
        float dist = distance(p, world_point);
        min_distance = min(min_distance, dist);
    }


    edge_distance = 1e10;
    edge_gradient = vec2(0.0); // <--- NEW

    // Get triangle vertices in world space
    vec2 v0 = lattice_to_world * candidates[0];
    vec2 v1 = lattice_to_world * candidates[1];
    vec2 v2 = lattice_to_world * candidates[2];

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
    edge_distance = min(d0, min(d1, d2)); // Distance to nearest edge in barycentric

    // --- Gradient computation ---
    // d(u)/d(p) = [e1.y, -e1.x] / denom
    // d(v)/d(p) = [-e0.y,  e0.x] / denom
    // d(w)/d(p) = -d(u)/d(p) - d(v)/d(p)
    vec2 du_dp = vec2(e1.y, -e1.x) / denom;
    vec2 dv_dp = vec2(-e0.y, e0.x) / denom;
    vec2 dw_dp = -du_dp - dv_dp;

    // The gradient of abs(u) is sign(u) * du_dp, etc.
    vec2 grad_d0 = sign(u) * du_dp;
    vec2 grad_d1 = sign(v) * dv_dp;
    vec2 grad_d2 = sign(w) * dw_dp;

    // Select the gradient corresponding to the minimum edge_distance
    if (edge_distance == d0) {
        edge_gradient = grad_d0;
    } else if (edge_distance == d1) {
        edge_gradient = grad_d1;
    } else {
        edge_gradient = grad_d2;
    }

    // Compute SDF for outline: scale edge_distance to world units
    float outline_width = 0.04; // tweakable: thickness of outline in tile units

    vec2 tile_id = base_point + vec2(float(triangle_type) * 0.5, 0.0);
    hue = fract(sin(dot(tile_id, vec2(12.9898, 78.233))) * 43758.5453);
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
}

float fractal_noise(vec3 p, int octaves, float persistence, float lacunarity) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;

    for (int i = 0; i < octaves; i++) {
        value += gradient_noise(p * frequency) * amplitude;
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    return value / max_value;
}

uniform float elapsed;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    texture_coords *= love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);
    vec2 center = vec2(0.5) * love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);

    float hue;
    float min_distance;
    float edge_distance;
    vec2 edge_gradient;
    triangle_tiling(texture_coords * 10 + elapsed / 9, hue, min_distance, edge_distance, edge_gradient);

    // outline
    float outline_thickness = 5 / love_ScreenSize.y; // tweakable, try 0.015-0.04
    float eps = 0.01;
    float outline = smoothstep(0, 0.3, min_distance) * smoothstep(outline_thickness + eps, outline_thickness, edge_distance);

    // lighting: normal map from SDF gradient, light rotates in xy plane
    float attenuation = 1; //symmetric(distance(uv, center) * 2 + elapsed / 5);

    vec3 surface_normal = normalize(vec3(edge_gradient.xy, 1.0));
    float direction_time_scale = 1;
    vec3 light_direction = normalize(vec3(cos(elapsed * direction_time_scale), sin(elapsed * direction_time_scale), 1.0));
    float alignment = attenuation * max(dot(surface_normal, light_direction), 0);

    // color
    float noise = (fractal_noise(vec3(texture_coords * 1.2, 1), 4, 3, 3) + 1) / 2;

    vec3 rgb = lch_to_rgb(vec3(0.65, 1, min_distance / 3 + hue + noise));
    rgb = mix(rgb, vec3(1), mix(0, 0.4, alignment));
    rgb = mix(rgb, vec3(0), mix(0, 0.4, gaussian(edge_distance, 4)));
    return vec4(rgb - outline, 1.0);
}