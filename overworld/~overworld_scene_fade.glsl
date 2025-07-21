#define PI 3.1415926535897932384626433832795

vec3 mod_289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod_289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod_289(((x * 34.0) + 10.0) * x);
}

vec4 taylor_inv_sqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float simplex_noise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;

    i = mod_289(i);
    vec4 p = permute(permute(permute(
    i.z + vec4(0.0, i1.z, i2.z, 1.0))
    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
    + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    vec4 norm = taylor_inv_sqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    vec4 m = max(0.5 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 105.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

vec2 translate_point_by_angle(vec2 xy, float dist, float angle) {
    return xy + vec2(cos(angle), sin(angle)) * dist;
}

#ifdef PIXEL

uniform vec4 black = vec4(0, 0, 0, 1);
uniform vec4 red = vec4(1, 0, 0, 1);

uniform float value; // in [0, 1]

vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 fragment_position) {
    float y_normalization = love_ScreenSize.y / love_ScreenSize.x;
    vec2 pos = texture_coords.xy;

    pos *= vec2(1, y_normalization);
    vec2 center = vec2(0.5) * vec2(1, y_normalization);

    // fbm with both noise octaves and texture coord offset
    const int n_octaves = 5;
    const float intensity = 0.002;

    float persistence = 0.5;
    float lacunarity = 5.5;

    float amplitude = 1.0;
    float frequency = 0.2;
    float total = 0.0;
    float max_value = 0.0;

    for (int i = 0; i < n_octaves; i++) {
        total += simplex_noise(vec3(pos.xy, 0) * frequency * amplitude);
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;

        vec2 offset = vec2(cos(total * 2 * PI), sin(total * 2 * PI)) * amplitude * frequency * value * intensity;
        pos.xy += offset;
    }

    pos += total / max_value * 0.05;

    float value = 0;
    float dist = distance(pos, center);
    float eps = 0.15;
    float radius = (value) * (1 + 2 * eps) - eps;
    value = smoothstep(radius, radius + eps, dist * 2);

    return value * black + 2 * fwidth(value) * red * 2.1 * (1 - value);
}

#endif