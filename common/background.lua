require "common.shader"
require "common.widget"
require "common.mesh"

local _elapsed_name = "elapsed"

rt.settings.background = {
    config_path = "common/backgrounds/"
}

--- @class rt.Background
rt.Background = meta.class("Background", rt.Widget)

--- @brief
function rt.Background:instantiate(id, override_path)
    local path
    if override_path == true then
        path = id
    else
        path = rt.settings.background.config_path .. id .. ".glsl"
    end

    meta.install(self, {
        _path = path,
        _shape = nil,
        _shader = nil,
        _elapsed = 0
    })
end

--- @brief
function rt.Background:realize()
    if self:already_realized() then return end

    self._shape = rt.MeshRectangle(0, 0, 1, 1)
    self._shader = rt.Shader(self._path)

    if self._shader:has_uniform(_elapsed_name) then
        self._shader:send(_elapsed_name, 0)
    end
end

--- @brief
function rt.Background:size_allocate(x, y, width, height)
    self._shape = rt.MeshRectangle(x, y, width, height)
end

local _offset_x, _offset_y = 0, 0
local _scale = 1

--- @brief
function rt.Background:draw()
    if not self:get_is_realized() then
        rt.error("In rt.Background.draw: trying to draw background, but it is not yet realized")
        return
    end

    self._shader:bind()

    if self._shader:has_uniform("camera_offset") then
        self._shader:send("camera_offset", { _offset_x, _offset_y})
    end

    if self._shader:has_uniform("camera_scale") then
        self._shader:send("camera_scale", _scale)
    end

    if self._shader:has_uniform(_elapsed_name) then
        self._shader:send(_elapsed_name, self._elapsed)
    end
    self._shape:draw()
    self._shader:unbind()
end

--- @brief
function rt.Background:update(delta)
    self._elapsed = self._elapsed + delta
end

--- @brief
function rt.Background:recompile(reset_time)
    self._shader:recompile()
    if reset_time == true then
        self._elapsed = 0
    end
end

--- @brief
function rt.Background:send(uniform_name, value)
    self._shader:send(uniform_name, value)
end

--- @brief
function rt.Background:_notify_camera_changed(camera)
    _offset_x, _offset_y = camera:get_offset()
    _scale = camera:get_scale()
end
