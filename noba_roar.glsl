#ifdef PIXEL

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

    return mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb_to_hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float gaussian(float x, float sigma)
{
    return exp(-1 * (x * x) / (2.0 * sigma * sigma));
}

uniform float saturation_fraction;
uniform float vignette_fraction;
uniform float ripple_fraction;
uniform float elapsed;

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 frag_position) {

    vec2 size = love_ScreenSize.xy;
    vec2 normalization = size / max(size.x, size.y);
    float dist = distance(
        texture_coords * normalization,
        vec2(0.5) * normalization
    );

    // vignette
    float vignette = gaussian(dist, 1 - vignette_fraction);

    // ripple
    const float ripple_scale = 15;
    const float ripple_speed = 2.5;
    const float ripple_magnitude = 1.0 / 2.2;

    vec2 delta = texture_coords * normalization - vec2(0.5) * normalization;
    delta *= max(love_ScreenSize.x, love_ScreenSize.y);
    delta = normalize(delta);

    float noise = gradient_noise(vec3(delta.x * ripple_scale, delta.y * ripple_scale, elapsed * ripple_speed));
    float offset = gaussian(1 - dist, ripple_magnitude * ripple_fraction * noise);

    // saturation ramp
    vec4 texel = texture(image, texture_coords) * color;
    vec3 as_hsv = rgb_to_hsv(texel.rgb);
    as_hsv.y = max(as_hsv.y - saturation_fraction, 0);
    vec3 as_rgb = hsv_to_rgb(as_hsv);

    return vec4(min(as_rgb * (vignette + offset), vec3(1)), texel.a);
}
#endif