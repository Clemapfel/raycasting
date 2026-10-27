#version 300 es
precision highp float;

uniform vec2 rt_ScreenSize;
in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

uniform float elapsed;
uniform vec2 cursor_position;
uniform float cursor_visible;

#define PI 3.14159265358979323846

// ------------------------------------------------------------
// Hash and noise
// ------------------------------------------------------------

float hash21(vec2 p) {
    return fract(
    sin(dot(p, vec2(127.1, 311.7))) *
    43758.5453123
    );
}

vec2 hash22(vec2 p) {
    vec2 q = vec2(
    dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3))
    );

    return fract(sin(q) * 43758.5453123);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(
    mix(a, b, u.x),
    mix(c, d, u.x),
    u.y
    );
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 4; i++) {
        value += amplitude * value_noise(p);

        p = mat2(
        1.6,  1.2,
        -1.2,  1.6
        ) * p + vec2(13.1, 7.7);

        amplitude *= 0.5;
    }

    return value;
}

// ------------------------------------------------------------
// Voronoi edge noise
//
// Produces irregular polygon boundaries. These become the
// fractured stone edges and the larger branching mineral veins.
// ------------------------------------------------------------

float edge_pair_hash(vec2 a, vec2 b) {
    // Sort the two cell IDs so both sides of an edge
    // get the same vein-width selection.
    if (
    a.x > b.x ||
    (abs(a.x - b.x) < 0.001 && a.y > b.y)
    ) {
        vec2 temp = a;
        a = b;
        b = temp;
    }

    return hash21(a * 17.17 + b * 31.73);
}

vec3 cellular_edge(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);

    float nearestDist = 1e9;
    vec2 nearestR = vec2(0.0);
    vec2 nearestID = vec2(0.0);

    // Find the nearest feature point.
    for (int y = -1; y <= 1; y++) {
        for (int xOffset = -1; xOffset <= 1; xOffset++) {
            vec2 g = vec2(float(xOffset), float(y));
            vec2 id = n + g;

            vec2 offset = 0.15 + 0.70 * hash22(id);

            vec2 r = g + offset - f;
            float d = dot(r, r);

            if (d < nearestDist) {
                nearestDist = d;
                nearestR = r;
                nearestID = id;
            }
        }
    }

    // Find the closest Voronoi boundary.
    float edgeDist = 1e9;
    vec2 edgeID = nearestID;

    for (int y = -1; y <= 1; y++) {
        for (int xOffset = -1; xOffset <= 1; xOffset++) {
            vec2 g = vec2(float(xOffset), float(y));
            vec2 id = n + g;

            if (all(equal(id, nearestID))) {
                continue;
            }

            vec2 offset = 0.15 + 0.70 * hash22(id);
            vec2 r = g + offset - f;

            vec2 diff = r - nearestR;
            float diffLength = max(length(diff), 0.0001);

            float d = dot(
            0.5 * (nearestR + r),
            diff / diffLength
            );

            if (d < edgeDist) {
                edgeDist = d;
                edgeID = id;
            }
        }
    }

    float pairRandom = edge_pair_hash(nearestID, edgeID);
    float cellRandom = hash21(nearestID);

    return vec3(max(edgeDist, 0.0), pairRandom, cellRandom);
}

// ------------------------------------------------------------
// Main shader
// ------------------------------------------------------------

