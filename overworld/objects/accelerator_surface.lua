--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _shader

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("use_friction", "hitbox")
    self._body:set_friction(-1)
    self._body:set_user_data(self)

    self._mesh, self._tris = object:create_mesh()
    if _shader == nil then _shader = rt.Shader("overworld/objects/accelerator_surface.glsl") end

    self._camera_scale = 1
    self._camera_offset = { 0, 0 }
    self._elapsed = 0

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == "z" then _shader:recompile(); self._elapsed = 0 end
    end)
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end
    _shader:bind()
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("elapsed", self._elapsed)
    self._mesh:draw()
    _shader:unbind()
end

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    self._elapsed = self._elapsed + delta
    local camera = self._scene:get_camera()
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()
end