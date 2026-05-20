import type { GLContext } from "./gl_context.ts";
import { Vec2 } from "./vector.ts";

/** **/
export enum TextureFilterMode {
    NEAREST,
    LINEAR,
}

/** **/
export enum TextureWrapMode {
    REPEAT,
    CLAMP,
    MIRROR
}

/** **/
export enum TextureFormat {
    // 8-bit Color
    RGBA8, RGB8, RG8, R8,
    // 16-bit Float Color
    RGBA16F, RGB16F, RG16F, R16F,
    // 32-bit Float Color
    RGBA32F, RGB32F, RG32F, R32F,
    // 8-bit Integer Color
    RGBA8UI, RGBA8I, RGB8UI, RGB8I, RG8UI, RG8I, R8UI, R8I,
    // 16-bit Integer Color
    RGBA16UI, RGBA16I, RGB16UI, RGB16I, RG16UI, RG16I, R16UI, R16I,
    // 32-bit Integer Color
    RGBA32UI, RGBA32I, RGB32UI, RGB32I, RG32UI, RG32I, R32UI, R32I,
    // Packed / Special Color
    RGB10_A2, RGB565, RGB5_A1, RGBA4,
    SRGB8_ALPHA8, SRGB8,
    R11F_G11F_B10F, RGB9_E5,
    // Depth / Stencil
    DEPTH_COMPONENT16, DEPTH_COMPONENT24, DEPTH_COMPONENT32F,
    DEPTH24_STENCIL8, DEPTH32F_STENCIL8
}

interface FormatInfo {
    internal_format: number;
    source_format: number;
    type: number;
    bytes_per_pixel: number;
    is_color: boolean;
    is_depth: boolean;
    is_stencil: boolean;
    is_float: boolean;
    is_half_float: boolean;
    is_integer: boolean;
}

