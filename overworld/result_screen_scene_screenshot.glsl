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

uniform float elapsed;
uniform float fraction; // 0-1 fade in
uniform float transition_fraction; // 0-1 fade out

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

float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

float sine_wave_sdf(vec2 point, float frequency, float amplitude) {
    float value = amplitude * sin(frequency * point.x);
    return (point.y - value);
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

uniform vec4 player_color = vec4(1, 0, 1, 1);

#ifndef SHADER_DERIVATIVES
#error "In result_screen_scene_screenshot.glsl: `SHADER_DERIVATIVES` undefined, should be true or false"
#endif

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {

    const float n_tiles = 6.0;
    const float scale = 6.0;
    const float frequency = 4.0;

    vec2 point = to_uv(frag_position);

    point = rotate(point, radians(45), vec2(0.5));
    point += vec2(elapsed / 30, 0);

    float aspect_ratio = (love_ScreenSize.x / love_ScreenSize.y) / (800.0 / 600.0);
    if (aspect_ratio > 1.0) {
        point.x *= aspect_ratio;
    } else {
        point.y /= aspect_ratio;
    }

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

    const float speed = 1;
    // Use the raw SDF (d) for texture translation as before
    vec2 translated_coords = texture_coords + vec2(side * d * fraction * speed, 0.0);
    float weight = mix(1.0, gaussian(0.5 * distance(translated_coords, texture_coords), 4.0), fraction);
    vec4 texel = texture(img, translated_coords - camera_offset / love_ScreenSize.xy) * weight; // img is clamp zero wrapping

    // Build the thick white stripe from the raw SDF
    const float threshold = 0.9;
    float eps = 0.05 + 0.5 * threshold * transition_fraction; // thickness/softness of the white band
    float line = 1.0 - smoothstep(threshold - eps, threshold + eps, abs(d));


    // Thin black outline just around the white stripe boundary.
    // Use a narrow band centered at |d| == threshold, width ~ 1-2 pixels via fwidth.
    float outline_threshold = 0.98;
    float outline_eps = 0.05 * 2 + 0.5 * outline_threshold * transition_fraction; // tune for desired outline thickness (in pixels)
    float line_outline = 1 - smoothstep(outline_threshold - outline_eps, outline_threshold + outline_eps, abs(d));

    // Foreground: white where the thick stripe (dist) is present, black where the thin outline mask is present.
    // Alpha includes either the white stripe or the black outline.
    const vec3 black = vec3(0);

    float alpha = max(line, line_outline);
    texel = texture(img, texture_coords) * (1 - fraction);
    texel *= (1 - alpha);

    vec3 outline_color = vec3(1, 0, 1);
    vec3 outline = (line_outline - line) * player_color.rgb;

    return vec4(texel.rgb + black * line_outline + outline, 1);
}