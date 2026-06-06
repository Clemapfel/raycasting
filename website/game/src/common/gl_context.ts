// @/website/game/src/common/gl_context.ts

import { RGBA } from "./color.ts";
import { RenderTexture, Texture } from "./texture.ts";
import {
    DEFAULT_COLOR_NAME,
    DEFAULT_SCREEN_SIZE_NAME,
    DEFAULT_TEXTURE_NAME,
    DEFAULT_TRANSFORM_NAME,
    Shader
} from "./shader.ts";
import { Deque } from "./deque.ts";
import { Transform } from "./transform.ts";
import { MeshVertexFormat } from "./mesh_vertex_format.ts";

/** **/
export enum BlendMode {
    NONE,
    ALPHA,
    PREMULTIPLIED_ALPHA,
    ADD,
    SUBTRACT,
    REVERSE_SUBTRACT,
    MULTIPLY
}

/** **/
export enum StencilMode {
    DRAW,
    TEST,
    NONE
}

const max_stack_depth = 512;

/** **/
export enum PushTarget {
    ALL = 0x0,
    COLOR = 0x1 << 0,
    BLEND_MODE = 0x1 << 1,
    STENCIL_MODE = 0x1 << 2,
    TRANSFORM = 0x1 << 3
}

/** **/
interface PushNode {
    color : RGBA | undefined,
    blend_mode_rgb : BlendMode | undefined,
    blend_mode_alpha : BlendMode | undefined,
    stencil_mode : StencilMode | undefined,
    stencil_value : number | undefined,
    transform : Transform | undefined
}

/** **/
class TextureUnitAllocator {
    private slots: (WebGLTexture | null)[];
    private cursor: number = 0;

    constructor(max_units: number) {
        // unit 0 is reserved for the default white texture in set_shader
        this.slots = new Array(Math.max(1, max_units - 1)).fill(null);
    }

    public allocate(texture: WebGLTexture): number {
        for (let i = 0; i < this.slots.length; i++) {
            if (this.slots[i] === texture) return i + 1;
        }
        const index = this.cursor;
        this.slots[index] = texture;
        this.cursor = (this.cursor + 1) % this.slots.length;
        return index + 1;
    }
}

/** **/
export class GLContext {
    public gl : WebGL2RenderingContext | null;

    private push_stack : Deque<PushNode> = new Deque<PushNode>();

    private blend_mode_rgb : BlendMode = BlendMode.ALPHA;
    private blend_mode_alpha : BlendMode = BlendMode.ALPHA;
    private stencil_mode : StencilMode = StencilMode.NONE;
    private stencil_value : number = 0x0;
    private color : RGBA = new RGBA(1, 1, 1, 1);
    private transform : Transform = new Transform().asIdentity();

    private render_texture_stack : Deque<RenderTexture> = new Deque<RenderTexture>();
    private shader_stack : Deque<Shader> = new Deque<Shader>();
    private shader_default_texture : WebGLTexture;
    private shader_texture_unit_allocator : TextureUnitAllocator;
    private mesh_vertex_format_to_default_shader : Map<MeshVertexFormat, Shader> = new Map<MeshVertexFormat, Shader>();

