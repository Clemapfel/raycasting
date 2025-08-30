float worley_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float minDist = 1.0;

    // Check surrounding 3x3x3 grid of cells
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 cellPos = i + neighbor;

                // Generate feature point within this cell (inlined hash)
                vec3 hashInput = vec3(dot(cellPos, vec3(127.1, 311.7, 74.7)),
                dot(cellPos, vec3(269.5, 183.3, 246.1)),
                dot(cellPos, vec3(113.5, 271.9, 124.6)));
                vec3 featurePoint = fract(sin(hashInput) * 43758.5453123);

                // Calculate distance from input point to feature point
                vec3 diff = neighbor + featurePoint - f;
                float dist = length(diff);

                minDist = min(minDist, dist);
            }
        }
    }

    return minDist;
}

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

// Returns vec2(noise, id) where 'id' is a stable random per-cell in [0,1).
vec2 worley_noise_with_id(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float minDist = 1.0;
    float id = 0.0;

    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(i, j, k);

                vec3 cell_p = n + g;
                vec3 hp = fract(cell_p * vec3(0.1031, 0.1030, 0.0973));
                hp += dot(hp, hp.yxz + 19.19);
                vec3 o = fract((hp.xxy + hp.yzz) * hp.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);

                if (d < minDist) {
                    minDist = d;
                    id = fract(dot(hp, vec3(12.9898, 78.233, 37.719)) * 43758.5453);
                }
            }
        }
    }

    return vec2(1.0 - minDist, id);
}

