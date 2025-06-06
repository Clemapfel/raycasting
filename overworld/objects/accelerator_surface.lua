rt.settings.overworld.accelerator_surface = {

}

--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _shader

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("use_friction", "hitbox")
    self._body:set_friction(object:get_number("friction") or -1)
    self._body:set_user_data(self)

    self._mesh, self._tris = object:create_mesh()
    if _shader == nil then _shader = rt.Shader("overworld/objects/accelerator_surface.glsl") end

    self._camera_scale = 1
    self._camera_offset = { 0, 0 }
    self._elapsed = 0

    self._is_emitting = false
    self._emission_origin_x, self._emission_origin_y = 0, 0
    self._particles = {}

    self._body:set_collides_with(bit.bor(rt.settings.player.player_collision_group, rt.settings.player.player_outer_body_collision_group))
    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, x1, y1, x2, y2)
        self._is_emitting = true
        self._emission_origin_x, self._emission_origin_y = x1, y1
        self._emissing_direction_x, self._emissing_direction_x = math.flip(self._scene:get_player():get_velocity())
    end)

    self._body:signal_connect("collision_end", function()
        self._is_emitting = false
    end)
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end
    --_shader:bind()
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("elapsed", self._elapsed)
    _shader:send("player_direction", { math.normalize(self._scene:get_player():get_velocity()) })
    self._mesh:draw()
    _shader:unbind()


    if self._is_emitting then
        love.graphics.setColor(1, 0, 1, 1)
        love.graphics.circle("fill", self._emission_origin_x, self._emission_origin_y, 10)
    end
end

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    self._elapsed = self._elapsed + delta
    local camera = self._scene:get_camera()
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    -- particle sim
end