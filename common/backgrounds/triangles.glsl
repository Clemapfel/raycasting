
void triangle_tiling_with_id(in vec2 p, out float sdf, out float tile_id) {
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
    // We use a hash-like function to create unique IDs
    //float tile_id = base_point.x + base_point.y * 1000.0 + float(triangle_type) * 0.5;

    // Alternative: If you want consecutive integer IDs, you can use:
    tile_id = (base_point.y * 2000.0 + base_point.x * 2.0 + float(triangle_type));

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
    sdf = min(d0, min(d1, d2));


}

uniform float elapsed;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    texture_coords *= love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);
    vec2 center = vec2(0.5) * love_ScreenSize.xy / max(love_ScreenSize.x, love_ScreenSize.y);

    float sdf;
    float tile_id;
    triangle_tiling_with_id(
        texture_coords * 10.0 + elapsed / 9.0,
        sdf,
        tile_id
    );

    vec3 tile_color = vec3(
        fract(sin(tile_id * 12.9898) * 43758.5453),
        fract(sin(tile_id * 78.233) * 43758.5453),
        fract(sin(tile_id * 39.346) * 43758.5453)
    );

    return vec4(tile_color * sdf, 1.0); // Just tile colors
}