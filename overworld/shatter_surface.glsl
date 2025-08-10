#ifdef VERTEX

layout (location = 0) in vec4 VertexPosition;
layout (location = 1) in vec4 VertexTexCoord;
layout (location = 2) in vec4 VertexColor;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

uniform vec4 bounds;

out vec2 uv;

void vertexmain() {
    VaryingColor = gammaCorrectColor(VertexColor) * ConstantColor;
    love_Position = TransformProjectionMatrix * vec4(VertexPosition.xy, 0, 1);
    VaryingTexCoord.xy = (VertexPosition.xy - bounds.xy) / bounds.zw;
}

#endif

#ifdef PIXEL

uniform sampler2D img;

vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 screen_coords) {
    return texture(img, texture_coords);
}


#endif