float smooth_max(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

float smooth_min(float a, float b, float k) {
    float h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
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

#define NUM_OCTAVES 6

// Each bubble gets a hue based on its Worley cell id, converted via LCh to sRGB.
vec3 hierarchical_bubble_texture(vec3 p) {
    vec3 color = vec3(0.0);
    float cumulative_mask = 0.0;
    float scale = 5 * NUM_OCTAVES;      // Start with largest bubbles
    float time_scale = 1.0;

    const float threshold = 0.6;
    vec2 offset = vec2(0);

    for (int i = 0; i < NUM_OCTAVES; i++) {
        // Generate bubbles at current scale and fetch a stable per-cell id
        vec2 w = worley_noise_with_id(vec3((p.xy + offset) * scale + vec2(0.0, p.z * 10), 0.0));
        float bubbles = w.x;
        float bubble_id = w.y; // in [0,1)

        float fraction = i / float(NUM_OCTAVES);

        // Mask for current bubble layer
        float eps = 0.015 * mix(0, 1, 1 - fraction);
        float current_threshold = mix(0.5, 0.6, (1 - fraction));
        float bubble_mask = smoothstep(current_threshold - eps, current_threshold + eps, bubbles);

        // Only add bubbles where previous larger bubbles don't exist
        float available_space = 1.0 - cumulative_mask;
        float mask = bubble_mask * available_space;

        // Map bubble id to hue; small octave-based offset to spread palette across octaves
        float hue = fract(bubble_id + float(i) / NUM_OCTAVES);
        // Keep L and C modest to avoid out-of-gamut colors


        float hue_threshold = mix(0.55, 0.59, pow(1 - fraction, 4));
        float hue_eps = 0.02;
        vec3 layer_color = lch_to_rgb(vec3(0.8 * smoothstep(hue_threshold - hue_eps, hue_threshold + hue_eps, bubbles), 1, hue));

        // Composite this octave's bubbles into the color
        color = mix(color, layer_color, bubble_mask);

        // Update cumulative mask to block smaller bubbles in occupied areas
        cumulative_mask = smooth_max(cumulative_mask, bubble_mask, 0.5);

        // Scale up for smaller bubbles (increase frequency each octave)
        scale /= 1.5;
        time_scale *= 0.5;
        offset += 2;
    }

    return color;
}

uniform float elapsed;
uniform float fraction;

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

#define PI 3.1415926535897932384626433832795

/*
vec3 sine_wave_sdf(vec2 p, float freq, float amp) {
    float halfWaveLength = PI / freq;
    float cellCenter = round(p.x / halfWaveLength) * halfWaveLength;
    float cellSign = sign(cos(p.x * freq));

    vec2 localP = vec2((p.x - cellCenter) * cellSign, p.y / amp);
    vec2 offset = vec2(-PI / (2.0 * freq), 0.0);

    vec2 candidateA, candidateB;

    // Find candidate A
    {
        vec2 pA = offset + localP;
        float freq2 = (freq * 0.5) * (freq * 0.5);
        float normalizer = 8.0 * freq2 * freq2;
        float x = sin(pA.x * freq * 0.5) / (freq * 0.5);
        float pp = ((-4.0 * pA.y - 4.0) * freq2 + 1.0) / normalizer;
        float qq = -x / normalizer;

        float q = -pp / 3.0;
        float r = qq / 2.0;
        float discriminant = q*q*q - r*r;
        float solution;

        if (discriminant < 0.0) {
            float a = -sign(r) * pow(abs(r) + sqrt(-discriminant), 1.0/3.0);
            float b = (a == 0.0) ? 0.0 : q/a;
            solution = a + b;
        } else {
            float theta = acos(r / pow(q, 1.5));
            solution = -2.0 * sqrt(q) * cos(theta / 3.0);
        }

        x = asin(clamp(solution * freq * 0.5, -1.0, 1.0)) / (freq * 0.5);
        candidateA = -offset + vec2(x, -cos(freq * 0.5 * 2.0 * x));
    }

    // Find candidate B
    {
        vec2 pB = offset - localP;
        float freq2 = (freq * 0.5) * (freq * 0.5);
        float normalizer = 8.0 * freq2 * freq2;
        float x = sin(pB.x * freq * 0.5) / (freq * 0.5);
        float pp = ((-4.0 * pB.y - 4.0) * freq2 + 1.0) / normalizer;
        float qq = -x / normalizer;

        float q = -pp / 3.0;
        float r = qq / 2.0;
        float discriminant = q*q*q - r*r;
        float solution;

        if (discriminant < 0.0) {
            float a = -sign(r) * pow(abs(r) + sqrt(-discriminant), 1.0/3.0);
            float b = (a == 0.0) ? 0.0 : q/a;
            solution = a + b;
        } else {
            float theta = acos(r / pow(q, 1.5));
            solution = -2.0 * sqrt(q) * cos(theta / 3.0);
        }

        x = asin(clamp(solution * freq * 0.5, -1.0, 1.0)) / (freq * 0.5);
        candidateB = offset - vec2(x, -cos(freq * 0.5 * 2.0 * x));
    }

    vec2 bestCandidate = (length(localP - candidateB) < length(localP - candidateA))
    ? candidateB : candidateA;

    // Newton refinement
    vec3 state = vec3(bestCandidate, localP.x - localP.y);

    vec3 gradient = vec3(
    2.0 * (state.x - localP.x) + state.z * (-cos(state.x * freq) * freq),
    2.0 * (state.y - localP.y) - state.z,
    state.y + sin(state.x * freq)
    );

    mat3 hessian = mat3(
    2.0 - state.z * (-sin(state.x * freq) * freq * freq), 0.0, cos(state.x * freq) * freq,
    0.0, 2.0, 1.0,
    -cos(state.x * freq) * freq, -1.0, 0.0
    );

    state -= inverse(hessian) * gradient;
    vec2 refinedPoint = vec2(state.x, -sin(state.x * freq) * amp);

    float signedDistance = length(vec2(localP.x, localP.y * amp) - refinedPoint) * sign(localP.y * amp + sin(localP.x * freq) * amp);
    vec2 globalPoint = vec2(refinedPoint.x * cellSign + cellCenter, refinedPoint.y);

    return vec3(signedDistance, globalPoint);
}
*/

float sine_wave_sdf(vec2 point, float frequency, float amplitude) {
    float value = amplitude * sin(frequency * point.x);
    return (point.y - value);
}

vec2 sine_wave_sdf_gradient(vec2 point, float frequency, float amplitude) {
    float sine_val = amplitude * sin(frequency * point.x);
    float diff = point.y - sine_val;
    float sign_diff = sign(diff);

    // Analytical gradient of abs(point.y - amplitude * sin(frequency * point.x))
    vec2 gradient;
    gradient.x = -sign_diff * amplitude * frequency * cos(frequency * point.x);
    gradient.y = sign_diff;

    return gradient;
}

vec2 rotate(vec2 v, float angle, vec2 origin) {
    float s = sin(angle);
    float c = cos(angle);

    v += origin;
    v *= mat2(c, -s, s, c);
    v -= origin;
    return v;
}



float dirac(float x) {
    float a = 0.045 * exp(log(1.0 / 0.045 + 1.0) * x) - 0.045;
    float b = 0.045 * exp(log(1.0 / 0.045 + 1.0) * (1.0 - x)) - 0.045;
    const float t = 5.81894409826698685315796808094;
    return t * min(a, b);
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {

    const float n_tiles = 6.0;
    const float scale = 5.0;
    const float frequency = 4.0;

    vec2 point = to_uv(frag_position);

    float tileIndex = floor(point.x * n_tiles);
    float direction = mod(tileIndex, 2.0) == 0.0 ? -1.0 : 1.0;
    float side = mod(tileIndex, 1) >= 0.5 ? -1.0 : 1.0;

    point.y += step(0, direction);
    point.x = fract(point.x * n_tiles);

    point = rotate(point, radians(90.0), vec2(0.5));
    point += vec2(0.0, -0.5);
    point *= vec2(2.0 * PI, scale);

    float amplitude = sin(2.0 * elapsed) * fraction;

    // Raw signed distance to the sine curve (keep this un-thresholded SDF)
    float d = sine_wave_sdf(point, frequency, amplitude * direction);

    const float speed = 0.2;
    // Use the raw SDF (d) for texture translation as before
    vec2 translated_coords = texture_coords + vec2(side * d * fraction * speed, 0.0);
    float weight = mix(1.0, gaussian(0.5 * distance(translated_coords, texture_coords), 4.0), fraction);
    vec4 texel = texture(img, translated_coords - camera_offset / love_ScreenSize.xy) * weight; // img is clamp zero wrapping

    // Build the thick white stripe from the raw SDF
    const float threshold = 0.9;
    float eps = 0.05; // thickness/softness of the white band
    float line = 1.0 - smoothstep(threshold - eps, threshold + eps, abs(d));

    float background_epsilon = 0.05;

    // Thin black outline just around the white stripe boundary.
    // Use a narrow band centered at |d| == threshold, width ~ 1-2 pixels via fwidth.
    float outline_eps = background_epsilon; // tune for desired outline thickness (in pixels)
    float outline_threshold = 1;
    float line_outline = 1 - smoothstep(outline_threshold - outline_eps, outline_threshold + outline_eps, abs(d));


    // Composite texel with the warped sample as before
    texel = mix(texel, vec4(line), 1.0 - weight);

    vec2 noise_coords = to_uv(frag_position);
    float noise_scale = 1.0;
    vec3 noise = hierarchical_bubble_texture(vec3(noise_coords, elapsed / 20.0));

    const float n_background_stripes = 12;
    vec2 background_offset = vec2(elapsed / 20, 0);
    vec2 background_pos = rotate(to_uv(frag_position) + background_offset, radians(45), vec2(0.5));
    float background_stripe_id = floor(background_pos.x * n_background_stripes);
    background_pos = fract(background_pos * n_background_stripes);

    // Stripe coverage: 1.0 inside stripe, fades to 0.0 near boundaries over 'background_epsilon'
    float background_stripe_mask =
    smoothstep(0.0, background_epsilon, background_pos.x) *
    smoothstep(0.0, background_epsilon, 1.0 - background_pos.x);

    vec4 background = vec4(vec3(background_stripe_mask * lch_to_rgb(vec3(0.8, 1, background_stripe_id / n_background_stripes))), 1.0);

    // Foreground: white where the thick stripe (dist) is present, black where the thin outline mask is present.
    // Alpha includes either the white stripe or the black outline.
    const vec3 white = vec3(1);
    const vec3 black = vec3(0);

    float alpha = max(line, line_outline);
    vec3 inverted_background = white * (1 - alpha);

    return vec4(inverted_background + texel.rgb * background.rgb * line + black * line_outline, 1);

}