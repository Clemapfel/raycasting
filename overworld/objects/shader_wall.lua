require "common.shader"
require "common.widget"
require "common.mesh"

--- @class ow.ShaderWall
ow.ShaderWall = meta.class("ShaderWall", rt.Drawable)

-- statics
local _offset_x = 0
local _offset_y = 0
local _scale = 1
local _elapsed = 0
local _scene_connected = false

local _id_to_shader = {}

--- @brief
function ow.ShaderWall:instantiate(object, stage, scene)
    local id = object:get_string("shader", true)

    local shader = _id_to_shader[id]
    if shader == nil then
        shader = rt.Shader("overworld/objects/shader_wall/" .. id .. ".glsl")
        _id_to_shader[id] = shader
    end

    local mesh, outline = object:create_mesh()
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world()),
        _mesh = mesh,
        _outline = outline,
        _shader = shader,
    })

    if _scene_connected ~= true then
        scene:signal_connect("update", function(scene, delta)
            ow.ShaderWall.notify_frame_advance(delta)
            ow.ShaderWall.notify_camera_changed(scene:get_camera())
        end)
        _scene_connected = true
    end
end

--- @brief
function ow.ShaderWall:draw()
    self._shader:bind()
    self._shader:send("color_a", { rt.Palette.COLOR_A:unpack() })
    self._shader:send("color_b", { rt.Palette.COLOR_B:unpack() })
    self._shader:send("elapsed", _elapsed)
    self._shader:send("camera_offset", { _offset_x, _offset_y})
    self._shader:send("camera_scale", _scale)
    love.graphics.push()
    love.graphics.translate(self._body:get_position())
    self._mesh:draw()
    self._shader:unbind()
    rt.Palette.FOREGROUND:bind()
    love.graphics.line(self._outline)
    love.graphics.setLineWidth(3)
    love.graphics.pop()
end

--- @brief
function ow.ShaderWall.notify_frame_advance(delta)
    _elapsed = _elapsed + delta
end

--- @brief
function ow.ShaderWall.notify_camera_changed(camera)
    _offset_x, _offset_y = camera:get_offset()
    _scale = camera:get_scale()
end
