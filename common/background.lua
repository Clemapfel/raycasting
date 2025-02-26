require "common.shader"
require "common.widget"
require "common.mesh"

local _elapsed_name = "elapsed"

--- @class rt.Background
rt.Background = meta.class("Background", rt.Widget)

--- @brief
function rt.Background:instantiate(shader_path)
    meta.install(self, {
        _path = shader_path,
        _shape = nil,
        _shader = nil,
        _elapsed = 0
    })
end

--- @brief
function rt.Background:realize()
    self._shape = rt.MeshRectangle(0, 0, 1, 1)
    self._shader = rt.Shader(self._shader_path)

    if self._shader:has_uniform(_elapsed_name) then
        self._shader:send(_elapsed_name, 0)
    end
end

--- @brief
function rt.Background:size_allocate(x, y, width, height)
    self._shape = rt.MeshRectangle(x, y, width, height)
end

--- @brief
function rt.Background:draw()
    self._shader:bind()
    if self._shader:has_uniform("elapsed") then
        self._shader:send("elased", self._elapsed)
    end
    self._shape:draw()
    self._shader:unbind()
end

--- @brief
function rt.Background:update(delta)
    self._elapsed = self._elapsed + delta
end
