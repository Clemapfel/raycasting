export enum MeshVertexFormat {
    XY_UV_RGBA,
    XY_UV,
    XY_RGBA,
    XY
}

export const MESH_VERTEX_FORMAT_TO_N_COMPONENTS = {
    [MeshVertexFormat.XY_UV_RGBA]: 8,
    [MeshVertexFormat.XY_UV]:      4,
    [MeshVertexFormat.XY_RGBA]:    6,
    [MeshVertexFormat.XY]:         2,
};