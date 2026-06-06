// @/website/game/src/common/shader.ts

import type { GLContext } from "./gl_context.ts";
import { Vec2, Vec3, Vec4 } from "./vector.ts";
import { Transform } from "./transform.ts";
import { RGBA } from "./color.ts";
import { Texture } from "./texture.ts";
import { MeshVertexFormat } from "./mesh_vertex_format.ts";

export const DEFAULT_TEXTURE_NAME = "rt_Texture0";
export const DEFAULT_UV_NAME = "rt_TextureCoords";
export const DEFAULT_RGBA_NAME = "rt_VertexColor";
export const DEFAULT_SCREEN_POS_NAME = "rt_VertexPosition";
export const DEFAULT_SCREEN_SIZE_NAME = "rt_ScreenSize";
export const DEFAULT_COLOR_NAME = "rt_Color";
export const DEFAULT_TRANSFORM_NAME = "rt_Transform";
export const DEFAULT_FRAGMENT_OUT_NAME = "rt_FragColor";
export const DEFAULT_SHADER_VERSION = "#version 300 es";
export const DEFAULT_FLOAT_PRECISION = "precision highp float;";

interface DefaultShaderSource {
    fragment: string,
    vertex: string
}

const mesh_format_to_default_shader_source : Record<MeshVertexFormat, DefaultShaderSource> = (() => {
    const format_to_has_components = {
        [MeshVertexFormat.XY_UV_RGBA] : {
            has_uv : true,
            has_rgba : true
        },

        [MeshVertexFormat.XY_UV] : {
            has_uv : true,
            has_rgba : false
        },

        [MeshVertexFormat.XY_RGBA] : {
            has_uv : false,
            has_rgba : true
        },

        [MeshVertexFormat.XY] : {
            has_uv : false,
            has_rgba : false
        }
    } as const;

    const out = {};
    for (const format of [
        MeshVertexFormat.XY,
        MeshVertexFormat.XY_UV,
        MeshVertexFormat.XY_RGBA,
        MeshVertexFormat.XY_UV_RGBA
    ]) {
        const { has_uv, has_rgba } = format_to_has_components[format];

        out[format] = {
            vertex : `${DEFAULT_SHADER_VERSION}
                ${DEFAULT_FLOAT_PRECISION}
                
                layout(location = 0) in vec2 vertex_position;
                ${ has_uv ? "layout(location = 1) in vec2 vertex_uv;" : "" }
                ${ has_rgba ? "layout(location = 2) in vec4 vertex_color;" : "" }
                
                uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
                uniform vec4 ${DEFAULT_COLOR_NAME}; 
                uniform mat4x4 ${DEFAULT_TRANSFORM_NAME};
                
                out vec2 ${DEFAULT_UV_NAME};
                out vec4 ${DEFAULT_RGBA_NAME};
                out vec2 ${DEFAULT_SCREEN_POS_NAME};
                void main() {
                    ${DEFAULT_UV_NAME} = ${ has_uv ? `vertex_uv` : "vec2(0.0)"};
                    ${DEFAULT_RGBA_NAME} = ${ has_rgba ? `${DEFAULT_COLOR_NAME} * vertex_color` : DEFAULT_COLOR_NAME };
                    
                    vec4 position = ${DEFAULT_TRANSFORM_NAME} * vec4(vertex_position, 0.0, 1.0);                    
                    ${DEFAULT_SCREEN_POS_NAME} = position.xy;
                    
                    position.xy = (position.xy / ${DEFAULT_SCREEN_SIZE_NAME}) * 2.0 - 1.0;
                    position.y *= -1.0;
                    
                    gl_Position = position;
                }
                `
            ,

            // fragment invariable for now
            fragment : `${DEFAULT_SHADER_VERSION}
                ${DEFAULT_FLOAT_PRECISION}
                
                uniform sampler2D ${DEFAULT_TEXTURE_NAME};
                uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
                
                in vec2 ${DEFAULT_UV_NAME};
                in vec4 ${DEFAULT_RGBA_NAME};
                in vec2 ${DEFAULT_SCREEN_POS_NAME};
                
                out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
                
                void main() {
                    vec4 texel = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME});
                    ${DEFAULT_FRAGMENT_OUT_NAME} = texel * ${DEFAULT_RGBA_NAME};
                }
                `
        } as DefaultShaderSource;
    }

    return out;
})() as Record<MeshVertexFormat, DefaultShaderSource>;

