import { RGBA } from "./color.ts";
import { Vec2 } from "./vector.ts";
import { RenderTexture } from "./texture.ts";
import { Shader } from "./shader.ts";
import { Deque } from "./deque.ts";
import type { Render } from "astro:content";

const makeDebugContext: typeof import("webgl-debug").makeDebugContext = await import("webgl-debug")
    // safe import, if package is missing, becomes noop
    .then(m => m.makeDebugContext)
    .catch(() => (context: WebGL2RenderingContext) => context
);

/** **/
export enum BlendMode {
    NONE,
    ALPHA, // standard alpha blending
    PREMULTIPLIED_ALPHA, // premultiplied alpha blending
    ADD, // src + dst
    SUBTRACT, // src - dst
    REVERSE_SUBTRACT, // dst - src
    MULTIPLY // src * dst
}

/** **/
export enum StencilMode {
    DRAW, // draw to stencil buffer, do not draw to back buffer
    TEST, // test against stencil buffer
    NONE // disable stencil
}

const max_stack_depth = 512;

/** **/
export enum PushTarget {
    ALL = 0x0,
    COLOR = 0x1 << 0,
    BLEND_MODE = 0x1 << 1,
    STENCIL_MODE = 0x1 << 2
}

/** **/
interface PushNode {
    color : RGBA | undefined,
    blend_mode_rgb : BlendMode | undefined,
    blend_mode_alpha : BlendMode | undefined,
    stencil_mode : StencilMode | undefined,
    stencil_value : number | undefined
}

/** **/
export class GLContext {
    public gl : WebGL2RenderingContext | null;
    public default_texture : WebGLTexture | undefined = undefined;

    // state
    private blend_mode_rgb : BlendMode = BlendMode.ALPHA;
    private blend_mode_alpha : BlendMode = BlendMode.ALPHA;
    private stencil_mode : StencilMode = StencilMode.NONE;
    private stencil_value : number = 0x0;
    private color : RGBA = new RGBA(1, 1, 1, 1);
    private push_stack : Deque<PushNode> = new Deque<PushNode>();
    private render_texture_stack : Deque<RenderTexture> = new Deque<RenderTexture>();
    private shader_stack : Deque<Shader> = new Deque<Shader>();

    constructor(canvas: HTMLCanvasElement) {
        this.gl = canvas.getContext("webgl2", {
            antialias: true,
            powerPreference: "high-performance",
            alpha: true,
            depth: true,
            stencil: true,
            desynchronized: true
        });
    }

    /** **/
    public getCanvas() : HTMLCanvasElement | OffscreenCanvas | null {
        if (this.gl !== null)
            return this.gl.canvas;
        else
            return null;
    }

    public setColor(r : RGBA);
    public setColor(r : number, g? : number, b? : number, a? : number)
    public setColor(r_or_rgba : number | RGBA, g? : number, b? : number, a? : number) : void {
        if (r_or_rgba instanceof RGBA) {
            ({
                r: this.color.r,
                g: this.color.g,
                b: this.color.b,
                a: this.color.a
            } = r_or_rgba as RGBA);
        } else {
            const r : number = r_or_rgba;
            this.color.r = r;
            this.color.g = g ?? r;
            this.color.b = b ?? g ?? r;
            this.color.a = a ?? 1;
        }
    }

    public getColor() : RGBA {
        return this.color.clone();
    }

    /**
     * if valid, narrows itself to native context
     *
     * @example
     * if (!this.context.isValid()) return;
     * const { gl } = this.context; // gl: WebGL2RenderingContext
     */
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
            throw Error("In GLContext.push: maximum stack depth reached. More pushes than pops?")

        const current_render_texture = (this.render_texture_stack.length == 0 ? null : this.render_texture_stack.peek()) ?? null

        let node: PushNode;
        if (push_targets.length == 0 || (push_targets.includes(PushTarget.ALL))) {
            // push everything
            node = {
                color: this.color.clone(),
                blend_mode_rgb: this.blend_mode_rgb,
                blend_mode_alpha: this.blend_mode_alpha,
                stencil_mode: this.stencil_mode,
                stencil_value: this.stencil_value
            }
        }
        else {
            // push specified
            node = {
                color: undefined,
                blend_mode_rgb: undefined,
                blend_mode_alpha: undefined,
                stencil_mode: undefined,
                stencil_value: undefined
            };

            for (let i = 0; i < push_targets.length; i++) {
                const target = push_targets[i];
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
                    case PushTarget.ALL:
                        // unreachable
                        break;
                    default:
                        throw Error(`In GLContext.push: unhandled push target ${target}`)
                }
            }
        }

        this.push_stack.push(node);
    }

    /** **/
    public pop() : void {
        if (this.push_stack.length == 0)
            throw Error("In GLContext: minimum stack depth reached, more pops than pushes?")

        const node = this.push_stack.pop()!;

        if (node.color !== undefined)
            this.setColor(node.color);

        if (node.blend_mode_rgb !== undefined || node.blend_mode_alpha !== undefined)
            this.setBlendmode(
                node.blend_mode_rgb ?? BlendMode.ALPHA,
                node.blend_mode_alpha
            );

        if (node.stencil_mode !== undefined || node.stencil_value !== undefined)
            this.setStencilMode(
                node.stencil_mode ?? StencilMode.NONE,
                node.stencil_value
            );
    }

    /** **/
    public with(...push_targets: PushTarget[]): Disposable {
        this.push(...push_targets);
        return {
            [Symbol.dispose]: () => this.pop()
        };
    }

    /** **/
    private _set_render_texture(texture : RenderTexture) {
        if (this.gl === null) return;

        const gl = this.gl;
        gl.bindFramebuffer(gl.FRAMEBUFFER, texture.getFrameBuffer());
        gl.viewport(0, 0, texture.getWidth(), texture.getHeight());
    }

    /** @internal */
    public _notify_render_texture_bound(texture : RenderTexture) {
        this.render_texture_stack.push(texture);
        this._set_render_texture(texture);
    }

    /** @internal */
    public _notify_render_texture_unbound(texture: RenderTexture) {
        if (this.gl === null) return;

        const current = this.render_texture_stack.peek();

        if (current !== texture)
            throw new Error("In RenderTexture.unbind: texture is not currently bound");

        this.render_texture_stack.pop();
        current.flush(); // blit MSAA buffer to draw buffer

        const gl = this.gl;
        const previous = this.render_texture_stack.peek();
        if (previous !== undefined) {
            this._set_render_texture(previous);
        } else {
            // bind backbuffer
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
        }
    }

    /** @internal */
    public _notify_shader_bound(shader : Shader) {
        this.shader_stack.push(shader);

        if (this.gl !== null)
            shader._make_current(this.gl);
    }

    /** @internal */
    public _notify_shader_unbound(shader : Shader) {
        if (this.gl === null) return;
        const current = this.shader_stack.peek();

        if (current !== shader)
            throw new Error("In Shader.unbind: shader is not currently bound");

        this.shader_stack.pop();

        const gl = this.gl;
        const previous = this.shader_stack.peek();
        if (previous !== undefined) {
            // bind previous shader
            previous._make_current(gl);
        } else {
            // unbind shaders
            gl.useProgram(null);
            gl.bindTexture(gl.TEXTURE_2D, null);
        }
    }

    /** @internal */
    public _notify_size_changed(width : number, height : number) {
        if (this.gl !== null)
            this.gl.viewport(0, 0, width, height);
    }
}