const resolve_texture_format = (gl: WebGL2RenderingContext, format: TextureFormat): FormatInfo => {
    const create = (
        internal: number, src: number, type: number, bpp: number,
        flags: { color?: boolean, depth?: boolean, stencil?: boolean, float?: boolean, half_float?: boolean, integer?: boolean } = {}
    ): FormatInfo => ({
        internal_format: internal, source_format: src, type: type, bytes_per_pixel: bpp,
        is_color: flags.color ?? false, is_depth: flags.depth ?? false, is_stencil: flags.stencil ?? false,
        is_float: flags.float ?? false, is_half_float: flags.half_float ?? false, is_integer: flags.integer ?? false
    });

    if (gl === null) return create(0, 0, 0, 0);

    gl.getExtension("EXT_color_buffer_float");
    gl.getExtension("EXT_float_blend");
    gl.getExtension("EXT_color_buffer_half_float");

    switch (format) {
        case TextureFormat.RGBA8: return create(gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, 4, { color: true });
        case TextureFormat.RGB8: return create(gl.RGB8, gl.RGB, gl.UNSIGNED_BYTE, 3, { color: true });
        case TextureFormat.RG8: return create(gl.RG8, gl.RG, gl.UNSIGNED_BYTE, 2, { color: true });
        case TextureFormat.R8: return create(gl.R8, gl.RED, gl.UNSIGNED_BYTE, 1, { color: true });

        case TextureFormat.RGBA16F: return create(gl.RGBA16F, gl.RGBA, gl.HALF_FLOAT, 8, { color: true, half_float: true });
        case TextureFormat.RGB16F: return create(gl.RGB16F, gl.RGB, gl.HALF_FLOAT, 6, { color: true, half_float: true });
        case TextureFormat.RG16F: return create(gl.RG16F, gl.RG, gl.HALF_FLOAT, 4, { color: true, half_float: true });
        case TextureFormat.R16F: return create(gl.R16F, gl.RED, gl.HALF_FLOAT, 2, { color: true, half_float: true });

        case TextureFormat.RGBA32F: return create(gl.RGBA32F, gl.RGBA, gl.FLOAT, 16, { color: true, float: true });
        case TextureFormat.RGB32F: return create(gl.RGB32F, gl.RGB, gl.FLOAT, 12, { color: true, float: true });
        case TextureFormat.RG32F: return create(gl.RG32F, gl.RG, gl.FLOAT, 8, { color: true, float: true });
        case TextureFormat.R32F: return create(gl.R32F, gl.RED, gl.FLOAT, 4, { color: true, float: true });

        case TextureFormat.RGBA8UI: return create(gl.RGBA8UI, gl.RGBA_INTEGER, gl.UNSIGNED_BYTE, 4, { color: true, integer: true });
        case TextureFormat.RGBA8I: return create(gl.RGBA8I, gl.RGBA_INTEGER, gl.BYTE, 4, { color: true, integer: true });
        case TextureFormat.RGB8UI: return create(gl.RGB8UI, gl.RGB_INTEGER, gl.UNSIGNED_BYTE, 3, { color: true, integer: true });
        case TextureFormat.RGB8I: return create(gl.RGB8I, gl.RGB_INTEGER, gl.BYTE, 3, { color: true, integer: true });
        case TextureFormat.RG8UI: return create(gl.RG8UI, gl.RG_INTEGER, gl.UNSIGNED_BYTE, 2, { color: true, integer: true });
        case TextureFormat.RG8I: return create(gl.RG8I, gl.RG_INTEGER, gl.BYTE, 2, { color: true, integer: true });
        case TextureFormat.R8UI: return create(gl.R8UI, gl.RED_INTEGER, gl.UNSIGNED_BYTE, 1, { color: true, integer: true });
        case TextureFormat.R8I: return create(gl.R8I, gl.RED_INTEGER, gl.BYTE, 1, { color: true, integer: true });

        case TextureFormat.RGBA16UI: return create(gl.RGBA16UI, gl.RGBA_INTEGER, gl.UNSIGNED_SHORT, 8, { color: true, integer: true });
        case TextureFormat.RGBA16I: return create(gl.RGBA16I, gl.RGBA_INTEGER, gl.SHORT, 8, { color: true, integer: true });
        case TextureFormat.RGB16UI: return create(gl.RGB16UI, gl.RGB_INTEGER, gl.UNSIGNED_SHORT, 6, { color: true, integer: true });
        case TextureFormat.RGB16I: return create(gl.RGB16I, gl.RGB_INTEGER, gl.SHORT, 6, { color: true, integer: true });
        case TextureFormat.RG16UI: return create(gl.RG16UI, gl.RG_INTEGER, gl.UNSIGNED_SHORT, 4, { color: true, integer: true });
        case TextureFormat.RG16I: return create(gl.RG16I, gl.RG_INTEGER, gl.SHORT, 4, { color: true, integer: true });
        case TextureFormat.R16UI: return create(gl.R16UI, gl.RED_INTEGER, gl.UNSIGNED_SHORT, 2, { color: true, integer: true });
        case TextureFormat.R16I: return create(gl.R16I, gl.RED_INTEGER, gl.SHORT, 2, { color: true, integer: true });

        case TextureFormat.RGBA32UI: return create(gl.RGBA32UI, gl.RGBA_INTEGER, gl.UNSIGNED_INT, 16, { color: true, integer: true });
        case TextureFormat.RGBA32I: return create(gl.RGBA32I, gl.RGBA_INTEGER, gl.INT, 16, { color: true, integer: true });
        case TextureFormat.RGB32UI: return create(gl.RGB32UI, gl.RGB_INTEGER, gl.UNSIGNED_INT, 12, { color: true, integer: true });
        case TextureFormat.RGB32I: return create(gl.RGB32I, gl.RGB_INTEGER, gl.INT, 12, { color: true, integer: true });
        case TextureFormat.RG32UI: return create(gl.RG32UI, gl.RG_INTEGER, gl.UNSIGNED_INT, 8, { color: true, integer: true });
        case TextureFormat.RG32I: return create(gl.RG32I, gl.RG_INTEGER, gl.INT, 8, { color: true, integer: true });
        case TextureFormat.R32UI: return create(gl.R32UI, gl.RED_INTEGER, gl.UNSIGNED_INT, 4, { color: true, integer: true });
        case TextureFormat.R32I: return create(gl.R32I, gl.RED_INTEGER, gl.INT, 4, { color: true, integer: true });

        case TextureFormat.RGB10_A2: return create(gl.RGB10_A2, gl.RGBA, gl.UNSIGNED_INT_2_10_10_10_REV, 4, { color: true });
        case TextureFormat.RGB565: return create(gl.RGB565, gl.RGB, gl.UNSIGNED_SHORT_5_6_5, 2, { color: true });
        case TextureFormat.RGB5_A1: return create(gl.RGB5_A1, gl.RGBA, gl.UNSIGNED_SHORT_5_5_5_1, 2, { color: true });
        case TextureFormat.RGBA4: return create(gl.RGBA4, gl.RGBA, gl.UNSIGNED_SHORT_4_4_4_4, 2, { color: true });
        case TextureFormat.SRGB8_ALPHA8: return create(gl.SRGB8_ALPHA8, gl.RGBA, gl.UNSIGNED_BYTE, 4, { color: true });
        case TextureFormat.SRGB8: return create(gl.SRGB8, gl.RGB, gl.UNSIGNED_BYTE, 3, { color: true });
        case TextureFormat.R11F_G11F_B10F: return create(gl.R11F_G11F_B10F, gl.RGB, gl.UNSIGNED_INT_10F_11F_11F_REV, 4, { color: true, float: true });
        case TextureFormat.RGB9_E5: return create(gl.RGB9_E5, gl.RGB, gl.UNSIGNED_INT_5_9_9_9_REV, 4, { color: true, float: true });

        case TextureFormat.DEPTH_COMPONENT16: return create(gl.DEPTH_COMPONENT16, gl.DEPTH_COMPONENT, gl.UNSIGNED_SHORT, 2, { depth: true });
        case TextureFormat.DEPTH_COMPONENT24: return create(gl.DEPTH_COMPONENT24, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, 4, { depth: true });
        case TextureFormat.DEPTH_COMPONENT32F: return create(gl.DEPTH_COMPONENT32F, gl.DEPTH_COMPONENT, gl.FLOAT, 4, { depth: true, float: true });
        case TextureFormat.DEPTH24_STENCIL8: return create(gl.DEPTH24_STENCIL8, gl.DEPTH_STENCIL, gl.UNSIGNED_INT_24_8, 4, { depth: true, stencil: true });
        case TextureFormat.DEPTH32F_STENCIL8: return create(gl.DEPTH32F_STENCIL8, gl.DEPTH_STENCIL, gl.FLOAT_32_UNSIGNED_INT_24_8_REV, 8, { depth: true, stencil: true, float: true });

        default:
            throw new Error(`In Texture: unsupported texture format ${format}`);
    }
}

