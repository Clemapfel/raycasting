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

float hexagonal_tiling(vec2 p) {
    // Triangle lattice basis vectors
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

    if (fract_part.x + fract_part.y < 1.0) {
        // Lower-left triangle
        candidates[0] = base_point;
        candidates[1] = base_point + vec2(1.0, 0.0);
        candidates[2] = base_point + vec2(0.0, 1.0);
    } else {
        // Upper-right triangle
        candidates[0] = base_point + vec2(1.0, 0.0);
        candidates[1] = base_point + vec2(0.0, 1.0);
        candidates[2] = base_point + vec2(1.0, 1.0);
    }

    // Find the closest lattice point
    float min_distance = 1e10;
    for (int i = 0; i < 3; i++) {
        vec2 world_point = lattice_to_world * candidates[i];
        float dist = distance(p, world_point);
        min_distance = min(min_distance, dist);
    }

    return min_distance;
}

float triangular_tiling(vec2 p) {
    // Triangle lattice basis vectors
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

    if (fract_part.x + fract_part.y < 1.0) {
        // Lower-left triangle
        candidates[0] = base_point;
        candidates[1] = base_point + vec2(1.0, 0.0);
        candidates[2] = base_point + vec2(0.0, 1.0);
    } else {
        // Upper-right triangle
        candidates[0] = base_point + vec2(1.0, 0.0);
        candidates[1] = base_point + vec2(0.0, 1.0);
        candidates[2] = base_point + vec2(1.0, 1.0);
    }

    // Instead of finding closest point, find closest edge
    // For a triangular tiling, we want distance to the nearest edge
    float min_distance = 1e10;

    // Check distance to each of the 3 edges of the triangle
    for (int i = 0; i < 3; i++) {
        vec2 p0 = lattice_to_world * candidates[i];
        vec2 p1 = lattice_to_world * candidates[(i + 1) % 3];

        // Distance from point p to line segment p0-p1
        vec2 edge = p1 - p0;
        vec2 to_point = p - p0;
        float t = clamp(dot(to_point, edge) / dot(edge, edge), 0.0, 1.0);
        vec2 closest = p0 + t * edge;
        float dist = distance(p, closest);

        min_distance = min(min_distance, dist);
    }

    return (1 - min_distance * 2) / 2;
}

uniform float elapsed;

vec4 effect(vec4 vertex_color, Image img, vec2 texture_position, vec2 frag_position)
{
    //vec2 uv = (inverse_camera_transform * vec4(frag_position.xy, 0, 1)).xy;
    vec2 uv = to_uv(frag_position);

    float noise = gradient_noise(vec3(uv * 5, 1));
    float triangle = triangular_tiling((uv) * 10);

    float threshold = 0.5 + noise * 2;
    float eps = 0.1;
    triangle = smoothstep(threshold - eps, threshold + eps, 1 - triangle);

    return vec4(vec4(triangle));

}