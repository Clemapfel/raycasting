import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Shader, DEFAULT_TRANSFORM_NAME } from "../common/shader.ts";
import { Time } from "../common/time.ts";

const default_elapsed_name = "elapsed";

export class ShaderCanvas extends GLWidget {
    private shader_program? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(Math.random());

    protected override async realize() {
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

        this.quad = new Mesh(
            this.context,
            new Float32Array([
                0, 0,           0, 0,   1, 1, 1, 1,
                width, 0,       1, 0,   1, 1, 1, 1,
                width, height,  1, 1,   1, 1, 1, 1,
                0, height,      0, 1,    1, 1, 1, 1
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
        if (this.shader_program === undefined || this.quad === undefined) return;

        if (this.shader_program.hasUniform(default_elapsed_name))
            this.shader_program.setUniform(default_elapsed_name, this.elapsed.asSeconds());

        this.shader_program.bind();
        this.quad.draw();
        this.shader_program.unbind();
    }
}