/** **/
export class Texture {
    private width: number = 0;
    private height: number = 0;

    protected native: WebGLTexture;
    protected context: GLContext;
    protected format_info: FormatInfo;

    /** **/
    constructor(context: GLContext, image: HTMLImageElement);

    /** **/
    constructor(context: GLContext, width: number, height: number, format?: number);

    // ctor
    constructor(context: GLContext, image_or_width: HTMLImageElement | number, height?: number, format?: TextureFormat) {
        this.context = context;
        if (!this.context.isValid()) {
            this.native = null as unknown as WebGLTexture;
            this.format_info = {} as FormatInfo;
            return;
        }
        const { gl } = this.context;

        const texture = gl.createTexture();
        if (texture === null)
            throw new Error("In Texture: unable to create texture");

        this.native = texture;

        if (image_or_width instanceof HTMLImageElement) {
            const image = image_or_width;
            this.format_info = resolve_texture_format(gl, TextureFormat.RGBA8);

            gl.bindTexture(gl.TEXTURE_2D, this.native);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
            gl.generateMipmap(gl.TEXTURE_2D);
            this.width = image.width;
            this.height = image.height;
            gl.bindTexture(gl.TEXTURE_2D, null);
        }
        else {
            let width = image_or_width;
            if (height === undefined) height = width;
            if (format === undefined) format = TextureFormat.RGBA8;

            width = Math.max(1, Math.floor(width));
            height = Math.max(1, Math.floor(height));

            this.format_info = resolve_texture_format(gl, format);

            gl.bindTexture(gl.TEXTURE_2D, this.native);
            gl.texImage2D(gl.TEXTURE_2D, 0, this.format_info.internal_format, width, height, 0, this.format_info.source_format, this.format_info.type, null);
            gl.bindTexture(gl.TEXTURE_2D, null);

            this.width = width;
            this.height = height;
        }

        this.setFilterMode(TextureFilterMode.LINEAR);
        this.setWrapMode(TextureWrapMode.CLAMP);
    }

