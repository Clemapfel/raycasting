import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Texture, TextureFilterMode } from "../common/texture.ts";
import { BlendMode } from "../common/gl_context.ts";
import {
    DEFAULT_FLOAT_PRECISION,
    DEFAULT_FRAGMENT_OUT_NAME,
    DEFAULT_RGBA_NAME,
    DEFAULT_SCREEN_POS_NAME,
    DEFAULT_SHADER_VERSION,
    DEFAULT_TEXTURE_NAME,
    DEFAULT_UV_NAME,
    Shader
} from "../common/shader.ts";
import { Time } from "../common/time.ts";
import type { Vec2 } from "../common/vector.ts";

const DEFAULT_ELAPSED_NAME = "elapsed";
const APPLY_BLUR_NAME = "apply_blur";

const canvas_threshold_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}
    
    vec3 lch_to_rgb(vec3 lch) {
        float L = lch.x * 100.0;
        float C = lch.y * 100.0;
        float H = lch.z * 360.0;
    
        float a = cos(radians(H)) * C;
        float b = sin(radians(H)) * C;
    
        float Y = (L + 16.0) / 116.0;
        float X = a / 500.0 + Y;
        float Z = Y - b / 200.0;
    
        X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
        Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
        Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);
    
        float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
        float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
        float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;
    
        R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
        G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
        B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;
    
        return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
    }
    
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

    uniform sampler2D ${DEFAULT_TEXTURE_NAME};
    uniform float ${DEFAULT_ELAPSED_NAME};
    uniform bool ${APPLY_BLUR_NAME};
    
    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};
    
    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
    
    void main() {
        const float eps = 0.04;
        const float center = 0.07;
        
        vec2 seed = ${DEFAULT_SCREEN_POS_NAME} / 20.0;
        const float seed_magnitude = 0.005;
        vec2 uv = ${DEFAULT_UV_NAME} + vec2(
            seed_magnitude * gradient_noise(vec3(seed, elapsed)),
            seed_magnitude * gradient_noise(vec3(-seed.yx, elapsed))
        );
        
        float dist;
        if (${APPLY_BLUR_NAME}) {
            const float kernel[25] = float[25](
                 1.0 / 256.0,  4.0 / 256.0,  6.0 / 256.0,  4.0 / 256.0,  1.0 / 256.0,
                 4.0 / 256.0, 16.0 / 256.0, 24.0 / 256.0, 16.0 / 256.0,  4.0 / 256.0,
                 6.0 / 256.0, 24.0 / 256.0, 36.0 / 256.0, 24.0 / 256.0,  6.0 / 256.0,
                 4.0 / 256.0, 16.0 / 256.0, 24.0 / 256.0, 16.0 / 256.0,  4.0 / 256.0,
                 1.0 / 256.0,  4.0 / 256.0,  6.0 / 256.0,  4.0 / 256.0,  1.0 / 256.0
            );
            
            vec2 texel_size = 1.0 / vec2(textureSize(${DEFAULT_TEXTURE_NAME}, 0));
            
            dist = 0.0;
            for (int y = -2; y <= 2; y++) {
                for (int x = -2; x <= 2; x++) {
                    vec2 offset = vec2(float(x), float(y)) * texel_size;
                    dist += kernel[(y + 2) * 5 + (x + 2)]
                          * texture(${DEFAULT_TEXTURE_NAME}, uv + offset).r;
                }
            }
        } 
        else {
             dist = texture(${DEFAULT_TEXTURE_NAME}, uv).r;
        }
        
        dist = 1.0 - smoothstep(center - eps, center + eps, dist);        
        ${DEFAULT_FRAGMENT_OUT_NAME} = vec4(dist);
    }
    `;

export class SDFLabelRenderer extends GLWidget {
    private shader? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(0);
    private texture_source : string;
    private texture : Texture;

    public apply_blur : boolean = true;

    protected override async realize() {
        const path = this.getAttribute("path");
        if (path === null)
            throw new Error("<sdf-label-renderer> requires a 'path' attribute");

        this.texture = new Texture(this.context, path);
        this.texture.setFilterMode(TextureFilterMode.LINEAR);

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
    }

    public override getSize() : Vec2 {
        return this.texture.getSize();
    }

    protected override draw(): void {
        if (!this.getIsRealized() || this.shader === undefined || this.quad === undefined) return;

        if (this.shader.hasUniform(DEFAULT_ELAPSED_NAME))
            this.shader.setUniform(DEFAULT_ELAPSED_NAME, this.elapsed.asSeconds());

        if (this.shader.hasUniform(DEFAULT_TEXTURE_NAME))
            this.shader.setUniform(DEFAULT_TEXTURE_NAME, this.texture);

        if (this.shader.hasUniform(APPLY_BLUR_NAME))
            this.shader.setUniform(APPLY_BLUR_NAME, this.apply_blur)

        this.context.setBlendMode(BlendMode.ALPHA)
        this.shader.bind();
        this.quad.draw();
        this.shader.unbind();
    }
}