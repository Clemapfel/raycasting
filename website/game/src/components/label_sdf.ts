import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Texture, TextureFilterMode } from "../common/texture.ts";
import { BlendMode } from "../common/gl_context.ts";
import {
    DEFAULT_COLOR_NAME,
    DEFAULT_FLOAT_PRECISION,
    DEFAULT_FRAGMENT_OUT_NAME,
    DEFAULT_RGBA_NAME,
    DEFAULT_SCREEN_POS_NAME, DEFAULT_SCREEN_SIZE_NAME,
    DEFAULT_SHADER_VERSION,
    DEFAULT_TEXTURE_NAME,
    DEFAULT_UV_NAME,
    Shader
} from "../common/shader.ts";
import { Time } from "../common/time.ts";
import { Vec2 } from "../common/vector.ts";
import { SmoothedMotion } from "../common/smoothed_motion.ts";
import { RGBA, OKLCHA, parseOKLCHA, parseRGBA } from "../common/color.ts";

const DEFAULT_ELAPSED_NAME = "elapsed";
const APPLY_BLUR_NAME = "apply_blur";
const MASK_T_NAME = "mask_t";
const RGB_NAME = "rgb";
const FOREGROUND_COLOR_NAME = "foreground";
const BACKGROUND_COLOR_NAME = "background";
const SCALE_NAME = "scale";