/** **/
export class Shader {
    private fragment_shader_source : string;
    private vertex_shader_source : string;
    private program : WebGLShader | null = null;
    private context : GLContext;
    private uniform_cache : Map<string, { location: WebGLUniformLocation, type: number }> = new Map();

    private uniform_id_to_warning_printed : Map<string, boolean> = new Map<string, boolean>();
    private texture_bound : boolean = false;
    private color_bound : boolean = false;
    private screen_size_bound : boolean = false;
    private transform_bound : boolean = false;

    /** **/
    constructor(
        context : GLContext,
        fragment_shader_source? : string,
        vertex_shader_source? : string,
        mesh_format : MeshVertexFormat = MeshVertexFormat.XY_UV_RGBA
    ) {
        if (!(mesh_format in mesh_format_to_default_shader_source))
            throw new Error(`In Mesh: unsupported mesh format ${mesh_format}`);

        const default_entry = mesh_format_to_default_shader_source[mesh_format];
        if (fragment_shader_source == undefined) fragment_shader_source = default_entry.fragment;
        if (vertex_shader_source == undefined) vertex_shader_source = default_entry.vertex;

        this.context = context;

        if (!this.context.isValid()) return;
        this.fragment_shader_source = fragment_shader_source;
        this.vertex_shader_source = vertex_shader_source;
        this.recompile();
    }