    /** **/
    public setFilterMode(filter_min: TextureFilterMode, filter_mag?: TextureFilterMode, anisotropy?: boolean): void {
        if (filter_mag === undefined) filter_mag = filter_min;
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        const ext_anisotropic = gl.getExtension("EXT_texture_filter_anisotropic");
        if (ext_anisotropic === null) anisotropy = false;

        let safe_min = filter_min;
        let safe_mag = filter_mag;

        if (this.format_info) {
            const missing_float_linear = this.format_info.is_float && !gl.getExtension("OES_texture_float_linear");
            const missing_half_linear = this.format_info.is_half_float && !gl.getExtension("OES_texture_half_float_linear");

            if (this.format_info.is_integer || this.format_info.is_depth || missing_float_linear || missing_half_linear) {
                safe_min = TextureFilterMode.NEAREST;
                safe_mag = TextureFilterMode.NEAREST;
            }
        }

        const to_native = (mode: TextureFilterMode) => {
            if (mode == TextureFilterMode.NEAREST) return gl.NEAREST;
            else if (mode == TextureFilterMode.LINEAR) return gl.LINEAR;
            else throw new Error(`In Texture.setFilterMode: unhandled filter mode ${mode}`);
        }

        gl.bindTexture(gl.TEXTURE_2D, this.native);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, to_native(safe_min));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, to_native(safe_mag));

        if (anisotropy && ext_anisotropic) {
            const max_anisotropy = gl.getParameter(ext_anisotropic.MAX_TEXTURE_MAX_ANISOTROPY_EXT);
            gl.texParameterf(gl.TEXTURE_2D, ext_anisotropic.TEXTURE_MAX_ANISOTROPY_EXT, max_anisotropy);
        } else if (ext_anisotropic) {
            gl.texParameterf(gl.TEXTURE_2D, ext_anisotropic.TEXTURE_MAX_ANISOTROPY_EXT, 1.0);
        }

        gl.bindTexture(gl.TEXTURE_2D, null);
    }

    /** **/
    public setWrapMode(wrap_s: TextureWrapMode, wrap_t?: TextureWrapMode): void {
        if (wrap_t === undefined) wrap_t = wrap_s;
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        const to_native = (mode: TextureWrapMode) => {
            if (mode == TextureWrapMode.REPEAT)
                return gl.REPEAT;
            else if (mode == TextureWrapMode.CLAMP)
                return gl.CLAMP_TO_EDGE;
            else if (mode == TextureWrapMode.MIRROR)
                return gl.MIRRORED_REPEAT;
            else
                throw new Error(`In Texture.setWrapMode: unhandled wrap mode ${mode}`);
        }

        gl.bindTexture(gl.TEXTURE_2D, this.native);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, to_native(wrap_s));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, to_native(wrap_t));
        gl.bindTexture(gl.TEXTURE_2D, null);
    }

    /** **/
    public free(): void {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.native !== null)
            gl.deleteTexture(this.native);
    }

    /** **/
    public getNative(): WebGLTexture {
        return this.native;
    }

    /** **/
    public getWidth(): number {
        const gl = this.context; if (gl === null) return 0;
        return this.width;
    }

    /** **/
    public getHeight(): number {
        const gl = this.context; if (gl === null) return 0;
        return this.height;
    }

    /** **/
    public getSize(): Vec2 {
        const gl = this.context; if (gl === null) return new Vec2(0, 0);
        return new Vec2(this.width, this.height);
    }
}

export class RenderTexture extends Texture {
    private resolve_framebuffer: WebGLFramebuffer | null = null;
    private multisample_framebuffer: WebGLFramebuffer | null = null;
    private color_renderbuffer: WebGLRenderbuffer | null = null;
    private depth_renderbuffer: WebGLRenderbuffer | null = null;
    private readonly msaa: number;

    constructor(
        context: GLContext,
        width: number,
        height: number,
        format: TextureFormat = TextureFormat.RGBA8,
        msaa: number = 2
    ) {
        super(context, width, height, format);

        if (!this.context.isValid()) {
            this.msaa = 0;
            return;
        }

        const { gl } = this.context;

        width = Math.max(1, Math.floor(width));
        height = Math.max(1, Math.floor(height));

        const info = this.format_info;

        // Ensure MSAA request does not exceed hardware limits for this specific format
        let safe_msaa = Math.max(0, msaa);
        if (safe_msaa > 0) {
            const format_samples = gl.getInternalformatParameter(gl.RENDERBUFFER, info.internal_format, gl.SAMPLES) as Int32Array;
            const max_samples = (format_samples && format_samples.length > 0) ? format_samples[0] : 0;
            safe_msaa = Math.min(safe_msaa, max_samples);
        }

        // Multisampling and then resolving depth/stencil formats is unreliable across implementations
        if (info.is_depth) {
            safe_msaa = 0;
        }

        this.msaa = safe_msaa;

        try {
            this.resolve_framebuffer = gl.createFramebuffer();
            if (this.resolve_framebuffer === null)
                throw new Error("In RenderTexture: unable to create resolve framebuffer");

            if (this.msaa === 0) {
                gl.bindFramebuffer(gl.FRAMEBUFFER, this.resolve_framebuffer);

                if (info.is_color) {
                    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.native, 0);

                    this.depth_renderbuffer = gl.createRenderbuffer();
                    if (this.depth_renderbuffer === null)
                        throw new Error("In RenderTexture: unable to create depth renderbuffer");

                    gl.bindRenderbuffer(gl.RENDERBUFFER, this.depth_renderbuffer);
                    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, width, height);
                    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, this.depth_renderbuffer);
                } else {
                    const depth_attach = info.is_stencil ? gl.DEPTH_STENCIL_ATTACHMENT : gl.DEPTH_ATTACHMENT;
                    gl.framebufferTexture2D(gl.FRAMEBUFFER, depth_attach, gl.TEXTURE_2D, this.native, 0);
                    // A framebuffer without color attachments needs explicit instructions
                    gl.drawBuffers([gl.NONE]);
                    gl.readBuffer(gl.NONE);
                }