const canvas_threshold_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}
   
    vec3 random_3d(in vec3 p) {
        return fract(sin(vec3(
        dot(p, vec3(127.1, 311.7, 74.7)),
        dot(p, vec3(269.5, 183.3, 246.1)),
        dot(p, vec3(113.5, 271.9, 124.6)))
        ) * 43758.5453123);
    }
    
    float gradient_noise(vec3 p) {
        vec3 i = floor(p);
        vec3 v = fract(p);
    
        vec3 u = v * v * v * (v * (v * 6.0 - 15.0) + 10.0);
    
        return mix( mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 0.0)), v - vec3(0.0, 0.0, 0.0)),
        dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 0.0)), v - vec3(1.0, 0.0, 0.0)), u.x),
        mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 0.0)), v - vec3(0.0, 1.0, 0.0)),
        dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 0.0)), v - vec3(1.0, 1.0, 0.0)), u.x), u.y),
        mix( mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 0.0, 1.0)), v - vec3(0.0, 0.0, 1.0)),
        dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 0.0, 1.0)), v - vec3(1.0, 0.0, 1.0)), u.x),
        mix( dot( -1.0 + 2.0 * random_3d(i + vec3(0.0, 1.0, 1.0)), v - vec3(0.0, 1.0, 1.0)),
        dot( -1.0 + 2.0 * random_3d(i + vec3(1.0, 1.0, 1.0)), v - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z );
    }
    
    vec4 max4(vec4 a, vec4 b) {
        return mix(b, a, step(b, a));
    }

    uniform sampler2D ${DEFAULT_TEXTURE_NAME};
    uniform float ${DEFAULT_ELAPSED_NAME};
    uniform bool ${APPLY_BLUR_NAME};
    uniform float ${MASK_T_NAME};
    uniform vec4 ${DEFAULT_COLOR_NAME};
    uniform vec4 ${FOREGROUND_COLOR_NAME};
    uniform vec4 ${BACKGROUND_COLOR_NAME};
    uniform float ${SCALE_NAME};
    
    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};
    
    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
    
    void main() {
    
    float center = 0.4 * scale;
    float eps = 0.1 * scale;
    float outline = 0.2 * scale;
    float fill = -0.1 * scale;

    vec2 seed = ${DEFAULT_SCREEN_POS_NAME} / 20.0;
    float seed_magnitude = mix(0.008, 0.012, ${MASK_T_NAME}) * scale;

    vec2 noise = vec2(
        gradient_noise(vec3(scale * seed, elapsed)),
        gradient_noise(vec3(-scale * seed.yx, elapsed))
    );
    vec2 uv = ${DEFAULT_UV_NAME} + seed_magnitude * noise;

    const float kernel[25] = float[25](
         1.0 / 256.0,  4.0 / 256.0,  6.0 / 256.0,  4.0 / 256.0,  1.0 / 256.0,
         4.0 / 256.0, 16.0 / 256.0, 24.0 / 256.0, 16.0 / 256.0,  4.0 / 256.0,
         6.0 / 256.0, 24.0 / 256.0, 36.0 / 256.0, 24.0 / 256.0,  6.0 / 256.0,
         4.0 / 256.0, 16.0 / 256.0, 24.0 / 256.0, 16.0 / 256.0,  4.0 / 256.0,
         1.0 / 256.0,  4.0 / 256.0,  6.0 / 256.0,  4.0 / 256.0,  1.0 / 256.0
    );

    vec2 texel_size = 1.0 / vec2(textureSize(${DEFAULT_TEXTURE_NAME}, 0));

    vec2 d = vec2(0.0);

    if (${APPLY_BLUR_NAME}) {
        const int kernel_size = 5;
        const int radius = kernel_size / 2;

        for (int y = -radius; y <= radius; y++) {
            for (int x = -radius; x <= radius; x++) {
                vec2 offset = vec2(x, y) * texel_size;
                d += kernel[(y + radius) * kernel_size + (x + radius)]
                   * texture(${DEFAULT_TEXTURE_NAME}, uv + offset).rg;
            }
        }
    } else {
        d = texture(${DEFAULT_TEXTURE_NAME}, uv).rg;
    }

    float line_t = 1.0 - smoothstep(
        max(0.0, center - eps), 
        min(1.0, center + eps), 
        d.r
    );

    float outline_t = 1.0 - smoothstep(
        max(0.0, (center + outline) - eps),
        min(1.0, (center + outline) + eps), 
        d.r
    ) - line_t;
    
    float fill_t = 1.0 - smoothstep(
        max(0.0, (center + fill) - eps),
        min(1.0, (center + fill) + eps), 
        d.g
    ) - outline_t - line_t;
    
    fill_t *= mix(0.9, 1.2, (noise.x + 1.0) / 2.0);
    
    
    ${DEFAULT_FRAGMENT_OUT_NAME} = ${BACKGROUND_COLOR_NAME} * outline_t
        + mix( ${DEFAULT_COLOR_NAME}, ${FOREGROUND_COLOR_NAME}, ${MASK_T_NAME}) * line_t
        + mix(${BACKGROUND_COLOR_NAME}, ${DEFAULT_COLOR_NAME}, ${MASK_T_NAME}) * fill_t
    ;
}
`;

export class LabelSDF extends GLWidget {
    private shader? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(0);
    private motion : SmoothedMotion = new SmoothedMotion(0);
    private texture_source : string;
    private texture : Texture;

    public apply_blur : boolean = true;
    public reactive : boolean = true;
    public scale : number = 1.0;

    protected override async realize() {
        const path = this.getAttribute("path");
        if (path === null)
            throw new Error("<label-sdf> requires a 'path' attribute");

        this.apply_blur = this.getAttribute("blur") === "true";
        this.reactive = this.getAttribute("reactive") === "true";

        const scale_str = this.getAttribute("scale");
        this.scale = scale_str ? parseFloat(scale_str) : 1.0;

        this.texture = new Texture(this.context, path);
        this.texture.setFilterMode(TextureFilterMode.LINEAR);
        this.texture.connectOnLoad((texture : Texture) => {
            const [ tex_w, tex_h ] = texture.getSize();
            if (tex_w > 0 && tex_h > 0) {
                this.style.aspectRatio = `${tex_w} / ${tex_h}`;
                this.style.flex = `${tex_w / tex_h}`;
            }

            const [ w, h ] = this.getSize();
            this.reformat(w, h);
        });

        this.shader = new Shader(this.context, canvas_threshold_shader_source);
    }

    protected override reformat(width: number, height: number): void {
        if (this.quad !== undefined)
            this.quad.deallocate();

        const [tex_w, tex_h] = this.texture.getSize();

        const scale = Math.min(width / tex_w, height / tex_h);
        const quad_w = tex_w * scale;
        const quad_h = tex_h * scale;

        const x0 = (width - quad_w) / 2;
        const y0 = (height - quad_h) / 2;
        const x1 = x0 + quad_w;
        const y1 = y0 + quad_h;

        this.quad = new Mesh(
            this.context,
            new Float32Array([
                x0, y0,  0, 0,   1, 1, 1, 1,
                x1, y0,  1, 0,   1, 1, 1, 1,
                x1, y1,  1, 1,   1, 1, 1, 1,
                x0, y1,  0, 1,   1, 1, 1, 1
            ]),
            new Uint16Array([ 0, 1, 2, 0, 2, 3 ]),
            MeshDrawMode.TRIANGLES,
            MeshVertexFormat.XY_UV_RGBA
        )
    }

    protected override update(delta: Time): void {
        this.elapsed.add(delta);
        this.motion.update(delta);
    }

    protected override draw(): void {
        if (!this.getIsRealized() || this.shader === undefined || this.quad === undefined) return;

        this.shader.trySetUniform(DEFAULT_ELAPSED_NAME, this.elapsed.asSeconds());
        this.shader.trySetUniform(DEFAULT_TEXTURE_NAME, this.texture);
        this.shader.trySetUniform(APPLY_BLUR_NAME, this.apply_blur);

        if (this.reactive)
            this.shader.trySetUniform(MASK_T_NAME, this.motion.getValue());
        else
            this.shader.trySetUniform(MASK_T_NAME, 1);

        const oklch : OKLCHA = parseOKLCHA(getComputedStyle(this).color);
        this.shader.trySetUniform(DEFAULT_COLOR_NAME, oklch.asRGBA());

        const foreground : RGBA = parseRGBA(getComputedStyle(this).getPropertyValue("--default-color-foreground"));
        this.shader.trySetUniform(FOREGROUND_COLOR_NAME, foreground);
        
        const background : RGBA = parseRGBA(getComputedStyle(this).getPropertyValue("--default-color-background"));
        this.shader.trySetUniform(BACKGROUND_COLOR_NAME, background)

        this.shader.trySetUniform(SCALE_NAME, this.scale);

        this.context.setBlendMode(BlendMode.ALPHA)
        this.shader.bind();
        this.quad.draw();
        this.shader.unbind();
    }

    protected override onMouseEnter(event: MouseEvent) {
        this.motion.setTargetValue(1);
    }

    protected override onMouseLeave(event: MouseEvent) {
        this.motion.setTargetValue(0);
    }
}