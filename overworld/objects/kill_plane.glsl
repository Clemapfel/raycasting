#ifdef PIXEL

#define MODE_INNER 0
#define MODE_OUTER 1

#ifndef MODE
#error "MODE not set, should be 0 or 1"
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

#define PI 3.1415926535897932384626433832795

float gaussian(float x, float ramp)
{
    // e^{-\frac{4\pi}{3}\left(r\cdot\left(x-c\right)\right)^{2}}
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}
// Butterworth bandpass filter
float butterworth_bandpass(float x, float center, float bandwidth, int order) {
    // Normalize frequency relative to center
    float normalized_freq = abs(x - center) / (bandwidth * 0.5);

    // Avoid division by zero
    if (normalized_freq < 0.001) {
        return 1.0;
    }

    // Butterworth bandpass response
    float response = 1.0 / (1.0 + pow(normalized_freq, 2.0 * float(order)));

    return response;
}


float butterworth(float x, float ramp, int order) {
    // Map ramp parameter to bandwidth (inverse relationship like gaussian)
    float bandwidth = 2.0 / max(ramp, 0.1);
    float center = 0.0; // Center the filter at x=0

    return butterworth_bandpass(x, center, bandwidth, order);
}

float symmetric(float value) {
    return abs(fract(value) * 2.0 - 1.0);
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

uniform float elapsed;
uniform vec4 red;

#if MODE == MODE_INNER
uniform vec2 center; // unnormalized screen coords
#endif

const float noise_scale = 30;

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

float triangle(float x) {
    return 2.0 * abs(fract(x) - 0.5) - 1.0;
}

float triangle_tiling(vec2 p) {
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

// Hash function for pseudo-random values
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Rotate a 2D vector by angle (in radians)
vec2 rotate(vec2 v, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// Triangle distance function
float triangleDist(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 v0 = c - a;
    vec2 v1 = b - a;
    vec2 v2 = p - a;

    float dot00 = dot(v0, v0);
    float dot01 = dot(v0, v1);
    float dot02 = dot(v0, v2);
    float dot11 = dot(v1, v1);
    float dot12 = dot(v1, v2);

    float invDenom = 1.0 / (dot00 * dot11 - dot01 * dot01);
    float u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    float v = (dot00 * dot12 - dot01 * dot02) * invDenom;

    // Check if point is inside triangle
    if (u >= 0.0 && v >= 0.0 && u + v <= 1.0) {
        return 0.0;
    }

    // Distance to edges
    vec2 pa = p - a;
    vec2 ba = b - a;
    vec2 ca = c - a;
    vec2 pb = p - b;
    vec2 cb = c - b;

    float h1 = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float h2 = clamp(dot(pb, cb) / dot(cb, cb), 0.0, 1.0);
    float h3 = clamp(dot(p - c, -ca) / dot(ca, ca), 0.0, 1.0);

    vec2 d1 = pa - ba * h1;
    vec2 d2 = pb - cb * h2;
    vec2 d3 = (p - c) + ca * h3;

    return sqrt(min(min(dot(d1, d1), dot(d2, d2)), dot(d3, d3)));
}

// Main triangular noise function
float triangularNoise(vec2 p) {
    float noise = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;

    // Multiple octaves for complexity
    for (int i = 0; i < 4; i++) {
        vec2 coord = p * frequency;
        vec2 cell = floor(coord);
        vec2 frac = fract(coord);

        float minDist = 10.0;

        // Check surrounding cells for triangles
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                vec2 cellOffset = vec2(float(x), float(y));
                vec2 currentCell = cell + cellOffset;

                // Generate random values for this cell
                vec2 h1 = hash2(currentCell);
                vec2 h2 = hash2(currentCell + vec2(0.1, 0.7));
                vec2 h3 = hash2(currentCell + vec2(0.3, 0.2));
                vec2 h4 = hash2(currentCell + vec2(0.8, 0.9));

                // Create triangle size variation (0.3 to 1.2)
                float size = 0.3 + 0.9 * (0.5 + 0.5 * h4.x);

                // Random rotation angle
                float angle = h4.y * 6.28318; // 2*PI

                // Base triangle vertices (equilateral)
                vec2 v1 = vec2(0.0, 0.6) * size;
                vec2 v2 = vec2(-0.52, -0.3) * size;
                vec2 v3 = vec2(0.52, -0.3) * size;

                // Apply rotation
                v1 = rotate(v1, angle);
                v2 = rotate(v2, angle);
                v3 = rotate(v3, angle);

                // Triangle center position with some randomness
                vec2 center = currentCell + 0.5 + h1 * 0.4;

                // Translate vertices to triangle position
                v1 += center;
                v2 += center;
                v3 += center;

                // Calculate distance to this triangle
                float dist = triangleDist(coord, v1, v2, v3);

                // Create sharp triangle edges with falloff
                float triangleValue = 1.0 - smoothstep(0.0, 0.15, dist);

                // Add some randomness to triangle "height"
                triangleValue *= 0.5 + 0.5 * h2.x;

                noise += triangleValue * amplitude;
            }
        }

        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return clamp(noise, 0.0, 1.0);
}

// Alternative version with more pronounced triangle shapes
float triangle_noise(vec2 p) {
    vec2 coord = p;
    vec2 cell = floor(coord);

    float noise = 0.0;

    // Check surrounding cells
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 cellOffset = vec2(float(x), float(y));
            vec2 currentCell = cell + cellOffset;

            vec2 h = hash2(currentCell);
            vec2 h2 = hash2(currentCell + vec2(0.5, 0.5));

            // Triangle center
            vec2 center = currentCell + 0.5 + h * 0.3;

            // Size and rotation
            float size = 0.4 + 0.6 * gradient_noise(vec3(h2, elapsed));
            float angle = h2.y * 6.28318;

            // Triangle pointing in random direction
            vec2 dir = vec2(cos(angle), sin(angle));
            vec2 perp = vec2(-dir.y, dir.x);

            vec2 tip = center + dir * size;
            vec2 base1 = center - dir * size * 0.3 + perp * size * 0.5;
            vec2 base2 = center - dir * size * 0.3 - perp * size * 0.5;

            float dist = triangleDist(coord, tip, base1, base2);
            float triangleValue = 1.0 - smoothstep(0.0, 0.1, dist);

            noise = max(noise, triangleValue * (0.7 + 0.3 * abs(h.y)));
        }
    }

    return noise;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec2 uv = to_uv(frag_position.xy);

    #if MODE == MODE_OUTER

    vec2 seed = vec2(symmetric(texture_coords.x))   ;
    float noise = (gradient_noise(vec3(vec2(seed) * noise_scale, elapsed)) + 1) / 2;
    float opacity = 1 - (texture_coords.y + 0.5 * noise);
    opacity *= 3;
    vec3 intensity = vec3(gaussian(dirac(opacity), 3));

    #elif MODE == MODE_INNER

    uv = texture_coords;
    float eps = 0.01;
    float opacity = 1;
    float intensity = triangle_noise(uv * 10);

    #endif

    return red * vec4(vec3(intensity), opacity);
}

#endif // PIXEL