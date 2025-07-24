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
