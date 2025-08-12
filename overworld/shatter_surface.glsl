#ifdef VERTEX

#ifndef N_INSTANCES
#error "N_INSTANCES undefined"
#endif

#ifndef N_VERTICES
#error "N_VERTICES undefined"
#endif

uniform vec4 static_data[N_INSTANCES * N_VERTICES]; // N_VERTICES many vec4s per instance
uniform vec2 offsets[N_INSTANCES]; // 1 many vec4s per instance

layout (location = 0) in vec4 VertexPosition;
layout (location = 1) in vec4 VertexTexCoord;
layout (location = 2) in vec4 VertexColor;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    int instance_id = gl_InstanceID;
    vec4 entry = static_data[instance_id * N_VERTICES + gl_VertexID];

    vec2 position = entry.xy;
    vec2 uv = entry.zw;
    vec2 offset = offsets[instance_id];

    VaryingColor = gammaCorrectColor(ConstantColor);
    VaryingTexCoord.xy = uv;
    love_Position = TransformProjectionMatrix * vec4(VertexPosition.xy + position, 0, 1);
}

#endif
