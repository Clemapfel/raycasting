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

float triangle_tiling_sdf(vec2 p, out vec2 gradient) {
    const float sqrt3 = 1.7320508075688772;
    const vec2 basis_a = vec2(1.0, 0.0);
    const vec2 basis_b = vec2(0.5, sqrt3 * 0.5);

    // Transform to lattice coordinates
    mat2 lattice_to_world = mat2(basis_a, basis_b);
    mat2 world_to_lattice = inverse(lattice_to_world);
    vec2 lattice_coords = world_to_lattice * p;

    // Find the nearest lattice point
    vec2 base_point = floor(lattice_coords);
    vec2 fract_part = lattice_coords - base_point;

    // Determine which triangle we're in within the parallelogram
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

    // Get triangle vertices in world space
    vec2 v0 = lattice_to_world * candidates[0];
    vec2 v1 = lattice_to_world * candidates[1];
    vec2 v2 = lattice_to_world * candidates[2];

    // Compute barycentric coordinates
    vec2 e0 = v1 - v0;
    vec2 e1 = v2 - v0;
    vec2 d = p - v0;

    float denom = e0.x * e1.y - e1.x * e0.y;
    float u = (d.x * e1.y - e1.x * d.y) / denom;
    float v = (e0.x * d.y - d.x * e0.y) / denom;
    float w = 1.0 - u - v;

    // Distance to each edge (in barycentric space)
    float d0 = abs(u);
    float d1 = abs(v);
    float d2 = abs(w);
    float edge_distance = min(d0, min(d1, d2));

    // Compute gradients of barycentric coordinates
    vec2 du_dp = vec2(e1.y, -e1.x) / denom;
    vec2 dv_dp = vec2(-e0.y, e0.x) / denom;
    vec2 dw_dp = -du_dp - dv_dp;

    // Gradients of abs(barycentric coords)
    vec2 grad_d0 = sign(u) * du_dp;
    vec2 grad_d1 = sign(v) * dv_dp;
    vec2 grad_d2 = sign(w) * dw_dp;

    // Select gradient corresponding to minimum edge distance
    if (edge_distance == d0) {
        gradient = grad_d0;
    } else if (edge_distance == d1) {
        gradient = grad_d1;
    } else {
        gradient = grad_d2;
    }

    // Convert barycentric distance to world-space distance
    // The barycentric distance needs to be scaled by the altitude of the triangle
    float triangle_altitude = sqrt3 * 0.5; // altitude of unit equilateral triangle
    float sdf = edge_distance * triangle_altitude;

    return sdf;
}

