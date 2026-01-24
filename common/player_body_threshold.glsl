#ifdef PIXEL

uniform bool use_highlight = true;
uniform float highlight_strength = 1;

uniform bool use_shadow = true;
uniform float shadow_strength = 1;

uniform float threshold = 0.4;
uniform float smoothness = 0.3;

float finalize(float x) {
    return smoothstep(
        threshold - smoothness,
        threshold + smoothness,
        x
    );
}

uniform vec4 body_color;
uniform vec4 outline_color;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 screen_coords)
{
    vec2 pixel_size = 1.0 / love_ScreenSize.xy;

    // compute gradient using sobel kernel
    // Sample raw values
    float tl_raw = texture(tex, texture_coordinates + vec2(-1.0, -1.0) * pixel_size).r;
    float tm_raw = texture(tex, texture_coordinates + vec2( 0.0, -1.0) * pixel_size).r;
    float tr_raw = texture(tex, texture_coordinates + vec2( 1.0, -1.0) * pixel_size).r;
    float ml_raw = texture(tex, texture_coordinates + vec2(-1.0,  0.0) * pixel_size).r;
    float mr_raw = texture(tex, texture_coordinates + vec2( 1.0,  0.0) * pixel_size).r;
    float bl_raw = texture(tex, texture_coordinates + vec2(-1.0,  1.0) * pixel_size).r;
    float bm_raw = texture(tex, texture_coordinates + vec2( 0.0,  1.0) * pixel_size).r;
    float br_raw = texture(tex, texture_coordinates + vec2( 1.0,  1.0) * pixel_size).r;

    // Apply box blur (average of all 8 neighbors)
    float blurred = (tl_raw + tm_raw + tr_raw + ml_raw + mr_raw + bl_raw + bm_raw + br_raw) / 8.0;

    // Finalize only for gradient computation
    float tl = finalize(tl_raw);
    float tm = finalize(tm_raw);
    float tr = finalize(tr_raw);
    float ml = finalize(ml_raw);
    float mr = finalize(mr_raw);
    float bl = finalize(bl_raw);
    float bm = finalize(bm_raw);
    float br = finalize(br_raw);

    // Compute gradients with finalized values
    float gradient_x = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
    float gradient_y = -tl - 2.0 * tm - tr + bl + 2.0 * bm + br;

    float magnitude = min(length(vec2(gradient_x, gradient_y)), 1);

    vec4 body = (finalize(texture(tex, texture_coordinates).r)) * body_color;
    return mix(body, outline_color, magnitude);
}

#endif