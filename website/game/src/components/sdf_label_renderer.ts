import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Texture, TextureFilterMode } from "../common/texture.ts";
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

const DEFAULT_ELAPSED_NAME = "elapsed";

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
        
        vec4 texel = texture(${DEFAULT_TEXTURE_NAME}, uv);
        float dist = texel.r;
        dist = smoothstep(center - eps, center + eps, dist);
        ${DEFAULT_FRAGMENT_OUT_NAME} = vec4(dist);
    }
    `;

export class SDFLabelRenderer extends GLWidget {
    private shader? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(0);
    private texture_source : string;
    private texture : Texture;

    constructor(path: string) {
        super();
        this.texture_source = path;
    }

    protected override async realize() {
        this.texture = new Texture(this.context, "404.png");
        this.texture.setFilterMode(TextureFilterMode.LINEAR);

        this.shader = new Shader(this.context, canvas_threshold_shader_source);
    }
    
    protected override reformat(width: number, height: number): void {
        if (this.quad !== undefined)
            this.quad.deallocate();

        this.quad = new Mesh(
            this.context,
            new Float32Array([
                0, 0,           0, 0,   1, 1, 1, 1,
                width, 0,       1, 0,   1, 1, 1, 1,
                width, height,  1, 1,   1, 1, 1, 1,
                0, height,      0, 1,   1, 1, 1, 1
            ]),
            new Uint16Array([ 0, 1, 2, 0, 2, 3 ]),
            MeshDrawMode.TRIANGLES,
            MeshVertexFormat.XY_UV_RGBA
        )
    }

    protected override update(delta: Time): void {
        this.elapsed.add(delta);
    }

    protected override draw(): void {
        if (!this.getIsRealized() || this.shader === undefined || this.quad === undefined) return;

        if (this.shader.hasUniform(DEFAULT_ELAPSED_NAME))
            this.shader.setUniform(DEFAULT_ELAPSED_NAME, this.elapsed.asSeconds());

        if (this.shader.hasUniform(DEFAULT_TEXTURE_NAME))
            this.shader.setUniform(DEFAULT_TEXTURE_NAME, this.texture);

        this.shader.bind();
        this.quad.draw();
        this.shader.unbind();
    }
}