    constructor(canvas: HTMLCanvasElement) {
        this.gl = canvas.getContext("webgl2", {
            antialias: true,
            powerPreference: "high-performance",
            alpha: true,
            depth: true,
            stencil: true,
            desynchronized: true
        });

        if (this.gl !== null) {
            const gl = this.gl;
            const texture = gl.createTexture();

            if (texture === null)
                throw new Error("In GLContext: unable to create default texture");

            gl.bindTexture(gl.TEXTURE_2D, texture);
            gl.texImage2D(gl.TEXTURE_2D, 0,
                gl.RGBA8, 1, 1, 0,
                gl.RGBA, gl.UNSIGNED_BYTE,
                new Uint8Array([255, 255, 255, 255])
            );

            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
            gl.bindTexture(gl.TEXTURE_2D, null);

            // shader default texture
            this.shader_default_texture = texture;

            // shader texture unit allocate
            this.shader_texture_unit_allocator = new TextureUnitAllocator(
                gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS)
            );
        }
    }

    /** **/
    public getCanvas() : HTMLCanvasElement | OffscreenCanvas | null {
        return this.gl ? this.gl.canvas : null;
    }

    public setColor(r : RGBA);
    public setColor(r : number, g? : number, b? : number, a? : number)
    public setColor(r_or_rgba : number | RGBA, g? : number, b? : number, a? : number) : void {
        if (r_or_rgba instanceof RGBA) {
            this.color.r = r_or_rgba.r;
            this.color.g = r_or_rgba.g;
            this.color.b = r_or_rgba.b;
            this.color.a = r_or_rgba.a;
        } else {
            this.color.r = r_or_rgba;
            this.color.g = g ?? r_or_rgba;
            this.color.b = b ?? (g ?? r_or_rgba);
            this.color.a = a ?? 1;
        }
    }

    public getColor() : RGBA {
        return this.color.clone();
    }

    public isValid(): this is { gl: WebGL2RenderingContext } {
        return this.gl !== null;
    }

    /** **/
    public free() : void {
        const gl = this.gl;
        if (gl === null) return;

        const ext = gl.getExtension("WEBGL_lose_context");
        if (ext !== null) ext.loseContext();

        this.gl = null;
    }

    /** **/
    public clear(r: number = 0, g: number = 0, b: number = 0, a: number = 1): void {
        if (!this.isValid()) return;
        const gl = this.gl;

        const is_stencil_draw = this.stencil_mode === StencilMode.DRAW;
        if (is_stencil_draw) {
            gl.colorMask(true, true, true, true);
            gl.depthMask(true);
        }

        gl.clearColor(r, g, b, a);
        gl.clearDepth(1.0);
        gl.clearStencil(0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT);

        if (is_stencil_draw) {
            gl.colorMask(false, false, false, false);
            gl.depthMask(false);
        }
    }

    /** **/
    private getBlendParams(mode: BlendMode) : [GLenum, GLenum, GLenum] {
        const gl = this.gl;
        if (gl === null) throw new Error("In GLContext.getBlendParams: context is invalid");

        switch (mode) {
            case BlendMode.ALPHA:
                return [gl.FUNC_ADD, gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA];
            case BlendMode.PREMULTIPLIED_ALPHA:
                return [gl.FUNC_ADD, gl.ONE, gl.ONE_MINUS_SRC_ALPHA];
            case BlendMode.ADD:
                return [gl.FUNC_ADD, gl.ONE, gl.ONE];
            case BlendMode.SUBTRACT:
                return [gl.FUNC_SUBTRACT, gl.ONE, gl.ONE];
            case BlendMode.REVERSE_SUBTRACT:
                return [gl.FUNC_REVERSE_SUBTRACT, gl.ONE, gl.ONE];
            case BlendMode.MULTIPLY:
                return [gl.FUNC_ADD, gl.DST_COLOR, gl.ZERO];
            default:
                throw new Error(`In GlContext.getBlendParam: unhandled blend mode: ${mode}`);
        }
    }

    /** **/
    public setTransform(transform : Transform) {
        this.transform = transform;
    }

    /** **/
    public setBlendmode(rgb : BlendMode, alpha : BlendMode = BlendMode.ALPHA) : void {
        const gl = this.gl;
        if (gl === null) return;

        if (rgb == BlendMode.NONE && alpha == BlendMode.NONE) {
            gl.disable(gl.BLEND)
            return
        }

        gl.enable(gl.BLEND)
        const [equation_rgb, source_factor_rgb, destination_factor_rgb] = this.getBlendParams(rgb);
        const [equation_a, source_factor_a, destination_factor_a] = this.getBlendParams(alpha);

        gl.blendEquationSeparate(equation_rgb, equation_a)
        gl.blendFuncSeparate(source_factor_rgb, destination_factor_rgb, source_factor_a, destination_factor_a)

        this.blend_mode_rgb = rgb;
        this.blend_mode_alpha = alpha;
    }

    /** **/
    public setStencilMode(mode : StencilMode, value : number = 1) : void {
        const gl = this.gl;
        if (gl === null) return;

        switch (mode) {
            case StencilMode.DRAW:
                gl.enable(gl.STENCIL_TEST);
                gl.stencilFunc(gl.ALWAYS, value, ~0x0);
                gl.stencilOp(gl.REPLACE, gl.REPLACE, gl.REPLACE);
                gl.colorMask(false, false, false, false);
                gl.depthMask(false);
                break;
            case StencilMode.TEST:
                gl.enable(gl.STENCIL_TEST);
                gl.stencilFunc(gl.EQUAL, value, ~0x0);
                gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP);
                gl.colorMask(true, true, true, true);
                gl.depthMask(true);
                break;
            case StencilMode.NONE:
                gl.disable(gl.STENCIL_TEST);
                gl.colorMask(true, true, true, true);
                gl.depthMask(true);
                break;
            default:
                throw new Error(`In GLContext.setStencilMode: unhandled mode ${mode}`);
        }

        this.stencil_mode = mode;
        this.stencil_value = value;
    }

    /** **/
    public push() : void;
    public push(...push_targets : PushTarget[]) : void;
    public push(...push_targets : PushTarget[]) : void {
        if (this.push_stack.length + 1 > max_stack_depth)
            throw Error("In GLContext.push: maximum stack depth reached")

        let node: PushNode = {
            color: undefined,
            blend_mode_rgb: undefined,
            blend_mode_alpha: undefined,
            stencil_mode: undefined,
            stencil_value: undefined,
            transform: undefined
        };

        const targets = (push_targets.length == 0 || push_targets.includes(PushTarget.ALL))
            ? [PushTarget.COLOR, PushTarget.BLEND_MODE, PushTarget.STENCIL_MODE, PushTarget.TRANSFORM]
            : push_targets;

        for (const target of targets) {
            switch (target) {
                case PushTarget.COLOR:
                    node.color = this.color.clone();
                    break;
                case PushTarget.BLEND_MODE:
                    node.blend_mode_rgb = this.blend_mode_rgb;
                    node.blend_mode_alpha = this.blend_mode_alpha;
                    break;
                case PushTarget.STENCIL_MODE:
                    node.stencil_mode = this.stencil_mode;
                    node.stencil_value = this.stencil_value;
                    break;
                case PushTarget.TRANSFORM:
                    node.transform = this.transform.clone();
                    break;
            }
        }

        this.push_stack.push(node);
    }

    /** **/
    public pop() : void {
        if (this.push_stack.length == 0)
            throw Error("In GLContext.pop: minimum stack depth reached")

        const node = this.push_stack.pop()!;

        if (node.color !== undefined)
            this.setColor(node.color);

        if (node.blend_mode_rgb !== undefined)
            this.setBlendmode(node.blend_mode_rgb, node.blend_mode_alpha);

        if (node.stencil_mode !== undefined)
            this.setStencilMode(node.stencil_mode, node.stencil_value);

        if (node.transform !== undefined)
            this.setTransform(node.transform);
    }

    /** **/
    public with(...push_targets: PushTarget[]): Disposable {
        this.push(...push_targets);
        return {
            [Symbol.dispose]: () => this.pop()
        };
    }

    /** **/
    private set_render_texture(texture : RenderTexture) {
        if (this.gl === null) return;

        const gl = this.gl;
        gl.bindFramebuffer(gl.FRAMEBUFFER, texture.getFrameBuffer());
        gl.viewport(0, 0, texture.getWidth(), texture.getHeight());
    }

    /** @internal */
    public _notify_render_texture_bound(texture : RenderTexture) {
        this.render_texture_stack.push(texture);
        this.set_render_texture(texture);
    }

    /** @internal */
    public _notify_render_texture_unbound(texture: RenderTexture) {
        if (this.gl === null) return;

        if (this.render_texture_stack.peek() !== texture)
            throw new Error("In RenderTexture.unbind: texture is not currently bound");

        this.render_texture_stack.pop();
        texture.flush();

        const previous = this.render_texture_stack.peek();
        if (previous !== undefined) {
            this.set_render_texture(previous);
        } else {
            // bind framebuffer
            const gl = this.gl;
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
        }
    }

    /** **/
    private set_shader(shader : Shader) {
        if (this.gl === null) return;
        const gl = this.gl;

        const native = shader.getNative();
        if (native === null) return;

        gl.useProgram(native);

        const flags = shader._get_are_defaults_bound();

        const texture_location = shader.getUniformLocation(DEFAULT_TEXTURE_NAME)
        if (!flags.texture_bound && texture_location !== undefined) {
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, this.shader_default_texture);
            gl.uniform1i(texture_location, 0);
        }

        const size_location = shader.getUniformLocation(DEFAULT_SCREEN_SIZE_NAME);
        if (!flags.screen_size_bound && size_location !== undefined) {
            gl.uniform2f(size_location, gl.canvas.width, gl.canvas.height)
        }

        const color_location = shader.getUniformLocation(DEFAULT_COLOR_NAME);
        if (!flags.color_bound && color_location !== undefined) {
            gl.uniform4f(color_location, this.color.r, this.color.g, this.color.b, this.color.a)
        }

        const transform_location = shader.getUniformLocation(DEFAULT_TRANSFORM_NAME)
        if (!flags.transform_bound && transform_location !== undefined) {
            gl.uniformMatrix4fv(transform_location, false, this.transform.getData())
        }
    }

    /** */
    public getTextureUnit(texture : Texture) : number {
        const native = texture.getNative();
        if (this.gl === null || native === null) return -1;
        return this.shader_texture_unit_allocator.allocate(native);
    }

    /** @internal */
    public _notify_shader_bound(shader : Shader) {
        this.shader_stack.push(shader);
        this.set_shader(shader);
    }

    /** @internal */
    public _notify_shader_unbound(shader : Shader) {
        if (this.gl === null) return;
        if (this.shader_stack.peek() !== shader)
            throw new Error("In Shader.unbind: shader is not currently bound");

        this.shader_stack.pop();

        const previous = this.shader_stack.peek();
        if (previous !== undefined) {
            this.set_shader(previous)
        } else {
            // noop, default shader set in _notify_curren_mesh_format
        }
    }

    /** @internal */
    public _notify_size_changed(width : number, height : number) {
        if (this.gl !== null)
            this.gl.viewport(0, 0, width, height);
    }

    /** @internal */
    public _notify_current_mesh_format(format : MeshVertexFormat) {
        if (this.gl === null) return;

        // if no shader active, use default shader
        if (this.shader_stack.isEmpty()) {
            if (!this.mesh_vertex_format_to_default_shader.has(format)) {
                this.mesh_vertex_format_to_default_shader.set(format, new Shader(
                    this,
                    undefined,
                    undefined,
                    format
                ));
            }

            this.set_shader(this.mesh_vertex_format_to_default_shader.get(format)!);
        }
    }
}