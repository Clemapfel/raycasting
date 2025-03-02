vec2 rotate(vec2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return v * mat2(c, -s, s, c);
}

uniform sampler2D derivative_texture; // r: dFdx, g: dFdy, b: fwidth, a: noise
uniform vec2 image_size;
uniform vec2 screen_size;
uniform float line_width;
uniform float line_length;

#define MODE_DRAW_LINE 0
#define MODE_DRAW_CIRCLE 1

#ifndef MODE
#error "MODE should be 0 or 1"
#endif

#define PI 3.1415926535897932384626433832795

#ifdef VERTEX

varying float magnitude;
varying float angle;

vec4 position(mat4 transform, vec4 vertex_position)
{
    uint instance_id = uint(love_InstanceID);
    uint x_index = instance_id % uint(image_size.x);
    uint y_index = instance_id / uint(image_size.x);

    vec2 position = vec2(x_index + 0.5, y_index + 0.5) * (screen_size / image_size);

    vec4 data = texelFetch(derivative_texture, ivec2(x_index, y_index), 0);
    vec2 translation = data.xy * line_length * 3;

    magnitude = data.z;
    angle = (atan(data.y, data.x) + PI) / (2 * PI);

    #if MODE == MODE_DRAW_LINE

    // rotate and scale line in direction of gradient

    vec2 origin = position;
    vec2 destination = position + translation;
    vec2 direction = normalize(destination - origin);
    vec2 perpendicular = vec2(-direction.y, direction.x) * (line_width * 0.5);

    vec2[4] offsets = vec2[](
        origin + perpendicular,
        origin - perpendicular,
        destination - perpendicular,
        destination + perpendicular
    );

    vertex_position.xy = offsets[gl_VertexID];

    #elif MODE == MODE_DRAW_CIRCLE

    // draw circle on top

    vertex_position.xy += position + translation;

    #endif

    return transform * vertex_position;
}

#endif

#ifdef PIXEL

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

varying float magnitude;
varying float angle;

vec4 effect(vec4 color, Image image, vec2 texture_coords, vec2 vertex_position)
{
    float min_magnitude = 0.3;
    return vec4(lch_to_rgb(vec3(0.8, 1, min_magnitude + (1 - min_magnitude) * magnitude)), 1);
}

#endif