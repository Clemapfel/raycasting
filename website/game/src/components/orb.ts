import { GLContext } from "../common/gl_context.ts";
import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { Shader } from "../common/shader.ts";
import {
    Texture, RenderTexture,
    TextureFormat, TextureFilterMode, TextureWrapMode
} from "../common/texture.ts";

import { RGBA, LCHA } from "../common/color.ts";
import { Time } from "../common/time.ts";

import { Vec2 } from "../common/vector.ts";

export class Orb extends GLWidget  {

    private particle_mesh? : Mesh;
    private particle_texture? : Texture;
    private canvas? : RenderTexture;

    protected override realize() {
    }
}