
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
    return abs(point.y - value);
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

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    // Start from UVs
    vec2 point = texture_coords;

    // Repeat along X: wrap the x coordinate before rotating.
    // tiles controls how many repeats across the screen width.
    float tiles = 10.0;
    const float scale = 5;
    const float frequency = 4;
    float tileIndex = floor(point.x * tiles);
    float direction = (mod(tileIndex, 2.0) == 0.0) ? -1.0 : 1.0;
    point.y += step(0, direction);
    point.x = fract(point.x * tiles);

    // Rotate 90 degrees around the center
    point = rotate(point, radians(90.0), vec2(0.5));

    // Center vertically so the wave fits when amplitude = 1
    point += vec2(0.0, -0.5);

    // Scale:
    // - Make x span exactly one full 2π period per tile so the curve tiles seamlessly.
    // - Preserve previous y scaling.
    point = vec2(point.x * (2.0 * PI), point.y * scale);

    // Animated amplitude; max amplitude (1.0) still fits the tiling
    float amp = sin(2 * elapsed);

    float dist = sine_wave_sdf(point, frequency, amp * direction);
    vec3 col = lch_to_rgb(vec3(0.8, 1, dist / tiles));

    vec4 texel = texture(img, texture_coords + pow(1 + fraction, 2) * dist * 1 / love_ScreenSize.xy);

    vec2 gradient = sine_wave_sdf_gradient(point, 3.0, amp).yy; // only use gradient away from curve

    const float threshold = 0.9;
    const float eps = 0.2;
    dist = smoothstep(threshold - eps, threshold + eps, abs(dist));

    return texel;
}