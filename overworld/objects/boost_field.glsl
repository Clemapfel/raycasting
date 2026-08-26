#pragma language glsl4

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

float mix_periodic(float a, float b, float t) {
    float tri = 1.0 - abs(2.0 * fract(t) - 1.0); // triangle wave: 0,1,0
    float w = smoothstep(0.0, 1.0, tri);
    return mix(a, b, w);
}

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

    vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
    mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
    mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
    dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );
}

uniform float elapsed;
uniform float velocity_factor;
uniform float opacity;

uniform mat4x4 screen_to_world_transform;
vec2 to_world_position(vec2 xy) {
    vec4 result = screen_to_world_transform * vec4(xy, 0.0, 1.0);
    return result.xy / result.w;
}

uniform int path_n_segments;       // # nodes - 1
uniform float path_inverse_length; // 1.0 / length
uniform sampler2D path_xy_and_tangent; // xy: node position, zw: tangent
uniform sampler2D path_segment_and_fraction; // x: segment length, y: fraction

float get_fraction(vec2 xy, out vec2 out_tangent) {
    float min_dist_sq = 3.402823466e+38; // Max float
    float best_frac = 0.0;
    out_tangent = vec2(1.0, 0.0); // Fallback

    for (int i = 0; i < path_n_segments; ++i) {
        vec4 geom = texelFetch(path_xy_and_tangent, ivec2(i, 0), 0).xyzw;
        vec2 metrics = texelFetch(path_segment_and_fraction, ivec2(i, 0), 0).xy;

        // Vector from segment start to the query point
        vec2 ap = xy - geom.xy;

        // Project point onto the infinite line, clamp to segment endpoints
        float t = clamp(dot(ap, geom.zw), 0.0, metrics.x);

        // Find the closest point on this specific segment
        vec2 closest = geom.xy + geom.zw * t;

        // Calculate squared distance (skip sqrt for comparison)
        vec2 diff = xy - closest;
        float dist_sq = dot(diff, diff);

        // Update if this is the closest segment found so far
        if (dist_sq < min_dist_sq) {
            min_dist_sq = dist_sq;

            // Calculate final fraction: fraction at start of segment + fraction along segment
            best_frac = metrics.y + (t * path_inverse_length);
            out_tangent = geom.zw;
        }
    }

    return best_frac;
}

vec4 effect(vec4 vertex_color, sampler2D _, vec2 texture_coordinates, vec2 frag_position) {
    float time = elapsed / 2.0;

    vec2 uv = to_world_position(frag_position);

    vec2 dxy;
    float hue = get_fraction(uv.xy, dxy);

    uv = uv / 12.0;
    uv.xy -= velocity_factor * dxy * elapsed;

    float hue_noise = (gradient_noise(vec3(uv.xy, time)) + 1.0) / 2.0;
    float lightness_noise = (gradient_noise(vec3(uv.y, time, uv.x)) + 1.0) / 2.0;

    return vec4(lch_to_rgb(vec3(
        0.8 + mix(-0.35, -0.0, lightness_noise),
        1.2 + mix(-0.0, -0.3, lightness_noise),
        hue + mix(-0.05, 0.05, hue_noise)
    )), opacity * mix(0.2, 1.0, 1.0 - hue_noise));
}