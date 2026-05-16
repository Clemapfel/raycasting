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
    RGBA8,
    RG8,
    R8,
    RGBA16F,
    RG16F,
    R16F,
    RGBA32F,
    RG32F,
    R32F,
    DEPTH16,
    DEPTH24,
    DEPTH32F,
    DEPTH24_STENCIL8,
    DEPTH32F_STENCIL8
}

const resolve_texture_format = (gl : WebGL2RenderingContext, format: TextureFormat): {
    internal_format: number,
    source_format: number,
    type: number,
    bytes_per_pixel: number
} => {
    if (gl === null) return { internal_format: 0x0, source_format: 0x0, type: 0x0, bytes_per_pixel: 0x0 }

    switch (format) {
        case TextureFormat.RGBA8:
            return { internal_format: gl.RGBA8,              source_format: gl.RGBA, type: gl.UNSIGNED_BYTE, bytes_per_pixel: 4 };
        case TextureFormat.RG8:
            return { internal_format: gl.RG8,                source_format: gl.RG,              type: gl.UNSIGNED_BYTE,               bytes_per_pixel: 2  };
        case TextureFormat.R8:
            return { internal_format: gl.R8,                 source_format: gl.RED,             type: gl.UNSIGNED_BYTE,               bytes_per_pixel: 1  };
        case TextureFormat.RGBA16F:
            return { internal_format: gl.RGBA16F,            source_format: gl.RGBA,            type: gl.HALF_FLOAT,                  bytes_per_pixel: 8  };
        case TextureFormat.RG16F:
            return { internal_format: gl.RG16F,              source_format: gl.RG,              type: gl.HALF_FLOAT,                  bytes_per_pixel: 4  };
        case TextureFormat.R16F:
            return { internal_format: gl.R16F,               source_format: gl.RED,             type: gl.HALF_FLOAT,                  bytes_per_pixel: 2  };
        case TextureFormat.RGBA32F:
            return { internal_format: gl.RGBA32F,            source_format: gl.RGBA,            type: gl.FLOAT,                       bytes_per_pixel: 16 };
        case TextureFormat.RG32F:
            return { internal_format: gl.RG32F,              source_format: gl.RG,              type: gl.FLOAT,                       bytes_per_pixel: 8  };
        case TextureFormat.R32F:
            return { internal_format: gl.R32F,               source_format: gl.RED,             type: gl.FLOAT,                       bytes_per_pixel: 4  };
        case TextureFormat.DEPTH16:
            return { internal_format: gl.DEPTH_COMPONENT16,  source_format: gl.DEPTH_COMPONENT, type: gl.UNSIGNED_SHORT,              bytes_per_pixel: 2  };
        case TextureFormat.DEPTH24:
            return { internal_format: gl.DEPTH_COMPONENT24,  source_format: gl.DEPTH_COMPONENT, type: gl.UNSIGNED_INT,                bytes_per_pixel: 4  };
        case TextureFormat.DEPTH32F:
            return { internal_format: gl.DEPTH_COMPONENT32F, source_format: gl.DEPTH_COMPONENT, type: gl.FLOAT,                       bytes_per_pixel: 4  };
        case TextureFormat.DEPTH24_STENCIL8:
            return { internal_format: gl.DEPTH24_STENCIL8,   source_format: gl.DEPTH_STENCIL,   type: gl.UNSIGNED_INT_24_8,           bytes_per_pixel: 4  };
        case TextureFormat.DEPTH32F_STENCIL8:
            return { internal_format: gl.DEPTH32F_STENCIL8,  source_format: gl.DEPTH_STENCIL,   type: gl.FLOAT_32_UNSIGNED_INT_24_8_REV, bytes_per_pixel: 8 };
        default:
            throw new Error(`In Texture: unsupported texture format ${format}`)
    }
}

/** **/
export class Texture {
    private width : number = 0;
    private height : number = 0;

    protected native : WebGLTexture;
    protected context : GLContext;

    /** **/
    constructor(context : GLContext, image: HTMLImageElement);

    /** **/
    constructor(context: GLContext, width: number, height: number, format?: number);

    // ctor
    constructor(context : GLContext, image_or_width: HTMLImageElement | number, height?: number, format?: TextureFormat) {
        this.context = context;
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        const texture = gl.createTexture();
        if (texture === null) throw new Error("In Texture: unable to create texture")
        this.native = texture;

        if (image_or_width instanceof HTMLImageElement) {
            // read from thml image, always RGBA8
            const image = image_or_width;
            gl.bindTexture(gl.TEXTURE_2D, this.native);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
            this.width = image.width;
            this.height = image.height;
        }
        else {
            const width = image_or_width;
            if (height === undefined) height = width;
            if (format === undefined) format = TextureFormat.RGBA8;
            const { internal_format, source_format, type, bytes_per_pixel } = resolve_texture_format(gl, format);

            gl.bindTexture(gl.TEXTURE_2D, this.native);
            gl.texImage2D(gl.TEXTURE_2D, 0, internal_format, width, height, 0, source_format, type, null);
            gl.bindTexture(gl.TEXTURE_2D, null);

            this.width = width;
            this.height = height;
        }

        this.setFilterMode(TextureFilterMode.LINEAR);
        this.setWrapMode(TextureWrapMode.CLAMP);
    }

