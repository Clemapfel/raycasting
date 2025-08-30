#define WORLEY_CELL(gx, gy, gz) g = vec3(gx, gy, gz); cell_pos = n + g; cell_pos = fract(cell_pos * hash_mul); cell_pos += dot(cell_pos, cell_pos.yxz + hash_add); o = fract((cell_pos.xxy + cell_pos.yzz) * cell_pos.zyx); delta = g + o - f; d = dot(delta, delta); min_dist = min(min_dist, d);

float worley_noise_macro(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float min_dist = 1.0;
    vec3 g, cell_pos, o, delta;
    float d;

    const vec3 hash_mul = vec3(0.1031, 0.1030, 0.0973);
    const float hash_add = 19.19;

    WORLEY_CELL(-1.0, -1.0, -1.0)
    WORLEY_CELL(-1.0, -1.0,  0.0)
    WORLEY_CELL(-1.0, -1.0,  1.0)
    WORLEY_CELL(-1.0,  0.0, -1.0)
    WORLEY_CELL(-1.0,  0.0,  0.0)
    WORLEY_CELL(-1.0,  0.0,  1.0)
    WORLEY_CELL(-1.0,  1.0, -1.0)
    WORLEY_CELL(-1.0,  1.0,  0.0)
    WORLEY_CELL(-1.0,  1.0,  1.0)
    WORLEY_CELL( 0.0, -1.0, -1.0)
    WORLEY_CELL( 0.0, -1.0,  0.0)
    WORLEY_CELL( 0.0, -1.0,  1.0)
    WORLEY_CELL( 0.0,  0.0, -1.0)
    WORLEY_CELL( 0.0,  0.0,  0.0)
    WORLEY_CELL( 0.0,  0.0,  1.0)
    WORLEY_CELL( 0.0,  1.0, -1.0)
    WORLEY_CELL( 0.0,  1.0,  0.0)
    WORLEY_CELL( 0.0,  1.0,  1.0)
    WORLEY_CELL( 1.0, -1.0, -1.0)
    WORLEY_CELL( 1.0, -1.0,  0.0)
    WORLEY_CELL( 1.0, -1.0,  1.0)
    WORLEY_CELL( 1.0,  0.0, -1.0)
    WORLEY_CELL( 1.0,  0.0,  0.0)
    WORLEY_CELL( 1.0,  0.0,  1.0)
    WORLEY_CELL( 1.0,  1.0, -1.0)
    WORLEY_CELL( 1.0,  1.0,  0.0)
    WORLEY_CELL( 1.0,  1.0,  1.0)

    return 1.0 - sqrt(min_dist);
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

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {

    const float n_tiles = 10.0;
    const float scale = 5;
    const float frequency = 4;

    vec2 point = texture_coords;

    float tileIndex = floor(point.x * n_tiles);
    float direction = mod(tileIndex, 2.0) == 0.0 ? -1.0 : 1.0;
    float side = mod(tileIndex, 1) >= 0.5 ? -1.0 : 1.0;

    point.y += step(0, direction);
    point.x = fract(point.x * n_tiles);

    point = rotate(point, radians(90.0), vec2(0.5));
    point += vec2(0.0, -0.5);
    point *= vec2(2 * PI, scale);

    float amplitude = sin(2 * elapsed) * fraction;
    float dist = sine_wave_sdf(point, frequency, amplitude * direction);

    const float speed = 0.2;
    vec2 translated_coords = texture_coords + vec2(side * dist * fraction * speed, 0);
    float weight = mix(1, gaussian(0.5 * distance(translated_coords, texture_coords), 4), fraction);
    vec4 texel = texture(img, translated_coords) * weight; // img is clamp zero wrapping

    const float threshold = 0.9;
    float eps = mix(0.05, 0.5, (1 - fraction));
    dist = 1 - smoothstep(threshold - eps, threshold + eps, abs(dist));
    texel = mix(texel, vec4(dist), 1 - weight);

    return texel;
}