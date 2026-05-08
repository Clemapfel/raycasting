import type { GLContext } from './GLContext.ts';
import { Vec2, Vec3, Vec4 } from './Math.ts';
import { RGBA } from './Colors.ts';
import { Texture } from './Texture.ts';

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

class TextureUnitAllocator {
    private texture_to_unit: Map<WebGLTexture, number> = new Map<WebGLTexture, number>();
    private unit_to_texture: (WebGLTexture | null)[] | undefined = undefined; // initialized in constructor
    private texture_order: WebGLTexture[] = []; // least recently used

    constructor(context : GLContext) {
        if (context === null) return;

        this.unit_to_texture = new Array<WebGLTexture | null>().fill(null,
            0, context.MAX_TEXTURE_IMAGE_UNITS
        );
    }

    public getTextureUnit(texture: WebGLTexture): number {
        if (this.texture_to_unit.has(texture)) {
            this.texture_order.splice(this.texture_order.indexOf(texture), 1);
            this.texture_order.push(texture);
            return this.texture_to_unit.get(texture)!;
        }

        let unit: number;

        if (this.texture_to_unit.size < this.unit_to_texture!.length) {
            // not yet all occupied, return free slot
            unit = this.texture_to_unit.size;
        } else {
            // all units occupied, evict least recently used
            const evicted = this.texture_order.shift()!;
            unit = this.texture_to_unit.get(evicted)!;
            this.texture_to_unit.delete(evicted);
        }

        this.unit_to_texture![unit] = texture;
        this.texture_to_unit.set(texture, unit);
        this.texture_order.push(texture);

        return unit;
    }
}

export class Shader {
    private fragment_shader_source : string;
    private vertex_shader_source : string;
    private program : WebGLShader;
    private context : GLContext;

    // static lru queue for texture unit allocation
    static context_to_texture_unit_allocator : Map<GLContext, TextureUnitAllocator> = new Map<GLContext, TextureUnitAllocator>();

    constructor(context : GLContext, fragment_shader_source? : string, vertex_shader_source? : string) {
        if (fragment_shader_source == undefined) fragment_shader_source = default_fragment_shader_source;
        if (vertex_shader_source == undefined) vertex_shader_source = default_vertex_shader_source;
        this.context = context;

        this.fragment_shader_source = fragment_shader_source;
        this.vertex_shader_source = vertex_shader_source;
        this.recompile();

        if (Shader.context_to_texture_unit_allocator.has(context))
            Shader.context_to_texture_unit_allocator.set(context, new TextureUnitAllocator(context));
    }

    private recompile(): void {
        const gl = this.context; if (gl === null) return;

        if (this.program) gl.deleteProgram(this.program);

        const compile_shader = (type: number, source: string): WebGLShader => {
            const shader = gl.createShader(type)!;
            gl.shaderSource(shader, source);
            gl.compileShader(shader);
            if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                const log = gl.getShaderInfoLog(shader) ?? "unknown error";
                gl.deleteShader(shader);
                throw new Error(`In Shader: when compiling ${type === gl.VERTEX_SHADER ? "vertex" : "fragment"} shader: compilation failed:\n${log}`);
            }
            return shader;
        };

        const vertex_shader = compile_shader(gl.VERTEX_SHADER, this.vertex_shader_source);
        const fragment_shader = compile_shader(gl.FRAGMENT_SHADER, this.fragment_shader_source);

        const program = gl.createProgram()!;
        gl.attachShader(program, vertex_shader);
        gl.attachShader(program, fragment_shader);
        gl.linkProgram(program);

        gl.deleteShader(vertex_shader);
        gl.deleteShader(fragment_shader);

        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
            const log = gl.getProgramInfoLog(program) ?? "unknown error";
            gl.deleteProgram(program);
            throw new Error(`In Shader: program linking failed:\n${log}`);
        }

        this.program = program;
    }

    public bind() {
        const gl = this.context; if (gl === null) return;
        gl.useProgram(this.program);
    }

    public unbind() {
        const gl = this.context; if (gl === null) return;
        gl.useProgram(null);
    }

    public setUniform(id: string, value: number | Vec2 | Vec3 | Vec4 | RGBA | Texture) {
        const gl = this.context; if (gl === null) return;

        const location = gl.getUniformLocation(this.program, id);
        if (location === null) {
            console.warn(`In Shader.setUniform: no uniform with id \'${id}\' present`);
            return;
        }

        if (typeof value === "number") {
            const indices = gl.getUniformIndices(this.program, [id]);
            if (indices === null) {
                console.warn(`In Shader.setUniform: unable to get uniform indices for uniform with id \'${id}\'`)
                return;
            }

            const info = gl.getActiveUniform(this.program, indices[0]);
            if (info === null) {
                console.warn(`In Shader.setUniform: unable to get uniform infor for uniform with id \'${id}\'`)
                return;
            }

            if (info.type == gl.UNSIGNED_INT)
                gl.uniform1ui(location, value as number);
            else
                gl.uniform1f(location, value as number);
        }
        else if (value instanceof Texture) {
            const unit = Shader.context_to_texture_unit_allocator.get(this.context)!.getTextureUnit(value.getNative());
            gl.activeTexture(gl.TEXTURE0 + unit);
            gl.bindTexture(gl.TEXTURE_2D, value.getNative());
            gl.uniform1i(location, unit);
            gl.bindTexture(gl.TEXTURE_2D, null);
        }
        else if (value instanceof RGBA)
            gl.uniform4f(location, value.r, value.g, value.b, value.a);
        else if (value instanceof Vec2)
            gl.uniform2f(location, value.x, value.y);
        else if (value instanceof Vec3)
            gl.uniform3f(location, value.x, value.y, value.z);
        else if (value instanceof Vec4)
            gl.uniform4f(location, value.x, value.y, value.z, value.w);
        else
            throw new Error(`In Shader.setUniform: unhandled argument type ${typeof value}`);
    }

    public free() {
        const gl = this.context; if (gl === null) return;
        if (this.program) gl.deleteProgram(this.program);
    }
}