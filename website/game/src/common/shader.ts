import type { GLContext } from "./gl_context.ts";
import { Vec2, Vec3, Vec4 } from "./vector.ts";
import { Transform } from "./transform.ts";
import { RGBA } from "./color.ts";
import { Texture } from "./texture.ts";
import { MeshVertexFormat } from "./mesh_vertex_format.ts";
import { List } from "./linked_list.ts"

export const DEFAULT_TEXTURE_UNIFORM_NAME = "rt_Texture0";
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
                    ${DEFAULT_RGBA_NAME} = ${ has_rgba ? `${DEFAULT_COLOR_NAME} * vertex_color` : "vec4(1.0)" };
                    
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
                
                uniform sampler2D ${DEFAULT_TEXTURE_UNIFORM_NAME};
                uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
                
                in vec2 ${DEFAULT_UV_NAME};
                in vec4 ${DEFAULT_RGBA_NAME};
                in vec2 ${DEFAULT_SCREEN_POS_NAME};
                
                out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
                
                void main() {
                    vec4 texel = texture(${DEFAULT_TEXTURE_UNIFORM_NAME}, ${DEFAULT_UV_NAME});
                    ${DEFAULT_FRAGMENT_OUT_NAME} = texel * ${DEFAULT_RGBA_NAME};
                }
                `
        } as DefaultShaderSource;
    }

    return out;
})() as Record<MeshVertexFormat, DefaultShaderSource>;

class TextureUnitAllocator {
    private context : GLContext;
    private list : List<WebGLTexture> = new List<WebGLTexture>();
    private max_units : number = 0;

    constructor(context : GLContext) {
        this.context = context;
        if (this.context.isValid()) {
            this.max_units = this.context.gl!.getParameter(this.context.gl!.MAX_TEXTURE_IMAGE_UNITS);
        }
    }

    public getTextureUnit(texture: WebGLTexture): number {
        if (!this.context.isValid()) return 0x0;

        if (!this.list.has(texture)) {
            if (this.list.length >= this.max_units)
                this.list.popBack();
        }
        else {
            this.list.remove(texture)
        }

        this.list.pushFront(texture);
        return this.list.getPosition(texture)!
    }
}

/** **/
export class Shader {
    private fragment_shader_source : string;
    private vertex_shader_source : string;
    private program : WebGLShader | null = null;
    private context : GLContext;
    private was_transform_bound : boolean = false;
    private uniform_cache : Map<string, { location: WebGLUniformLocation, type: number }> = new Map();

    // static lru queue for texture unit allocation
    static context_to_texture_unit_allocator : Map<GLContext, TextureUnitAllocator> = new Map<GLContext, TextureUnitAllocator>();

    // default textures for meshes
    static context_to_default_texture : Map<GLContext, WebGLTexture> = new Map<GLContext, WebGLTexture>();
    static create_default_texture(context : GLContext) : WebGLTexture {
        const gl = context.gl!;
        const tex = gl.createTexture();
        if (tex === null) throw new Error("In Shader: unable to create default texture");

        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([255, 255, 255, 255]));            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.bindTexture(gl.TEXTURE_2D, null)

        return tex
    }

    static default_transform = new Transform().asIdentity();

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
        const { gl } = this.context;

        this.fragment_shader_source = fragment_shader_source;
        this.vertex_shader_source = vertex_shader_source;
        this.recompile();

        if (!Shader.context_to_texture_unit_allocator.has(context))
            Shader.context_to_texture_unit_allocator.set(context, new TextureUnitAllocator(context));

        // event listeners to free default texture

        if (!Shader.context_to_default_texture.has(this.context)) {
            Shader.context_to_default_texture.set(this.context, Shader.create_default_texture(this.context));

            gl.canvas.addEventListener("webglcontextlost", () => {
                // gl resource already freed, no gl.deleteTexture
                Shader.context_to_default_texture.delete(this.context);
            });

            gl.canvas.addEventListener("webglcontextrestored", () => {
                Shader.context_to_default_texture.set(this.context, Shader.create_default_texture(this.context));
            });
        }
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

            this.setUniform(
                DEFAULT_TRANSFORM_NAME,
                Shader.default_transform.asIdentity()
            );
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

    /** @internal **/
    public _make_current(gl : WebGL2RenderingContext) {
        if (this.program === null) return;

        gl.useProgram(this.program);

        // bind 1x1 white default texture so the default shader does not return vec4(0)
        if (gl.getParameter(gl.TEXTURE_BINDING_2D) === null) {
            const tex = Shader.context_to_default_texture.get(this.context);
            if (tex !== undefined) {
                gl.activeTexture(gl.TEXTURE0);
                gl.bindTexture(gl.TEXTURE_2D, tex);
                gl.uniform1i(gl.getUniformLocation(this.program, DEFAULT_TEXTURE_UNIFORM_NAME), 0);
            }
        }

        // set default screen size
        const screen_size_location = gl.getUniformLocation(this.program, DEFAULT_SCREEN_SIZE_NAME);
        if (screen_size_location !== null)
            gl.uniform2f(screen_size_location, gl.canvas.width, gl.canvas.height)

        // set color
        const color_location = gl.getUniformLocation(this.program, DEFAULT_COLOR_NAME);
        if (color_location !== null) {
            const color = this.context.getColor();
            gl.uniform4f(color_location, color.r, color.g, color.b, color.a)
        }

        // set transform
        if (gl.getUniformLocation(this.program, DEFAULT_TRANSFORM_NAME)) {
            /*
            const element = this.context.gl!.canvas as HTMLElement;
            const rect = element.getBoundingClientRect();
            this.setUniform(default_transform_name, Shader.default_transform
                .asIdentity()
                .translate(rect.width / 2, rect.height / 2)
                .scale(
                    element.offsetWidth / rect.width,
                    element.offsetHeight / rect.height
                )
                .translate(-rect.width / 2, -rect.height / 2)
            );
             */
            this.setUniform(DEFAULT_TRANSFORM_NAME, Shader.default_transform.asIdentity());
        }
    }

    /** **/
    public bind() {
        if (!this.context.isValid() || this.program === null) return;
        const { gl } = this.context;

        this.context._notify_shader_bound(this);
    }

    /** **/
    public unbind() {
        if (!this.context.isValid() || this.program === null) return;
        const { gl } = this.context;

        this.context._notify_shader_unbound(this);
    }

    /** **/
    public setUniform(id: string, value: number | Vec2 | Vec3 | Vec4 | RGBA | Transform | Texture | undefined) {
        if (!this.context.isValid() || this.program === null) return;
        const { gl } = this.context;

        const info = this.uniform_cache.get(id);
        if (!info) {
            console.warn(`In Shader.setUniform: no uniform with id \"${id}\" present`);
            return;
        }

        gl.useProgram(this.program);

        const { location, type } = info;

        if (typeof value === "number") {
            if (type == gl.UNSIGNED_INT)
                gl.uniform1ui(location, value);
            else
                gl.uniform1f(location, value);
        }
        else if (value instanceof Transform) {
            gl.uniformMatrix4fv(location, false, value.getData());
        }
        else if (value instanceof Texture) {
            const unit = Shader.context_to_texture_unit_allocator.get(this.context)!.getTextureUnit(value.getNative());

            gl.activeTexture(gl.TEXTURE0 + unit);
            gl.bindTexture(gl.TEXTURE_2D, value.getNative());
            gl.uniform1i(location, unit);
        }
        else if (value instanceof RGBA)
            gl.uniform4f(location, value.r, value.g, value.b, value.a);
        else if (value instanceof Vec2)
            gl.uniform2f(location, value.x, value.y);
        else if (value instanceof Vec3)
            gl.uniform3f(location, value.x, value.y, value.z);
        else if (value instanceof Vec4)
            gl.uniform4f(location, value.x, value.y, value.z, value.w);
        else if (!value)
            throw new Error(`In Shader.setUniform: value for uniform ${id} is ${value}`)
        else
            throw new Error(`In Shader.setUniform: for uniform ${id}: unhandled argument type ${typeof value}`);
    }

    /** **/
    public hasUniform(id : string) : boolean {
        return this.uniform_cache.has(id);
    }

    /** **/
    public free() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;
        if (this.program) gl.deleteProgram(this.program);
    }
}