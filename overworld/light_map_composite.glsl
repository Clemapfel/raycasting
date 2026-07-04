uniform sampler2D composite_texture; // r: intensity
uniform sampler2D mask; // r: mask
uniform float strength;

vec4 effect(vec4 _0, sampler2D _1, vec2 texture_coords, vec2 frag_position) {
    float composite = texture(composite_texture, texture_coords).r;
    float mask = texture(mask, texture_coords).r;
    return vec4(max(composite, 1.0 - strength * mask)); // blended multiplicitavely
}