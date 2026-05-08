const makeDebugContext: typeof import("webgl-debug").makeDebugContext = await import("webgl-debug")
    // safe import, if package is missing, becomes noop
    .then(m => m.makeDebugContext)
    .catch(() => (context: WebGL2RenderingContext) => context
);

export type GLContext = WebGL2RenderingContext | null;

export function clear(context: GLContext, clear_color? : boolean, clear_stencil : boolean = false, clear_depth : boolean = false) {
    if (context === null) return;

    let mask = 0;
    if (clear_color !== false) mask |= context.COLOR_BUFFER_BIT;
    if (clear_stencil) mask |= context.STENCIL_BUFFER_BIT;
    if (clear_depth)  mask |= context.DEPTH_BUFFER_BIT;
    context.clear(mask);
}

export function getGLContext(canvas_name: string): GLContext {
    const canvas = document.querySelector<HTMLCanvasElement>(`canvas[name="${canvas_name}"]`);
    if (canvas === null) return null;

    const context = canvas.getContext("webgl2");
    if (context == null) return null;

    return makeDebugContext(context);
}

export enum BlendMode {
    ALPHA, // standard alpha blending
    PREMULTIPLIED_ALPHA, // premultiplied alpha blending
    ADD, // src + dst
    SUBTRACT, // src - dst
    REVERSE_SUBTRACT, // dst - src
    MULTIPLY // src * dst
}

function getBlendParams(
    gl: GLContext,
    mode: BlendMode
): [equation: number, source_factor: number, destination_factor: number] {
    if (gl === null) return [0, 0, 0];

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
            throw new Error(`Unknown BlendMode: ${mode}`);
    }
}

export function setBlendMode(context : GLContext, rgb : BlendMode, alpha : BlendMode = BlendMode.ALPHA) : void {
    const gl = context;
    if (gl === null) return;

    gl.enable(gl.BLEND)
    const [equation_rgb, source_factor_rgb, destination_factor_rgb] = getBlendParams(gl, rgb);
    const [equation_a, source_factor_a, destination_factor_a] = getBlendParams(gl, alpha);

    gl.blendEquationSeparate(equation_rgb, equation_a)
    gl.blendFuncSeparate(source_factor_rgb, destination_factor_rgb, source_factor_a, destination_factor_a)
}

export enum StencilMode {
    DRAW, // draw to stencil buffer, do not draw to back buffer
    TEST, // test against stencil buffer
    NONE // disable stencil
}

export function setStencilMode(context : GLContext, mode : StencilMode, value : number = 1) : void {
    const gl = context;
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
            throw new Error(`In setStencilMode: unhandled mode ${mode}`);
    }
}


