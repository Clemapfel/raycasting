#ifdef VERTEX

layout (location = 0) in vec4 VertexPosition;
layout (location = 1) in vec4 VertexTexCoord;
layout (location = 2) in vec4 VertexColor;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

uniform vec4 bounds;

out vec2 uv;

void main() {
    // override uv from vertex position
    uv = VaryingTexCoord.xy;

    // rest, default
    VaryingTexCoord.xy = (VertexPosition.xy - bounds.xy) / bounds.zw;
    VaryingColor = gammaCorrectColor(VertexColor) * ConstantColor;
    love_Position = position(ClipSpaceFromLocal, VertexPosition);
    love_Position = love_clipSpaceTransform(love_Position);
}

#endif

#ifdef PIXEL

in vec2 uv;

uniform sampler2D img;

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 screen_coords) {
    return color * texture(img, uv);
}


#endif
