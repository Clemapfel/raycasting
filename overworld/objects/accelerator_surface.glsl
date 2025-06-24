#define MODE_TEXTURE 0
#define MODE_DERIVATIVE 1
#define MODE_NORMAL_MAP 2

#ifndef MODE
#error "In accelerator_surface.glsl: MODE unset, should be 0, 1, or 2"
#endif

#if MODE == MODE_TEXTURE

float worley_noise(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float dist = 1.0;
    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(i, j, k);

                vec3 p = n + g;
                p = fract(p * vec3(0.1031, 0.1030, 0.0973));
                p += dot(p, p.yxz + 19.19);
                vec3 o = fract((p.xxy + p.yzz) * p.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);
                dist = min(dist, d);
            }
        }
    }

    return 1 - dist;
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

    vec3 u = v * v * v * (v *(v * 6.0 - 15.0) + 10.0);

    float result = mix( mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,0.0)), v - vec3(0.0,0.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,0.0)), v - vec3(1.0,0.0,0.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,0.0)), v - vec3(0.0,1.0,0.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,0.0)), v - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( -1 + 2 * random_3d(i + vec3(0.0,0.0,1.0)), v - vec3(0.0,0.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,0.0,1.0)), v - vec3(1.0,0.0,1.0)), u.x),
    mix( dot( -1 + 2 * random_3d(i + vec3(0.0,1.0,1.0)), v - vec3(0.0,1.0,1.0)),
    dot( -1 + 2 * random_3d(i + vec3(1.0,1.0,1.0)), v - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );

    return (result + 1) / 2.;
}

uniform float elapsed;
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

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec2 uv = to_uv(frag_position);
    return vec4(gradient_noise(vec3(uv * 10, elapsed))); // R32F format
}

#elif MODE == MODE_DERIVATIVE

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec2 texel = vec2(1.0) / textureSize(img, 0);

    float tl = texture(img, texture_coords + texel * vec2(-1.0, -1.0)).r;
    float  t = texture(img, texture_coords + texel * vec2( 0.0, -1.0)).r;
    float tr = texture(img, texture_coords + texel * vec2( 1.0, -1.0)).r;
    float l  = texture(img, texture_coords + texel * vec2(-1.0,  0.0)).r;
    float c  = texture(img, texture_coords).r;
    float r  = texture(img, texture_coords + texel * vec2( 1.0,  0.0)).r;
    float bl = texture(img, texture_coords + texel * vec2(-1.0,  1.0)).r;
    float  b = texture(img, texture_coords + texel * vec2( 0.0,  1.0)).r;
    float br = texture(img, texture_coords + texel * vec2( 1.0,  1.0)).r;

    vec2 gradient = vec2(
        -tl - 2.0 * l - bl + tr + 2.0 * r + br,
        -tl - 2.0 * t - tr + bl + 2.0 * b + br
    );

    return vec4(gradient.x, gradient.y, c, c); // RG11B10 format
}

#elif MODE == MODE_NORMAL_MAP

vec3 hsv_to_rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#define PI 3.1415926535897932384626433832795

uniform vec2 player_position;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec4 data = texture(img, texture_coords);
    if (length(data.xy) == 0) discard;
    return vec4(data.xyx, 1.0);
}

#endif