import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Shader, DEFAULT_TRANSFORM_NAME } from "../common/shader.ts";
import { Time } from "../common/time.ts";
import { Vec2 } from "../common/vector.ts";

const default_cursor_position_name = "cursor_position";
const default_cursor_is_visible_name = "cursor_is_visible";
const default_elapsed_name = "elapsed";
const default_screen_size_name = "screen_size";

export class ShaderCanvas extends GLWidget {
    private shader_program? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(0);

    private cursor_position : Vec2 = new Vec2();
    private cursor_visible : boolean = false;

    protected override async realize() {
        const source_code = this.getAttribute("fragment-shader-source");
        if (!source_code)
            throw new Error("ShaderCanvas: Attribute 'fragment-shader-source' is missing.");

        this.shader_program = new Shader(this.context, source_code);

        this.cursor_visible = true;
        this.cursor_position.x = 0.5 * this.getWidth();
        this.cursor_position.y = 0.5 * this.getHeight();
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
                0, height,      0, 1,    1, 1, 1, 1
            ]),
            new Uint16Array([ 0, 1, 2, 0, 2, 3 ]),
            MeshDrawMode.TRIANGLES,
            MeshVertexFormat.XY_UV_RGBA
        )
    }

    protected override onMouseMoved(x: number, y: number, event: MouseEvent) {
        this.cursor_position.x = x;
        this.cursor_position.y = y;
    }

    protected override onMouseEnter(event: MouseEvent) {
        this.cursor_visible = true;
    }

    protected override onMouseLeave(event: MouseEvent) {
        this.cursor_visible = false;
    }

    protected override update(delta: Time): void {
        this.elapsed.add(delta);
    }


    protected override draw(): void {
        if (!this.getIsRealized() ||this.shader_program === undefined || this.quad === undefined) return;

        if (this.shader_program.hasUniform(default_elapsed_name))
            this.shader_program.setUniform(default_elapsed_name, this.elapsed.asSeconds());

        if (this.shader_program.hasUniform(default_cursor_position_name))
                this.shader_program.setUniform(default_cursor_position_name, this.cursor_position);

        if (this.shader_program.hasUniform(default_cursor_is_visible_name))
            this.shader_program.setUniform(default_cursor_is_visible_name, this.cursor_visible)

        this.shader_program.bind();
        this.quad.draw();
        this.shader_program.unbind();
    }
}