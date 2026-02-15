#ifdef PIXEL

#define PI 3.1415926535897932384626433832795

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform float elapsed;
uniform vec4 red;
uniform vec2 player_position;

float gaussian(float x, float ramp) {
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

vec3 triangleDistAndBary(vec2 p, vec2 a, vec2 b, vec2 c) {
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

    float dist;
    if (u >= 0.0 && v >= 0.0 && u + v <= 1.0) {
        dist = 0.0;
    } else {
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

        dist = sqrt(min(min(dot(d1, d1), dot(d2, d2)), dot(d3, d3)));
    }

    return vec3(dist, u, v);
}

float fast_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float n = i.x + i.y * 157.0 + i.z * 113.0;

    float ga = sin(n * 0.01) * 2.0 - 1.0;
    float gb = sin((n + 1.0) * 0.01) * 2.0 - 1.0;
    float gc = sin((n + 157.0) * 0.01) * 2.0 - 1.0;
    float gd = sin((n + 158.0) * 0.01) * 2.0 - 1.0;
    float ge = sin((n + 113.0) * 0.01) * 2.0 - 1.0;
    float gf = sin((n + 114.0) * 0.01) * 2.0 - 1.0;
    float gg = sin((n + 270.0) * 0.01) * 2.0 - 1.0;
    float gh = sin((n + 271.0) * 0.01) * 2.0 - 1.0;

    float va = ga * f.x;
    float vb = gb * (f.x - 1.0);
    float vc = gc * f.x;
    float vd = gd * (f.x - 1.0);
    float ve = ge * f.x;
    float vf = gf * (f.x - 1.0);
    float vg = gg * f.x;
    float vh = gh * (f.x - 1.0);

    float k0 = mix(va, vb, u.x);
    float k1 = mix(vc, vd, u.x);
    float k2 = mix(ve, vf, u.x);
    float k3 = mix(vg, vh, u.x);

    float k4 = mix(k0, k1, u.y);
    float k5 = mix(k2, k3, u.y);

    return mix(k4, k5, u.z) * 0.5 + 0.5;
}

float triangle_noise(vec2 p, vec2 origin) {
    vec2 target = normalize(origin - p);
    float weight = clamp(1 - distance(p, origin) * 2, 0, 1);
    p *= 40;

    vec2 coord = p;
    vec2 cell = floor(coord);

    float noise = 0.0;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 cellOffset = vec2(float(x), float(y));
            vec2 currentCell = cell + cellOffset;

            vec2 h = hash2(currentCell);
            vec2 h2 = hash2(currentCell + vec2(0.5, 0.5));
            vec2 h3 = hash2(currentCell + vec2(0.7, 0.3));

            vec2 center = currentCell + 0.5 + h * 0.3;

            float size = mix(0.2, 1.0, abs(h.x));
            float angle = h2.y * 2 * PI;

            vec2 dir = vec2(cos(angle - elapsed * h2.y), sin(angle + elapsed * h2.x));
            vec2 perp = vec2(-dir.y, dir.x);

            dir = mix(dir, target, weight);

            vec2 tip = center + dir * size;
            vec2 base1 = center - dir * size + perp * size;
            vec2 base2 = center - dir * size - perp * size;

            const float eps = 0.0;
            vec3 distAndBary = triangleDistAndBary(coord, vec2(1 - eps, 1 + eps) * tip, base1, base2);
            float dist = distAndBary.x;
            vec2 bary = distAndBary.yz;
            float baryW = 1.0 - bary.x - bary.y;

            float blur = mix(0.1, 0.05, 1 - size);
            float triangleValue = 1.0 - smoothstep(0.0, blur, dist);
            triangleValue += 1.75 * smoothstep(0, 0.3, 1 - gaussian(3 * dirac(triangleValue), 1.4));

            if (triangleValue > 0.0) {
                float baseIntensity = abs(h.x);

                float baryShading = 0.3 + 0.7 * (bary.x * 0.8 + bary.y * 0.6 + baryW * 1.0);

                vec2 localPos = coord - center;
                float centerDist = length(localPos) / size;
                float radialShading = 1.0 - 0.4 * smoothstep(0.0, 1.0, centerDist);

                vec2 lightDir = normalize(vec2(0.7, 0.3));
                vec2 triangleNormal = normalize(perp);
                float lightDot = dot(triangleNormal, lightDir);
                float directionalShading = 0.6 + 0.4 * (lightDot * 0.5 + 0.5);

                float detailNoise = fast_noise(vec3(coord * 20.0 + h3 * 10.0, elapsed * 0.5));
                float patternDetail = 0.8 + 0.2 * detailNoise;

                float edgeDistance = min(min(
                length(coord - tip),
                length(coord - base1)
                ), length(coord - base2));
                float edgeShading = 1.0 - 0.3 * exp(-edgeDistance * 5.0);

                float finalShading = baseIntensity * baryShading * radialShading *
                directionalShading * patternDetail * edgeShading;

                if (finalShading * triangleValue > noise) {
                    noise = finalShading * triangleValue;
                }
            }
        }
    }

    return noise;
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec2 world_position = to_world_position(frag_position.xy);

    const float world_scale = 1. / 500;
    float intensity = triangle_noise(world_position * world_scale, to_world_position(player_position) * world_scale);

    return red * vec4(vec3(intensity), 1.0);
}

#endif // PIXEL