    /** **/
    public setFilterMode(filter_min : TextureFilterMode, filter_mag? : TextureFilterMode) : void {
        if (filter_mag === undefined) filter_mag = filter_min;
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        const to_native = (mode : TextureFilterMode) => {
            if (mode == TextureFilterMode.NEAREST)
                return gl.NEAREST;
            else if (mode == TextureFilterMode.LINEAR)
                return gl.LINEAR;
            else
                throw new Error(`In Texture.setFilterMode: unhandled filter mode ${mode}`);
        }

        gl.bindTexture(gl.TEXTURE_2D, this.native);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, to_native(filter_min));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, to_native(filter_mag));
        gl.bindTexture(gl.TEXTURE_2D, null);
    }

    /** **/
    public setWrapMode(wrap_s : TextureWrapMode, wrap_t? : TextureWrapMode) : void {
        if (wrap_t === undefined) wrap_t = wrap_s;
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        const to_native = (mode : TextureWrapMode) => {
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
    public free() : void {
        if (!this.context.isValid()) return;
        const { gl } = this.context;
        if (this.native) gl.deleteTexture(this.native);
    }

    /** **/
    public getNative() : WebGLTexture {
        return this.native;
    }

    /** **/
    public getWidth() : number {
        const gl = this.context; if (gl === null) return 0;
        return this.width;
    }

    /** **/
    public getHeight() : number {
        const gl = this.context; if (gl === null) return 0;
        return this.height;
    }

    /** **/
    public getSize() : Vec2 {
        const gl = this.context; if (gl === null) return new Vec2(0, 0);
        return new Vec2(this.width, this.height);
    }
}

export class RenderTexture extends Texture {

    private msaa_framebuffer: WebGLFramebuffer | null = null;
    private resolve_framebuffer: WebGLFramebuffer;
    private sample_count: number;

    constructor(context: GLContext, width: number, height: number, format?: number, msaa: number = 1) {
        if (format === undefined) format = TextureFormat.RGBA8;
        super(context, width, height, format);

        this.sample_count = Math.min(msaa, (() => {
            if (!context.isValid()) return 1;
            return context.gl.getParameter(context.gl.MAX_SAMPLES);
        })());

        if (!this.context.isValid()) return;
        const { gl } = this.context;

        const attachment_point = ((format: TextureFormat): number => {
            if (format === TextureFormat.DEPTH24_STENCIL8 || format === TextureFormat.DEPTH32F_STENCIL8)
                return gl.DEPTH_STENCIL_ATTACHMENT;
            else if (format === TextureFormat.DEPTH16 || format === TextureFormat.DEPTH24 || format === TextureFormat.DEPTH32F)
                return gl.DEPTH_ATTACHMENT;
            else
                return gl.COLOR_ATTACHMENT0;
        })(format);

        const { internal_format } = resolve_texture_format(gl, format);

        const resolve_framebuffer = gl.createFramebuffer();
        if (resolve_framebuffer === null) throw new Error("In RenderTexture: unable to create resolve framebuffer");
        this.resolve_framebuffer = resolve_framebuffer;

        gl.bindFramebuffer(gl.FRAMEBUFFER, resolve_framebuffer);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, attachment_point, gl.TEXTURE_2D, this.native, 0);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE)
            throw new Error("In RenderTexture: resolve framebuffer incomplete");

        if (this.sample_count > 1) {
            const msaa_framebuffer = gl.createFramebuffer();
            if (msaa_framebuffer === null) throw new Error("In RenderTexture: unable to create msaa framebuffer");
            this.msaa_framebuffer = msaa_framebuffer;

            const color_renderbuffer = gl.createRenderbuffer();
            if (color_renderbuffer === null) throw new Error("In RenderTexture: unable to create msaa renderbuffer");

            gl.bindFramebuffer(gl.FRAMEBUFFER, msaa_framebuffer);
            gl.bindRenderbuffer(gl.RENDERBUFFER, color_renderbuffer);
            gl.renderbufferStorageMultisample(gl.RENDERBUFFER, this.sample_count, internal_format, width, height);
            gl.framebufferRenderbuffer(gl.FRAMEBUFFER, attachment_point, gl.RENDERBUFFER, color_renderbuffer);

            if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE)
                throw new Error("In RenderTexture: msaa framebuffer incomplete");
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        gl.bindRenderbuffer(gl.RENDERBUFFER, null);
    }

    public free() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;
        super.free();
        if (this.msaa_framebuffer) gl.deleteFramebuffer(this.msaa_framebuffer);
        if (this.resolve_framebuffer) gl.deleteFramebuffer(this.resolve_framebuffer);
    }

    public bind() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;
        gl.bindFramebuffer(gl.FRAMEBUFFER, this.msaa_framebuffer ?? this.resolve_framebuffer);
    }

    public unbind() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.msaa_framebuffer !== null) {
            const width = this.getWidth();
            const height = this.getHeight();
            gl.bindFramebuffer(gl.READ_FRAMEBUFFER, this.msaa_framebuffer);
            gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, this.resolve_framebuffer);
            gl.blitFramebuffer(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST);
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    }
}