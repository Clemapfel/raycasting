#ifdef VERTEX

layout (location = 0) in vec2 origin;
layout (location = 1) in vec2 dxy;
layout (location = 2) in vec4 rest_origin_rest_dxy;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    vec2 position = origin + dxy;
    vec2 rest_origin = rest_origin_rest_dxy.xy;
    vec2 rest_dxy = rest_origin_rest_dxy.zw;

    float fraction = length(dxy) / length(rest_dxy);
    vec4 color = vec4(vec3(fraction), 1);

    VaryingTexCoord = vec4(0);
    VaryingColor = gammaCorrectColor(color * ConstantColor);
    love_Position = TransformProjectionMatrix * vec4(position.xy, 0, 1);
}

#endif

#ifdef PIXEL

#define PI 3.1415926535897932384626433832795
float gaussian(float x, float ramp)
{
    return exp(((-4 * PI) / 3) * (ramp * x) * (ramp * x));
}

uniform vec2 player_position; // screen_cords
uniform vec4 player_color;

vec4 effect(vec4 color, sampler2D _img, vec2 _uv, vec2 screen_coords)
{
    vec2 player_uv = player_position / love_ScreenSize.xy;
    vec2 screen_uv = screen_coords / love_ScreenSize.xy;

    float attenuation = gaussian(distance(player_uv, screen_uv) * 2, 3);
    return vec4(color.rgb * attenuation * player_color.rgb, color.a * player_color.a);
}

#endif