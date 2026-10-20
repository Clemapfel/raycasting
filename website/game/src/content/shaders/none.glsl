#version 300 es
precision mediump float;

in vec2 rt_TextureCoords;
in vec4 rt_VertexColor;
in vec2 rt_VertexPosition;
out vec4 rt_FragColor;

void main() {
    rt_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
}