import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshRectangle } from "../common/mesh.ts";
import { Shader, default_transform_name } from "../common/shader.ts";
import { Time } from "../common/time.ts";

export const default_elapsed_name = "elapsed";

export class ShaderCanvas extends GLWidget {
    private shader_program? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(Math.random());

    protected override realize() : void {
        const source_code = this.getAttribute("fragment-shader-source");
        if (!source_code)
            throw new Error("ShaderCanvas: Attribute 'fragment-shader-source' is missing.");

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
            0, 0,
            width, height
        );
    }

    protected override update(delta: Time): void {
        this.elapsed.add(delta);
    }

    protected override draw(): void {
        if (this.shader_program === undefined || this.quad === undefined) return;

        if (this.shader_program.hasUniform(default_elapsed_name))
            this.shader_program.setUniform(default_elapsed_name, this.elapsed.asSeconds());

        this.shader_program.bind();
        this.shader_program.setUniform( // ignore global pixel transform
            default_transform_name,
            Shader.default_transform.asIdentity()
        );
        this.quad.draw();
        this.shader_program.unbind();
    }
}