#ifdef VERTEX

#ifndef N_INSTANCES
#error "N_INSTANCES undefined"
#endif

#ifndef N_VERTICES
#error "N_VERTICES undefined"
#endif

// default mesh attributes ignored
layout (location = 0) in vec4 VertexPosition;
layout (location = 1) in vec4 VertexTexCoord;
layout (location = 2) in vec4 VertexColor;

uniform vec2 positions[N_INSTANCES * N_VERTICES];
uniform vec2 texture_coordinates[N_INSTANCES * N_VERTICES];
uniform vec2 offsets[N_INSTANCES];

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    int instance_id = gl_InstanceID;
    int index = instance_id * N_VERTICES + gl_VertexID;

    // read vertex attributes from uniform instead
    vec2 position = positions[index] + offsets[instance_id];
    vec2 uv = texture_coordinates[index];

    VaryingColor = gammaCorrectColor(ConstantColor);
    VaryingTexCoord.xy = uv;
    love_Position = TransformProjectionMatrix * vec4(position, 0, 1);
}

#endif
