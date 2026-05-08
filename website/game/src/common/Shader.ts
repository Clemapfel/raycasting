import type { GLContext } from './GLContext.ts';
import type { Vec2 } from './Math.ts';
import type { RGBA } from './Colors.ts'

export const default_texture_uniform_name = "texture";
export const default_uv_name = "fragment_uv";
export const default_rgba_name = "fragment_color";
export const default_fragment_out_name = "out_color";

const default_vertex_shader_source = `#version 300 es

layout(location = 0) in vec2 vertex_position;
layout(location = 1) in vec2 vertex_uv;
layout(location = 2) in vec4 vertex_color;

out vec2 ${default_uv_name};
out vec4 ${default_rgba_name};

void main() {
    ${default_uv_name} = vertex_uv;
    ${default_rgba_name} = vertex_color;
    gl_Position = vec4(vertex_position, 0.0, 1.0);
}
`;

const default_fragment_shader_source = `#version 300 es
precision mediump float;

uniform sampler2D ${default_texture_uniform_name};

in vec2 ${default_uv_name};
in vec4 ${default_rgba_name};

out vec4 ${default_fragment_out_name};

void main() {
    vec4 texel = texture(${default_texture_uniform_name}, ${default_uv_name});
    ${default_fragment_out_name} = texel * ${default_rgba_name};
}
`;

export class Shader {
    private fragment_shader_source : string;
    private vertex_shader_source : string;
    private program : WebGLShader;
    private context : GLContext;

    constructor(context : GLContext, fragment_shader_source? : string, vertex_shader_source? : string) {
        if (fragment_shader_source == undefined) fragment_shader_source = default_fragment_shader_source;
        if (vertex_shader_source == undefined) vertex_shader_source = default_vertex_shader_source;
        this.context = context;


        // compile shader program, correctly bubble up verbose error
    }

    public recompile() {
       // recompile shader program, correclty bubble up verbose error
    }

    public bind() {
        // bind shader for rendering
    }

    public unbind() {
        // unbind shader for rendering
    }

    public setUniform(id: string, value: number | Vec2 | RGBA) {
        // cache location lookup in uniform_to_name_location
        // switch on value type and use the correct gl.uniform*
    }

    public free() {
        // free program and strings
    }
}