// Hexagonal tiling SDF with analytic gradient (pointy-top hexagons, side = 1.0)
float hexagon_tiling_sdf(vec2 p, out vec2 gradient) {
    const float SQRT3 = 1.7320508075688772;
    // Side length of each hexagon (set to 1.0 here for convenience)
    const float a = 1.0;

    // Lattice basis for pointy-top hexagon centers:
    // (these place hex centers in axial orientation)
    // basis_x = (sqrt(3)*a, 0)
    // basis_y = (sqrt(3)/2*a, 1.5*a)
    mat2 lattice_to_world = mat2(
    vec2(SQRT3 * a, 0.0),
    vec2(0.5 * SQRT3 * a, 1.5 * a)
    );
    mat2 world_to_lattice = inverse(lattice_to_world);

    // Map point to lattice coordinates and find nearest hex center
    vec2 lattice_coords = world_to_lattice * p;
    // round to nearest integer lattice point (nearest center)
    vec2 nearest_lattice = floor(lattice_coords + 0.5);
    vec2 center = lattice_to_world * nearest_lattice;

    // Local coordinates relative to hex center (in world units)
    vec2 lp = p - center;

    // Define the 6 hex vertices for a regular pointy-top hex with side 'a'
    // circumradius = a; vertices ordered CCW starting at angle 0 (rightmost)
    vec2 verts[6];
    verts[0] = vec2( 1.0 * a,  0.0                );
    verts[1] = vec2( 0.5 * a,  0.5 * SQRT3 * a   );
    verts[2] = vec2(-0.5 * a,  0.5 * SQRT3 * a   );
    verts[3] = vec2(-1.0 * a,  0.0               );
    verts[4] = vec2(-0.5 * a, -0.5 * SQRT3 * a   );
    verts[5] = vec2( 0.5 * a, -0.5 * SQRT3 * a   );

    // Compute signed distances to the infinite supporting lines (to test inside/outside)
    float max_line = -1e20;
    for (int i = 0; i < 6; ++i) {
        int j = (i + 1) % 6;
        vec2 e = verts[j] - verts[i];            // edge vector (CCW)
        // outward normal for CCW polygon: (e.y, -e.x)
        vec2 n = normalize(vec2(e.y, -e.x));
        float lineDist = dot(lp - verts[i], n);  // positive outside, negative inside
        if (lineDist > max_line) max_line = lineDist;
    }
    bool inside = (max_line <= 0.0);

    // Now find the true Euclidean closest point on the polygon boundary (segments)
    float minDist = 1e20;
    vec2 bestClosest = vec2(0.0);
    for (int i = 0; i < 6; ++i) {
        int j = (i + 1) % 6;
        vec2 a_pt = verts[i];
        vec2 b_pt = verts[j];
        vec2 ab = b_pt - a_pt;
        vec2 ap = lp - a_pt;
        float ab2 = dot(ab, ab);
        // projection parameter t in [0,1]
        float t = 0.0;
        if (ab2 > 0.0) {
            t = clamp(dot(ap, ab) / ab2, 0.0, 1.0);
        }
        vec2 proj = a_pt + ab * t;
        vec2 diff = lp - proj;
        float d = length(diff);
        if (d < minDist) {
            minDist = d;
            bestClosest = proj;
        }
    }

    // Signed distance: negative inside, positive outside
    float sdf = inside ? -minDist : minDist;

    // Compute analytic gradient (outward unit normal)
    // diff = p_local - closest_point_on_boundary
    vec2 diffVec = lp - bestClosest;
    float eps = 1e-9;
    if (minDist < eps) {
        // The point is practically on the boundary (or exactly at a vertex).
        // Gradient is undefined or numerically unstable; set to outward normal by
        // using the supporting-line with maximal lineDist computed above.
        // Find that edge and use its outward normal
        vec2 fallbackN = vec2(0.0);
        float bestLine = -1e20;
        for (int i = 0; i < 6; ++i) {
            int j = (i + 1) % 6;
            vec2 e = verts[j] - verts[i];
            vec2 n = normalize(vec2(e.y, -e.x));
            float lineDist = dot(lp - verts[i], n);
            if (lineDist > bestLine) {
                bestLine = lineDist;
                fallbackN = n;
            }
        }
        // outward normal should be fallbackN regardless of inside/outside
        gradient = fallbackN;
    } else {
        // gradient direction (unit): make it point outward always
        vec2 n_local = normalize(diffVec);       // points from boundary -> point
        // If point outside: n_local points outward already; if inside n_local points inward.
        // We want outward unit normal. So multiply by sign(sdf)
        float s = inside ? -1.0 : 1.0;
        gradient = s * n_local;
    }

    // gradient is in world-space (lp was in world units), no further transform needed
    return sdf;
}

/*
  Hexagonal tiling signed distance function with analytic gradient.

  Overview:
    - Computes the signed distance to the nearest edge of a regular hexagonal tiling.
    - Also returns the analytic gradient (unit-length almost everywhere).
    - The sign is defined with respect to the nearest edge's normal: it flips across each tile edge.
      For typical line rendering (e.g., width w), use: abs(d) - w.

  Parameters:
    - p: point in 2D plane (world units).
    - a: hex cell apothem (distance from center to a side). Controls tile size.
         Hex circumradius R = a / cos(30°) = a * 1.154700538...
    - grad: out parameter receiving the gradient of the signed distance.

  Notes:
    - The function finds the nearest hex center in a flat-top hex grid, reduces to local coordinates,
      then uses a symmetric folding approach to compute distance to a single edge segment.
    - Gradient is computed analytically by finding the nearest point on the edge segment and
      propagating the reflections back to world space.
    - At edge and vertex singularities, the gradient is chosen consistently but is mathematically undefined.

  Reference constants:
    sqrt3 = 1.7320508075688772
    invSqrt3 = 1.0 / sqrt3 = 0.5773502691896258

  Usage:
    vec2 g;
    float d = sdHexTiling(vec2(x, y), 1.0, g);  // a=1.0 apothem
    // for line band: float mask = smoothstep(0.0, w, w - abs(d));

*/


