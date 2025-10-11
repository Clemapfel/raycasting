require "common.delaunay_triangulation"
require "overworld.player_recorder_body"
require "overworld.player_recorder_eyes"
require "common.render_texture_3d"
require "common.blur"

rt.settings.overworld.npc = {
    -- model
    canvas_radius = 150,
    canvas_padding = 20,
    face_backing_factor = 1.2, -- times eye radius
    radius_factor = 1.5, -- times player radius
    blur_strength = 4,
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    assert(object:get_type() == ow.ObjectType.POINT, "NPC should be Point")
    self._x = object.x
    self._y = object.y

    -- graphics
    do
        local radius = rt.settings.overworld.npc.canvas_radius
        local padding = rt.settings.overworld.npc.canvas_padding
        local factor = rt.settings.overworld.npc.face_backing_factor

        radius, padding = math.multiply(radius, padding, factor)

        -- construct eyes at higher resolution, then downscale to correct radius in draw
        self._eyes = ow.PlayerRecorderEyes(radius, 0, 0)
        self._eyes_texture = rt.RenderTexture(
            2 * (radius + padding),
            2 * (radius + padding),
            4 -- msaa
        )
        self._eyes_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

        self._3d_texture = rt.RenderTexture3D(
            2 * (radius + 2 * padding),
            2 * (radius + 2 * padding),
            4
        )
        self._3d_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

        self._model_transform = rt.Transform()
        self._view_transform = rt.Transform()
        self._view_transform:translate(0, 0, -1 * (radius + padding))

        self._center_x, self._center_y, self._center_z = 0, 0, 0
        self._eye_mesh = rt.MeshPlane(
            self._center_x, self._center_y, self._center_z,
            self._eyes_texture:get_width() / 4,
            self._eyes_texture:get_height() / 4,
            radius / 7 -- curvature
        )
        self._eye_mesh:set_texture(self._eyes_texture)

        local sphere_r = radius / 2.5
        self._sphere_mesh = rt.MeshSphere(
            self._center_x, self._center_y, self._center_z - sphere_r,
            sphere_r,
            8, 8
        )

        -- blur for manual anti aliasing
        self._blur = rt.Blur(self._3d_texture:get_width(), self._3d_texture:get_height())
        self._blur:set_blur_strength(rt.settings.overworld.npc.blur_strength)

        self._graphics_body = ow.PlayerRecorderBody(self._stage, self._scene)
        self._graphics_body:initialize(self._x, self._y)
    end
end

--- @brief
function ow.NPC:update(delta)
    do -- graphics
        self._eyes:update(delta)
        self._graphics_body:update(delta)

        -- update eye texture
        love.graphics.push("all")
        self._eyes_texture:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(
            0.5 * self._eyes_texture:get_width(),
            0.5 * self._eyes_texture:get_height()
        )

        local r = 0.5 * self._eyes_texture:get_width()
        local line_width = 7

        rt.Palette.BLACK:bind()
        love.graphics.circle("fill", 0, 0, r - line_width)

        love.graphics.setColor(self._eyes:get_color())
        love.graphics.setLineWidth(line_width)
        love.graphics.circle("line", 0, 0, r - line_width)

        rt.Palette.TRUE_WHITE:bind()
        self._eyes:draw()
        self._eyes_texture:unbind()
        love.graphics.pop()

        -- orient eye mesh
        local target_x, target_y = self._scene:get_player():get_position()
        target_x = target_x - self._x
        target_y = target_y - self._y

        local target_z = -10
        local turn_magnitude_x = 20 -- the higher, the less it will react along that axis
        local turn_magnitude_y = 30

        self._model_transform = rt.Transform()
        self._model_transform:set_target_to(
            self._center_x, self._center_y, self._center_z,
            target_x / turn_magnitude_x,
            target_y / turn_magnitude_y, -- separate value for y to prevent roll
            target_z,
            0, 1, 0 -- up
        )

        self._model_transform:as_inverse()

        -- update 3d texture
        love.graphics.push("all")
        local canvas = self._3d_texture
        canvas:set_fov(0.2)
        canvas:set_view_transform(self._view_transform)
        canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setMeshCullMode("back")

        rt.Palette.TRUE_WHITE:bind()
        canvas:set_model_transform(self._model_transform)
        self._eye_mesh:draw()

        canvas:unbind()
        love.graphics.pop()

        love.graphics.push("all")
        love.graphics.origin()
        self._blur:bind()
        love.graphics.clear(0, 0, 0, 0)
        canvas:draw(0, 0)
        self._blur:unbind()
        love.graphics.pop()
    end
end

--- @brief
function ow.NPC:draw()
    local scale = rt.settings.overworld.npc.radius_factor * rt.settings.player.radius / self._eyes:get_radius()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self._blur:get_texture(),
        self._x,
        self._y,
        0,
        scale, scale,
        0.5 * self._3d_texture:get_width(),
        0.5 * self._3d_texture:get_height()
    )

    self._graphics_body:draw()
end

function ow.NPC:draw_bloom()
    love.graphics.push("all")
    love.graphics.reset()
    self._eyes_texture:bind()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(
        0.5 * self._eyes_texture:get_width(),
        0.5 * self._eyes_texture:get_height()
    )
    self._eyes:draw_bloom()
    self._eyes_texture:unbind()
    love.graphics.pop()

    love.graphics.push("all")
    love.graphics.reset()
    self._3d_texture:bind()
    love.graphics.clear(0, 0, 0, 0)
    self._eye_mesh:draw()
    self._3d_texture:unbind()
    love.graphics.pop()

    local scale = rt.settings.overworld.npc.radius_factor * rt.settings.player.radius / self._eyes:get_radius()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self._3d_texture:get_native(),
        self._x,
        self._y,
        0,
        scale, scale,
        0.5 * self._3d_texture:get_width(),
        0.5 * self._3d_texture:get_height()
    )
end

--- @brief
function ow.NPC:get_render_priority()
    return -1 -- below player
end
