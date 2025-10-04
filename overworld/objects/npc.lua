require "common.delaunay_triangulation"
require "overworld.player_recorder_body"
require "overworld.player_recorder_eyes"
require "common.render_texture_3d"

rt.settings.overworld.npc = {
   canvas_radius = 200,
   canvas_padding = 20,

   eye_mesh_width = 100,
   eye_mesh_height = 100,
   eye_mesh_curvature = 20
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    assert(object:get_type() == ow.ObjectType.POINT, "NPC should be Point")
    self._position_x = object.x
    self._position_y = object.y

    local radius = rt.settings.overworld.npc.canvas_radius
    local padding = rt.settings.overworld.npc.canvas_padding
    self._eyes = ow.PlayerRecorderEyes(radius, 0, 0)
    self._eyes_texture =rt.RenderTexture(
        2 * (radius + padding), 2 * (radius + padding)
    )
    self._eyes_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._3d_texture = rt.RenderTexture3D(
        2 * (radius + 2 * padding), 2 * (radius + 2 * padding)
    )

    self._model_transform = rt.Transform()
    self._view_transform = rt.Transform()
    self._view_transform:translate(0, 0, -2 * radius)

    self._center_x, self._center_y, self._center_z = 0, 0, 0
    self._eye_mesh = rt.MeshPlane(
        self._center_x, self._center_y, self._center_z,
        rt.settings.overworld.npc.eye_mesh_width,
        rt.settings.overworld.npc.eye_mesh_height,
        rt.settings.overworld.npc.eye_mesh_curvature
    )
    self._eye_mesh:set_texture(self._eyes_texture)
end

--- @brief
function ow.NPC:update(delta)
    -- update eye texture
    love.graphics.push("all")
    self._eyes_texture:bind()
    love.graphics.clear(1, 0, 1, 1)
    love.graphics.translate(
        0.5 * self._eyes_texture:get_width(),
        0.5 * self._eyes_texture:get_height()
    )
    self._eyes:draw()
    self._eyes_texture:unbind()
    love.graphics.pop()

    -- orient eye mesh
    local target_x, target_y = self._scene:get_player():get_position()
    target_x = target_x - self._position_x - 0.5 * self._3d_texture:get_width()
    target_y = target_y - self._position_y - 0.5 * self._3d_texture:get_height()

    self._dbg = {target_x, target_y}
    target_x, target_y = 0, 0
    local target_z = -1
    local turn_magnitude = 1

    self._model_transform = rt.Transform()
    self._model_transform:set_target_to(
        self._center_x, self._center_y, self._center_z, -- object position
        target_x * turn_magnitude, target_y * turn_magnitude, target_z, -- target position
        0, 1, 0 -- up
    )

    -- update 3d texture
    love.graphics.push("all")
    local canvas = self._3d_texture
    canvas:set_fov(0.2)
    canvas:set_model_transform(self._model_transform)
    canvas:set_view_transform(self._view_transform)
    canvas:bind()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setMeshCullMode("back")

    self._eye_mesh:draw()
    canvas:unbind()
    love.graphics.pop()
end

--- @brief
function ow.NPC:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._position_x, self._position_y, 30)
    love.graphics.line(self._position_x, self._position_y, table.unpack(self._dbg))

    love.graphics.push()
    love.graphics.translate(
        self._position_x - 0.5 * self._3d_texture:get_width(),
        self._position_y - 0.5 * self._3d_texture:get_height()
    )
    self._3d_texture:draw()
    love.graphics.pop()
end

--- @brief
function ow.NPC:get_render_priority()
    return math.huge
end
