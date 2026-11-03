#version 300 es
precision mediump float;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

uniform float elapsed;

void main() {
    float time = elapsed / 10.0;
    rt_FragColor = vec4(
        (sin(rt_TextureCoords.x + time) + 1.0) / 2.0,
        0.0,
        (cos(rt_TextureCoords.y + time) + 1.0) / 2.0,
        1.0
    );
}