    /** **/
    private recompile(): void {
        if (!this.context.isValid()) return;

        const { gl } = this.context;
        const old_program = this.program;

        let vertex_shader: WebGLShader | null = null;
        let fragment_shader: WebGLShader | null = null;
        let new_program: WebGLProgram | null = null;

        try {
            const compile_shader = (type: number, source: string): WebGLShader | null => {
                const shader = gl.createShader(type);
                if (!shader) {
                    throw new Error(`In Shader: failed to create ${type === gl.VERTEX_SHADER ? "vertex" : "fragment"} shader`);
                }

                gl.shaderSource(shader, source);
                gl.compileShader(shader);

                if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                    const log = gl.getShaderInfoLog(shader) ?? "unknown error";
                    gl.deleteShader(shader);

                    throw new Error(`In Shader: when compiling ${type === gl.VERTEX_SHADER ? "vertex" : "fragment"} shader: compilation failed:\n${log}`);
                }

                return shader;
            };

            vertex_shader = compile_shader(gl.VERTEX_SHADER, this.vertex_shader_source);
            if (vertex_shader === null)
                throw new Error("In Shader: failed to create vertex shader");

            fragment_shader = compile_shader(gl.FRAGMENT_SHADER, this.fragment_shader_source);
            if (fragment_shader === null)
                throw new Error("In Shader: failed to create fragment shader");

            new_program = gl.createProgram();
            if (new_program === null)
                throw new Error("In Shader: failed to create program");

            gl.attachShader(new_program, vertex_shader);
            gl.attachShader(new_program, fragment_shader);
            gl.linkProgram(new_program);

            if (!gl.getProgramParameter(new_program, gl.LINK_STATUS)) {
                const log = gl.getProgramInfoLog(new_program) ?? "unknown error";
                throw new Error(`In Shader: program linking failed:\n${log}`);
            }

            if (old_program !== null) {
                gl.deleteProgram(old_program);
            }

            this.program = new_program;
            this.uniform_cache.clear();

            const n_uniforms = gl.getProgramParameter(this.program, gl.ACTIVE_UNIFORMS) as number;
            for (let i = 0; i < n_uniforms; i++) {
                const info = gl.getActiveUniform(this.program, i);
                if (info === null) continue;

                const name = info.name.replace(/\[0\]$/, "");
                const location = gl.getUniformLocation(this.program, name);

                if (location !== null)
                    this.uniform_cache.set(name, { location, type: info.type });
            }
        } catch (error) {
            if (new_program !== null)
                gl.deleteProgram(new_program);

            throw error;
        } finally {
            if (vertex_shader !== null)
                gl.deleteShader(vertex_shader);

            if (fragment_shader !== null)
                gl.deleteShader(fragment_shader);
        }
    }

    /** **/
    public bind() {
        if (!this.context.isValid() || this.program === null) return;
        this.context._notify_shader_bound(this);
    }

    /** **/
    public unbind() {
        if (!this.context.isValid() || this.program === null) return;
        this.context._notify_shader_unbound(this);
    }

    /** **/
    public setUniform(id: string, value: number | Vec2 | Vec3 | Vec4 | RGBA | Transform | Texture | undefined) {
        if (!this.context.isValid() || this.program === null) return;
        const { gl } = this.context;

        const info = this.uniform_cache.get(id);
        if (!info && this.uniform_id_to_warning_printed.get(id) !== true) {
            console.warn(`In Shader.setUniform: no uniform with id \"${id}\" present`);
            this.uniform_id_to_warning_printed.set(id, true);
            return;
        }

        gl.useProgram(this.program);

        const { location, type } = info!;

        if (typeof value === "number") {
            if (type == gl.UNSIGNED_INT)
                gl.uniform1ui(location, value);
            else
                gl.uniform1f(location, value);
        }
        else if (value instanceof RGBA)
            gl.uniform4f(location, value.r, value.g, value.b, value.a);
        else if (value instanceof Vec2)
            gl.uniform2f(location, value.x, value.y);
        else if (value instanceof Vec3)
            gl.uniform3f(location, value.x, value.y, value.z);
        else if (value instanceof Vec4)
            gl.uniform4f(location, value.x, value.y, value.z, value.w);
        else if (value instanceof Transform) {
            gl.uniformMatrix4fv(location, false, value.getData());
        }
        else if (value instanceof Texture) {
            const index = this.context.getTextureUnit(value);
            gl.activeTexture(gl.TEXTURE0 + index);
            gl.bindTexture(gl.TEXTURE_2D, value.getNative());
            gl.uniform1i(location, index);
        }
        else if (value !== undefined)
            throw new Error(`In Shader.setUniform: for uniform ${id}: unhandled argument type ${typeof value}`);

        // allow resetting bound state with undefined

        if (id == DEFAULT_SCREEN_SIZE_NAME)
            this.screen_size_bound = value !== undefined;
        else if (id === DEFAULT_COLOR_NAME)
            this.color_bound = value !== undefined;
        else if (id == DEFAULT_TEXTURE_NAME)
            this.texture_bound = value !== undefined;
        else if (id == DEFAULT_TRANSFORM_NAME)
            this.transform_bound = value !== undefined;
        else if (this.uniform_id_to_warning_printed.get(id) !== true) {
            console.warn(`In Shader.setUniform: trying to set uniform \"${id}\" to undefined. The uniform will not be updated`);
            this.uniform_id_to_warning_printed.set(id, true);
        }
    }

    /** @internal */
    public _get_are_defaults_bound(): {
        texture_bound: boolean;
        color_bound: boolean;
        screen_size_bound: boolean;
        transform_bound: boolean
    } {
        return {
            texture_bound: this.texture_bound,
            color_bound: this.color_bound,
            screen_size_bound: this.screen_size_bound,
            transform_bound: this.transform_bound,
        };
    }

    /** **/
    public getUniformLocation(id : string) : WebGLUniformLocation | undefined {
        return this.uniform_cache.get(id)?.location;
    }

    /** **/
    public hasUniform(id : string) : boolean {
        return this.uniform_cache.has(id);
    }

    /** **/
    public free() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.program !== null) {
            gl.deleteProgram(this.program);
            this.program = null;
        }
    }

    /** **/
    public getNative() : WebGLShader | null {
        return this.program;
    }
}