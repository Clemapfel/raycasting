import type { GLContext } from './GLContext.ts';
import type { Vec2 } from './Math.ts';
import type { RGBA } from './Color.ts';

const defaultVertexSource = `
attribute vec2 a_position;
attribute vec2 a_texCoord;
attribute vec4 a_color;

varying vec2 v_texCoord;
varying vec4 v_color;

void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texCoord = a_texCoord;
    v_color = a_color;
}
`;

const defaultFragmentSource = `
precision mediump float;
varying vec2 v_texCoord;
varying vec4 v_color;

uniform sampler2D u_texture;

void main() {
    // Multiply vertex color by texture (default white texture ensures no effect when untextured)
    gl_FragColor = v_color * texture2D(u_texture, v_texCoord);
}
`;

export class Shader {
    private context: GLContext;
    private vertexSource: string;
    private fragmentSource: string;
    private program: WebGLProgram | null = null;
    private uniformLocationCache: Map<string, WebGLUniformLocation | null> = new Map();

    constructor(
        context: GLContext,
        fragmentSource?: string,
        vertexSource?: string
    ) {
        this.context = context;
        this.vertexSource = vertexSource ?? defaultVertexSource;
        this.fragmentSource = fragmentSource ?? defaultFragmentSource;
        this.compileAndLink();
    }

    /** Recompiles the shader program from the stored sources. */
    public recompile(): void {
        if (this.program) {
            this.context.deleteProgram(this.program);
            this.uniformLocationCache.clear();
        }
        this.compileAndLink();
    }

    /** Binds the shader program for subsequent draw calls. */
    public bind(): void {
        this.context.useProgram(this.program);
    }

    /** Unbinds any shader program. */
    public unbind(): void {
        this.context.useProgram(null);
    }

    /**
     * Sets a uniform value.
     * @param id    Uniform name (as in the shader source).
     * @param value Number (float), Vec2 (x,y), or RGBA (r,g,b,a in 0‑1 range).
     */
    public setUniform(id: string, value: number | Vec2 | RGBA): void {
        const gl = this.context;
        const loc = this.getUniformLocation(id);
        if (loc === null) return; // uniform not found or optimized out

        if (typeof value === 'number') {
            gl.uniform1f(loc, value);
        } else if ('x' in value && 'y' in value && !('r' in value)) {
            // Vec2
            gl.uniform2f(loc, value.x, value.y);
        } else if ('r' in value && 'g' in value && 'b' in value && 'a' in value) {
            // RGBA (assume 0‑1 floats)
            gl.uniform4f(loc, value.r, value.g, value.b, value.a);
        } else {
            throw new Error(`Unsupported uniform value type for '${id}'`);
        }
    }

    /** Frees the shader program. */
    public free(): void {
        if (this.program) {
            this.context.deleteProgram(this.program);
            this.program = null;
            this.uniformLocationCache.clear();
        }
    }

    private compileAndLink(): void {
        const gl = this.context;
        const vertexShader = this.compileShader(gl.VERTEX_SHADER, this.vertexSource);
        const fragmentShader = this.compileShader(gl.FRAGMENT_SHADER, this.fragmentSource);

        this.program = gl.createProgram()!;
        gl.attachShader(this.program, vertexShader);
        gl.attachShader(this.program, fragmentShader);
        gl.linkProgram(this.program);

        if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) {
            const log = gl.getProgramInfoLog(this.program);
            gl.deleteProgram(this.program);
            throw new Error(`Shader program linking failed: ${log}`);
        }

        // Shaders can be deleted after linking
        gl.deleteShader(vertexShader);
        gl.deleteShader(fragmentShader);
    }

    private compileShader(type: number, source: string): WebGLShader {
        const gl = this.context;
        const shader = gl.createShader(type)!;
        gl.shaderSource(shader, source);
        gl.compileShader(shader);

        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            const log = gl.getShaderInfoLog(shader);
            gl.deleteShader(shader);
            const typeName = type === gl.VERTEX_SHADER ? 'vertex' : 'fragment';
            throw new Error(`${typeName} shader compilation failed:\n${log}`);
        }
        return shader;
    }

    private getUniformLocation(name: string): WebGLUniformLocation | null {
        if (this.uniformLocationCache.has(name)) {
            return this.uniformLocationCache.get(name)!;
        }
        const loc = this.context.getUniformLocation(this.program!, name);
        this.uniformLocationCache.set(name, loc);
        return loc;
    }
}

class TextureUnitCache {
    private readonly texture_to_unit = new Map<WebGLTexture, number>();
    private readonly unit_to_texture: (WebGLTexture | null)[];

    constructor(private readonly gl: WebGL2RenderingContext, private readonly unit_count: number) {
        this.unit_to_texture = new Array(unit_count).fill(null);
    }

    bind(texture: WebGLTexture, target: number, location: WebGLUniformLocation): void {
        const gl = this.gl;
        let unit = this.texture_to_unit.get(texture);

        if (unit === undefined) {
            if (this.texture_to_unit.size < this.unit_count) {
                unit = this.texture_to_unit.size;
            } else {
                unit = this.texture_to_unit.keys().next().value!; // least recently used
                this.texture_to_unit.delete(this.unit_to_texture[unit]!);
            }
            this.unit_to_texture[unit] = texture;
            gl.activeTexture(gl.TEXTURE0 + unit);
            gl.bindTexture(target, texture);
        }

        this.texture_to_unit.delete(texture);
        this.texture_to_unit.set(texture, unit); // bump to most recently used
        gl.uniform1i(location, unit);
    }
}