                const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
                if (status !== gl.FRAMEBUFFER_COMPLETE) {
                    throw new Error(`In RenderTexture: framebuffer incomplete (${width}x${height}): ${status}`);
                }
            }
            else {
                this.multisample_framebuffer = gl.createFramebuffer();
                if (this.multisample_framebuffer === null)
                    throw new Error("In RenderTexture: unable to create multisample framebuffer");

                gl.bindFramebuffer(gl.FRAMEBUFFER, this.multisample_framebuffer);

                this.color_renderbuffer = gl.createRenderbuffer();
                if (this.color_renderbuffer === null)
                    throw new Error("In RenderTexture: unable to create color renderbuffer");

                gl.bindRenderbuffer(gl.RENDERBUFFER, this.color_renderbuffer);
                gl.renderbufferStorageMultisample(gl.RENDERBUFFER, this.msaa, info.internal_format, width, height);
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, this.color_renderbuffer);

                this.depth_renderbuffer = gl.createRenderbuffer();
                if (this.depth_renderbuffer === null)
                    throw new Error("In RenderTexture: unable to create depth renderbuffer");

                gl.bindRenderbuffer(gl.RENDERBUFFER, this.depth_renderbuffer);
                gl.renderbufferStorageMultisample(gl.RENDERBUFFER, this.msaa, gl.DEPTH24_STENCIL8, width, height);
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, this.depth_renderbuffer);

                let status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
                if (status !== gl.FRAMEBUFFER_COMPLETE) {
                    throw new Error(`In RenderTexture: multisample framebuffer incomplete (${width}x${height}, msaa=${this.msaa}): ${status}`);
                }

                // Bind the actual texture to the resolve target
                gl.bindFramebuffer(gl.FRAMEBUFFER, this.resolve_framebuffer);
                gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.native, 0);
            }
        } catch (error) {
            this.free();
            throw error;
        } finally {
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            gl.bindRenderbuffer(gl.RENDERBUFFER, null);
        }
    }

    public bind(): void {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.msaa === 0)
            gl.bindFramebuffer(gl.FRAMEBUFFER, this.resolve_framebuffer);
        else
            gl.bindFramebuffer(gl.FRAMEBUFFER, this.multisample_framebuffer);

        gl.viewport(0, 0, this.getWidth(), this.getHeight());
    }

    public unbind(): void {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.msaa === 0) {
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
            return;
        }

        const width = this.getWidth();
        const height = this.getHeight();

        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, this.multisample_framebuffer);
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, this.resolve_framebuffer);

        gl.blitFramebuffer(
            0, 0, width, height,
            0, 0, width, height,
            gl.COLOR_BUFFER_BIT,
            gl.NEAREST
        );

        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, null);

        gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    }

    public override free(): void {
        if (!this.context.isValid()) return;

        const { gl } = this.context;

        if (this.color_renderbuffer !== null) {
            gl.deleteRenderbuffer(this.color_renderbuffer);
            this.color_renderbuffer = null;
        }

        if (this.depth_renderbuffer !== null) {
            gl.deleteRenderbuffer(this.depth_renderbuffer);
            this.depth_renderbuffer = null;
        }

        if (this.multisample_framebuffer !== null) {
            gl.deleteFramebuffer(this.multisample_framebuffer);
            this.multisample_framebuffer = null;
        }

        if (this.resolve_framebuffer !== null) {
            gl.deleteFramebuffer(this.resolve_framebuffer);
            this.resolve_framebuffer = null;
        }

        super.free();
    }
}