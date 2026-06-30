uniform sampler2D light_intensity_texture; // rgba: color
uniform sampler2D light_direction_texture; // rg: normal
uniform sampler2D mask_texture; // r: is_mask

uniform sampler2D composite_texture; // r: intensity
uniform float strength;

vec4 effect(vec4 _0, sampler2D _1, vec2 texture_coords, vec2 frag_position) {
    float composite = texture(composite_texture, texture_coords).r;
    return vec4(max(composite, 1.0 - strength)); // blended multiplicatively
}