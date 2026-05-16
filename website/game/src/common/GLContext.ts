import { RGBA } from "./Colors.ts";
import { Vec2 } from "./Vector.ts";

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

/** **/
export class GLContext {
    public gl : WebGL2RenderingContext | null;
    public default_texture : WebGLTexture | undefined = undefined;

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

    /** **/
    public getScale() : Vec2 {
        return this.scale;
    }

    // state
    private color : RGBA = new RGBA(1, 1, 1, 1);

    public setColor(r, g, b, a) : void {
        this.color.r = r;
        this.color.g = g;
        this.color.b = b;
        this.color.a = a;
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
    public clear(
        clear_color : boolean = true,
        clear_stencil : boolean = false,
        clear_depth : boolean = false
    ) : void {
        const gl = this.gl;
        if (gl === null) return;

        let mask = 0;
        if (clear_color) mask |= gl.COLOR_BUFFER_BIT;
        if (clear_stencil) mask |= gl.STENCIL_BUFFER_BIT;
        if (clear_depth)  mask |= gl.DEPTH_BUFFER_BIT;
        gl.clear(mask);
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
    }
}