void main() {
    vec2 uv = rt_TextureCoords;

    float aspect = rt_ScreenSize.x /
    max(rt_ScreenSize.y, 1.0);

    // Keep the pattern approximately uniform in screen space.
    uv.x *= aspect;

    // --------------------------------------------------------
    // Organic domain distortion
    // --------------------------------------------------------

    vec2 warp = vec2(
    fbm(uv * 5.2 + vec2(2.4, 9.2)),
    fbm(uv * 5.2 + vec2(8.7, 1.4))
    ) - 0.5;

    // A little extra distortion creates nonuniform crack paths.
    vec2 warpedUV = uv + warp * 0.075;

    // --------------------------------------------------------
    // Pale gray stone matrix
    // --------------------------------------------------------

    float cloud = fbm(
    uv * vec2(13.0, 17.0) + vec2(4.1, 7.2)
    );

    float grain = value_noise(
    uv * vec2(230.0, 270.0)
    );

    vec3 stoneDark = vec3(0.61, 0.62, 0.61);
    vec3 stoneLight = vec3(0.82, 0.81, 0.78);

    vec3 stone = mix(
    stoneDark,
    stoneLight,
    smoothstep(0.22, 0.78, cloud)
    );

    // Fine mineral grain and subtle surface mottling.
    stone += (grain - 0.5) * 0.045;

    // --------------------------------------------------------
    // Secondary cracks: small polygonal fragments
    // --------------------------------------------------------

    vec3 fineCell = cellular_edge(
    (uv + warp * 0.018) * 19.0 +
    vec2(2.4, 8.3)
    );

    float fineCrack = 1.0 - smoothstep(
    0.012,
    0.040,
    fineCell.x
    );

    vec3 color = stone;

    // Dark seams separating the small pale stone fragments.
    color = mix(
    color,
    vec3(0.19, 0.17, 0.15),
    fineCrack * 0.68
    );

    // A faint, chalky lip next to some fine fractures.
    float fineRim = smoothstep(
    0.025, 0.045, fineCell.x
    ) * (
    1.0 - smoothstep(0.045, 0.065, fineCell.x)
    );

    color += vec3(0.035, 0.030, 0.022) * fineRim;

    // --------------------------------------------------------
    // Primary branching septarian veins
    // --------------------------------------------------------

    const float MAIN_SCALE = 8.5;

    vec3 mainCell = cellular_edge(
    warpedUV * MAIN_SCALE
    );

    float edgeDist = mainCell.x;
    float edgeRandom = mainCell.y;

    // Only some polygon boundaries become wide mineral veins.
    // The remaining boundaries stay as narrow dark fractures.
    float majorVein = smoothstep(
    0.68,
    0.86,
    edgeRandom
    );

    float width = mix(
    0.016,
    0.145,
    majorVein
    );

    // Give the veins slight natural variations in thickness.
    float widthNoise = value_noise(
    warpedUV * vec2(17.0, 29.0) +
    vec2(3.0, 6.0)
    );

    width *= 0.82 + 0.36 * widthNoise;

    // Thin dark cracks remain visible along smaller boundaries.
    float hairline = 1.0 - smoothstep(
    0.004,
    0.022,
    edgeDist
    );

    color = mix(
    color,
    vec3(0.15, 0.105, 0.070),
    hairline * (1.0 - majorVein * 0.88)
    );

    // Layered mineral bands.
    float outerVein = (
    1.0 - smoothstep(
    width * 0.86,
    width * 1.06,
    edgeDist
    )
    ) * majorVein;

    float brownBody = (
    1.0 - smoothstep(
    width * 0.58,
    width * 0.79,
    edgeDist
    )
    ) * majorVein;

    float amberBand = (
    smoothstep(
    width * 0.25,
    width * 0.34,
    edgeDist
    ) *
    (
    1.0 - smoothstep(
    width * 0.53,
    width * 0.66,
    edgeDist
    )
    )
    ) * majorVein;

    float creamRim = (
    smoothstep(
    width * 0.70,
    width * 0.78,
    edgeDist
    ) *
    (
    1.0 - smoothstep(
    width * 0.89,
    width * 1.00,
    edgeDist
    )
    )
    ) * majorVein;

    float darkCore = (
    1.0 - smoothstep(
    width * 0.12,
    width * 0.23,
    edgeDist
    )
    ) * majorVein;

    // Subtle striations inside the brown mineral.
    float striation = value_noise(
    warpedUV * MAIN_SCALE * vec2(4.0, 12.0) +
    vec2(6.2, 1.7)
    );

    vec3 outerColor = vec3(0.105, 0.070, 0.045);

    vec3 brownColor = vec3(0.30, 0.17, 0.085);
    brownColor += (striation - 0.5) * 0.065;

    vec3 amberColor = vec3(0.72, 0.42, 0.145);
    amberColor += (striation - 0.5) * 0.10;

    vec3 creamColor = vec3(0.91, 0.79, 0.57);
    vec3 coreColor = vec3(0.12, 0.075, 0.040);

    // Outside shadow -> brown vein -> amber band.
    color = mix(color, outerColor, outerVein);
    color = mix(color, brownColor, brownBody);
    color = mix(color, amberColor, amberBand);

    // Thin pale mineral outlines create the lightning-like edges.
    color = mix(color, creamColor, creamRim);

    // The deep brown central seam gives the veins depth.
    color = mix(color, coreColor, darkCore);

    // A fine amber streak within the darkest part of the vein.
    float centerAmber = (
    1.0 - smoothstep(
    width * 0.035,
    width * 0.095,
    edgeDist
    )
    ) * majorVein;

    color = mix(
    color,
    vec3(0.53, 0.285, 0.095),
    centerAmber * 0.75
    );

    // --------------------------------------------------------
    // Cursor-responsive mineral highlights
    // --------------------------------------------------------

    vec2 cursorUV = cursor_position /
    max(rt_ScreenSize, vec2(1.0));

    cursorUV.x *= aspect;

    vec2 toCursor = uv - cursorUV;
    float cursorDistance = length(toCursor);

    const float SIGMA = 0.20;

    float falloff = cursor_visible * exp(
    -(cursorDistance * cursorDistance) /
    (2.0 * SIGMA * SIGMA)
    );

    float edgeHighlight = 1.0 - smoothstep(
    0.015,
    0.13,
    edgeDist
    );

    float shimmer = 0.96 + 0.04 * sin(elapsed * 0.8);

    color += vec3(0.085, 0.052, 0.023) *
    falloff *
    (0.20 + 0.80 * edgeHighlight) *
    shimmer;

    rt_FragColor = vec4(
    clamp(color, 0.0, 1.0),
    1.0
    );
}
