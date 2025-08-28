
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

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 frag_position) {
    vec4 texel = texture(img, texture_coords);
    return texel - vec4(vec3(0), fraction);
}