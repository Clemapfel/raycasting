#pragma language glsl4

struct Sprite {
    vec2 top_left;
    vec2 top_right;
    vec2 bottom_right;
    vec2 bottom_left;

    vec2 texture_top_left;
    vec2 texture_top_right;
    vec2 texture_bottom_right;
    vec2 texture_bottom_left;

    vec2 origin;
    bool flip_horizontally;
    bool flip_vertically;
    float angle;
};

vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

layout(std430) readonly buffer SpriteBuffer {
    Sprite sprites[];
}; // size: instance count

#ifdef VERTEX

varying vec2 texture_coords;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    uint instance_id = love_InstanceID;
    Sprite sprite = sprites[instance_id];

    uint vertex_i = gl_VertexID.x;

    vec2 position_offsets[4] = vec2[4](
        sprite.top_left,
        sprite.top_right,
        sprite.bottom_right,
        sprite.bottom_left
    );

    vec2 offset = position_offsets[vertex_i];

    vec2 origin = sprite.origin;
    offset -= origin;
    offset = rotate(offset, sprite.angle);
    offset += origin;
    vertex_position.xy += offset;

    vec2 texture_offsets[4] = vec2[4](
        sprite.texture_top_left,
        sprite.texture_top_right,
        sprite.texture_bottom_right,
        sprite.texture_bottom_left
    );
    texture_coords = texture_offsets[vertex_i];

    if (sprite.flip_horizontally) {
        texture_coords.x = sprite.texture_top_right.x - (texture_coords.x - sprite.texture_top_left.x);
    }

    if (sprite.flip_vertically) {
        texture_coords.y = sprite.texture_bottom_left.y - (texture_coords.y - sprite.texture_top_left.y);
    }

    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

#ifdef APPLY_ANTI_ALIAS_CORRECTION

varying vec2 texture_coords;
uniform vec2 texture_resolution; // resolution of spritesheet

vec4 effect(vec4 color, Image tex, vec2 _, vec2 screen_coords)
{
    vec2 uv = texture_coords;

    // adapted from: https://github.com/Nikaoto/subpixel/blob/master/subpixel_grad.frag
    vec2 texel_size = vec2(1) / texture_resolution ;

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);
    vec2 fw = abs(ddx) + abs(ddy);

    vec2 xy = uv * texture_resolution;
    vec2 xy_rounded = vec2(round(xy.x + 0.5), round(xy.y + 0.5)) - vec2(0.5);
    vec2 f = xy - xy_rounded;
    vec2 f_uv = f * texel_size - vec2(0.5) * texel_size;

    f = clamp(f_uv / fw + vec2(0.5), 0.0, 1.0);
    uv = xy_rounded * texel_size;
    return color * textureGrad(tex, uv + f * texel_size, ddx, ddy);

    /*
    vec2 fw = fwidth(uv);
    if (fw.x < 1.0/texture_resolution.x && fw.y < 1.0/texture_resolution.y) {

        vec2 mins = (uv - 0.5 * fw) * texture_resolution;
        vec2 maxes = (uv + 0.5 * fw) * texture_resolution;

        if (mins.x >= floor(uv.x * texture_resolution.x) && maxes.x < ceil(uv.x * texture_resolution.x)) {
            uv.x = (floor(mins.x) + 0.5) / texture_resolution.x;
        }
        else
        {
            float right_side_coverage = fract(maxes.x);
            float sum = maxes.x - mins.x;
            float left_offset = (right_side_coverage / sum);
            float u_tex_center = floor(mins.x) + 0.5;
            uv.x = (u_tex_center + left_offset) / texture_resolution.x;
        }

        if (mins.y >= floor(uv.y * texture_resolution.y) && maxes.y < ceil(uv.y * texture_resolution.y)) {
            uv.y = (floor(mins.y) + 0.5) / texture_resolution.y;
        }
        else
        {
            float bottom_side_coverage = fract(maxes.y);
            float sum = maxes.y - mins.y;
            float top_offset = bottom_side_coverage / sum;
            float u_tex_center = floor(mins.y) + 0.5;
            uv.y = (u_tex_center + top_offset) / texture_resolution.y;
        }
    }

    vec2 xy = texture_resolution * uv - 0.5;
    vec2 f = fract(xy);
    vec2 xy_floor = floor(xy);

    vec4 p00 = texture(tex, (xy_floor + vec2(0.0, 0.0) + 0.5) / texture_resolution);
    vec4 p10 = texture(tex, (xy_floor + vec2(1.0, 0.0) + 0.5) / texture_resolution);
    vec4 p01 = texture(tex, (xy_floor + vec2(0.0, 1.0) + 0.5) / texture_resolution);
    vec4 p11 = texture(tex, (xy_floor + vec2(1.0, 1.0) + 0.5) / texture_resolution);

    vec4 pX0 = p00 * (1.0 - f.x) + p10 * f.x;
    vec4 pX1 = p01 * (1.0 - f.x) + p11 * f.x;
    vec4 pXX = pX0 * (1.0 - f.y) + pX1 * f.y;

    return pXX * color;
    */
}

#else

varying vec2 texture_coords;

vec4 effect(vec4 color, Image tex, vec2 _, vec2 screen_coords)
{
    return color * texture(tex, texture_coords);
}

#endif

#endif // ifdef PIXEL