// Compute signed distance to a hex tiling and analytic gradient.
// a = apothem (distance center -> side).
float hexagonal_tiling_sdf(in vec2 p, in float a, out vec2 grad)
{
    // Constants for 60-degree geometry
    const float SQRT3    = 1.7320508075688772;
    const float INV_SQRT3= 0.5773502691896258;

    // 1) Find nearest hex center (flat-top) using axial coordinates
    // Basis vectors for centers (columns):
    //   bq = (sqrt(3)*a, a), br = (0, 2a)
    // Inverse mapping to axial coordinates (q, r_axial):
    float qf = p.x / (SQRT3 * a);
    float rf = (-p.x + SQRT3 * p.y) / (2.0 * SQRT3 * a);

    // Cube rounding to nearest axial integer coordinates
    vec3 cube = vec3(qf, -qf - rf, rf);     // (x, y, z) with x+y+z=0
    vec3 rc = round(cube);
    vec3 diff = abs(rc - cube);
    if (diff.x > diff.y && diff.x > diff.z) {
        rc.x = -rc.y - rc.z;
    } else if (diff.y > diff.z) {
        rc.y = -rc.x - rc.z;
    } else {
        rc.z = -rc.x - rc.y;
    }

    // Convert back to world center using basis:
    // center = bq*rc.x + br*rc.z
    vec2 center = vec2(SQRT3 * a * rc.x, a * rc.x + 2.0 * a * rc.z);

    // Local coordinates relative to nearest center
    vec2 v = p - center;

    // 2) Fold into wedge via reflections (Inigo Quilez-style hex SDF core)
    // k.xy and k.yx are unit normals to the 60° reflection lines; k.z = 1/sqrt(3)
    const vec3 k = vec3(-0.5, 0.8660254037844386, INV_SQRT3);

    // Record sign from absolute-value fold to reflect gradient back later
    vec2 sAxis = vec2(v.x < 0.0 ? -1.0 : 1.0, v.y < 0.0 ? -1.0 : 1.0);
    vec2 w = abs(v);

    float d1 = dot(k.xy, w);
    bool ref1 = (d1 < 0.0);
    if (ref1) w -= 2.0 * d1 * k.xy;

    float d2 = dot(k.yx, w);
    bool ref2 = (d2 < 0.0);
    if (ref2) w -= 2.0 * d2 * k.yx;

    // 3) Nearest point on the top edge segment (y = a, x in [-a/sqrt(3), a/sqrt(3)])
    float xClamp = clamp(w.x, -k.z * a, k.z * a);
    vec2  qEdge  = vec2(xClamp, a);

    vec2  dv     = w - qEdge;
    float lenDV  = length(dv);

    // Signed distance: positive above the edge in wedge coords, negative below
    // (for line rendering you typically use abs(dist))
    float sgn = (dv.y >= 0.0) ? 1.0 : -1.0;
    float dist = lenDV * sgn;

    // 4) Analytic gradient in wedge coords
    vec2 g = (lenDV > 0.0) ? (dv / lenDV) : vec2(0.0, 1.0);
    // Outward normal of the edge (gradient of signed distance)
    g *= sgn;

    // 5) Unfold gradient back through reflections (reverse order), then axis reflections
    if (ref2) g = g - 2.0 * dot(g, k.yx) * k.yx;
    if (ref1) g = g - 2.0 * dot(g, k.xy) * k.xy;
    g *= sAxis;  // undo abs()

    grad = g;
    return dist;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform float elapsed;
uniform vec2 player_position; // screen coords
uniform vec4 player_color;
uniform mat4x4 screen_to_world_transform;

uniform vec4 outline_color;

vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords) {
    vec2 player_pos = to_world_position(player_position);
    vec2 screen_pos = to_world_position(screen_coords);

    float noise = gradient_noise(vec3(screen_pos / 100, elapsed / 3));


    vec2 gradient;
    float tiling = hexagonal_tiling_sdf(screen_pos / 75.0, 0.4, gradient);

    vec2 surface_normal = normalize(-1 * gradient) * 0.5;

    float dist = distance(player_pos, screen_pos) / 100.0;
    float attenuation = gaussian(dist, 0.5) * 0.5;

    vec2 light_direction = normalize(player_pos - screen_pos);
    float alignment = smoothstep(0, 1.6, max(dot(surface_normal, light_direction), 0.0));
    float light = alignment;
    const float eps = 0.1;
    float threshold = noise;
    float line = 1 - smoothstep(threshold - eps, threshold + eps, tiling);
    return vec4(mix(color.rgb * tiling, (max((1 - line) * 0.4, light)) * player_color.rgb * attenuation, 2), 0.7);
}