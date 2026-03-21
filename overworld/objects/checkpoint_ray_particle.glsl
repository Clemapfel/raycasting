#ifdef PIXEL

#define PI 3.1415926535897932384626433832795

// rotate vector by angle (clockwise positive)
vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

// unsigned distance from point p to segment [a,b]
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float baba = dot(ba, ba);
    if (baba == 0.0) return length(pa);
    float t = clamp(dot(pa, ba) / baba, 0.0, 1.0);
    vec2 q = a + ba * t;
    return length(p - q);
}

// point-in-triangle test using barycentric coordinates
bool pointInTriangle(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 v0 = b - a;
    vec2 v1 = c - a;
    vec2 v2 = p - a;
    float dot00 = dot(v0, v0);
    float dot01 = dot(v0, v1);
    float dot02 = dot(v0, v2);
    float dot11 = dot(v1, v1);
    float dot12 = dot(v1, v2);
    float denom = dot00 * dot11 - dot01 * dot01;
    // If degenerate triangle, return false
    if (abs(denom) < 1e-8) return false;
    float invDen = 1.0 / denom;
    float u = (dot11 * dot02 - dot01 * dot12) * invDen;
    float v = (dot00 * dot12 - dot01 * dot02) * invDen;
    return (u >= 0.0) && (v >= 0.0) && (u + v <= 1.0);
}

// Signed distance for a teardrop formed by a base circle at 'baseCenter' with radius r0,
// and a tip point 'tip' with radius 0. The envelope of circles (linear radius interpolation)
// produces two straight lateral edges from the circle perimeter to the tip.
// We compute the unsigned distance to the nearest boundary (base circle, left edge, right edge)
// then sign it negative if the point is inside (inside the base circle or inside the triangle).
float sdTeardrop(vec2 p, vec2 baseCenter, vec2 tip, float r0) {
    // axis and perpendicular direction
    vec2 axis = tip - baseCenter;
    float axisLen = length(axis);
    if (axisLen < 1e-6) {
        // degenerate: just a circle
        return length(p - baseCenter) - r0;
    }
    vec2 n = axis / axisLen;
    vec2 perp = vec2(-n.y, n.x);

    // perimeter points on base circle that connect to the tip
    vec2 leftPoint  = baseCenter + perp * r0;
    vec2 rightPoint = baseCenter - perp * r0;

    // unsigned distances to the boundary primitives
    float dCircle = length(p - baseCenter) - r0;
    float dLeftEdge  = sdSegment(p, leftPoint, tip);
    float dRightEdge = sdSegment(p, rightPoint, tip);

    float dBoundary = min(dCircle, min(dLeftEdge, dRightEdge));

    // determine if point is inside (inside base circle OR inside triangle formed by left,right,tip)
    bool inside = (length(p - baseCenter) <= r0) || pointInTriangle(p, leftPoint, rightPoint, tip);

    return inside ? -dBoundary : dBoundary;
}

vec4 effect(vec4 _0, sampler2D _1, vec2 texture_coords, vec2 _2) {
    vec2 uv = texture_coords;

    // Transform the UV to orient/scale the teardrop (kept from original)
    uv -= vec2(0.5);
    uv = rotate(uv, 1.5 * PI);
    uv /= 1;
    uv += vec2(0.5);

    // Teardrop configuration (kept inside [0,1])
    float size = 0.25;
    vec2 base_center = vec2(0.5, 0.5 - size / 2.0);
    vec2 tip         = vec2(0.5, 0.5 + size);
    float base_radius = 0.1;

    // compute signed distance using robust teardrop SDF
    float sd = sdTeardrop(uv, base_center, tip, base_radius);

    // anti-aliased fill: compute alpha from sdf
    float aa = max(fwidth(sd), 1.0 / 300.0);
    float center = 0.2;   // thickness/threshold for the visible fill boundary
    float range  = 0.0;  // softness around that threshold
    // map sdf to coverage: inside -> 1.0, outside -> 0.0 (with smoothing)
    float coverage = 1.0 - smoothstep(center - range - aa, center + range + aa, sd);

    // white teardrop with premultiplied alpha-like output
    return vec4(coverage);
}

#endif