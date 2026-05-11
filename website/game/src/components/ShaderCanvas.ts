import { GLWidget } from "../common/GLWidget.ts";
import { Mesh, MeshRectangle } from "../common/Mesh.ts";
import { Shader } from "../common/Shader.ts";
import { type Seconds } from "../common/Time.ts";

const UNIFORM_ELAPSED_TIME = "elapsed";
const UNIFORM_SCREEN_RESOLUTION = "screen_size";

export class ShaderCanvas extends GLWidget {
    private shader_program?: Shader;
    private quad?: Mesh;
    private elapsed: number = Math.random() * 10e6;

    protected override realize(): void {
        const source_code = this.getAttribute("fragment-shader-source");
        if (!source_code) {
            throw new Error("ShaderCanvas: Attribute 'fragment-shader-source' is missing.");
        }

        this.shader_program = new Shader(this.context, source_code);
    }
    
    protected override unrealize() : void {
        if (this.shader_program !== undefined) 
            this.shader_program.free();
    }

    protected override reformat(width: number, height: number): void {
        if (this.quad !== undefined) 
            this.quad.free();

        this.quad = MeshRectangle(
            this.context,
            0,
            0,
            width,
            height
        );
    }

    protected override update(delta: Seconds): void {
        this.elapsed += delta;
    }

    protected override draw(): void {
        if (!this.shader_program || !this.quad) return;

        if (this.shader_program.hasUniform(UNIFORM_ELAPSED_TIME)) {
            this.shader_program.setUniform(UNIFORM_ELAPSED_TIME, this.elapsed);
        }

        if (this.shader_program.hasUniform(UNIFORM_SCREEN_RESOLUTION)) {
            this.shader_program.setUniform(UNIFORM_SCREEN_RESOLUTION, this.getSize());
        }

        this.shader_program.bind();
        this.quad.draw();
        this.shader_program.unbind();
    }
}