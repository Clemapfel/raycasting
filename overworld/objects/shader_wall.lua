require "common.shader"
require "common.widget"
require "common.mesh"

--- @class ow.Hitbox
ow.Hitbox = meta.class("Hitbox", rt.Drawable)

-- statics
local _offset_x = 0
local _offset_y = 0
local _scale = 1
local _elapsed = 0
local _scene_connected = false

local _id_to_shader = {}

--- @brief
function ow.Hitbox:instantiate(object, stage, scene)
    local id = object:get_string("shader", false)

    TODO: choose shader base on properties

    local shader = nil
    if id ~= nil then
        shader = _id_to_shader[id]
        if shader == nil then
            shader = rt.Shader("overworld/objects/shader_wall/" .. id .. ".glsl")
            _id_to_shader[id] = shader
        end
    end

    local mesh, tris = nil, nil
    if shader ~= nil then
        mesh, tris = object:create_mesh()
        for tri in values(tris) do -- close for line loop
            table.insert(tri, tri[1])
            table.insert(tri, tri[2])
        end
    end

    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world()),

        -- drawables, optional
        _mesh = mesh,
        _mesh_triangles = tris,
        _shader = shader,
    })


    if _scene_connected ~= true then
        scene:signal_connect("update", function(scene, delta)
            ow.Hitbox.notify_frame_advance(delta)
            ow.Hitbox.notify_camera_changed(scene:get_camera())
        end)
        _scene_connected = true
    end

    if object:get_string("type") == b2.BodyType.DYNAMIC then
        self._body._native:setLinearDamping(30)
        self._body._native:setAngularDamping(30)
    end

    local group = 0x0
    local once = false
    if object:get_boolean("is_reflective") then
        group = bit.bor(group, ow.RayMaterial.REFLECTIVE)
        self._body:add_tag("draw")
        self._color = rt.Palette.WHITE
        once = true
    end

    if object:get_boolean("is_transmissive") then
        group = bit.bor(group, ow.RayMaterial.TRANSMISSIVE)
        self._body:add_tag("draw")
        self._color = rt.Palette.BLUE_2
        once = true
    end

    if object:get_boolean("is_filtrative") then
        group = bit.bor(group, ow.RayMaterial.FILTRATIVE)
        self._body:add_tag("draw")
        self._color = rt.Palette.BLACK
        once = true
    end

    if object:get_boolean("is_absorptive") or once == false then
        group = bit.bor(group, ow.RayMaterial.ABSORPTIVE)
        once = true
    end
end

--- @brief
function ow.Hitbox:draw()
    if self._shader ~= nil then
        self._shader:bind()
        self._shader:send("color_a", { rt.Palette.COLOR_A:unpack() })
        self._shader:send("color_b", { rt.Palette.COLOR_B:unpack() })
        self._shader:send("elapsed", _elapsed)
        self._shader:send("camera_offset", { _offset_x, _offset_y})
        self._shader:send("camera_scale", _scale)

        love.graphics.push()
        love.graphics.translate(self._body:get_position())
        love.graphics.rotate(self._body:get_rotation())

        self._mesh:draw()
        self._shader:unbind()

        local stencil_value = rt.graphics.get_stencil_value()
        love.graphics.setColor(1, 1, 1, 1)
        rt.graphics.stencil(stencil_value, function()
            for tri in values(self._mesh_triangles) do
                love.graphics.polygon("fill", tri)
            end
        end)
        rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

        local line_width = 2

        -- multiple for loops for batching
        love.graphics.setLineJoin("none")

        rt.Palette.BASE_OUTLINE:bind()
        love.graphics.setLineWidth(2 * (line_width + 1))
        for tri in values(self._mesh_triangles) do
            love.graphics.line(tri)
        end

        for tri in values(self._mesh_triangles) do
            for i = 1, #tri, 2 do
                love.graphics.circle("fill", tri[i], tri[i+1], line_width + 1)
            end
        end

        rt.Palette.FOREGROUND:bind()
        love.graphics.setLineWidth(2 * line_width)
        for tri in values(self._mesh_triangles) do
            love.graphics.line(tri)
        end

        for tri in values(self._mesh_triangles) do
            for i = 1, #tri, 2 do
                love.graphics.circle("fill", tri[i], tri[i+1], line_width)
            end
        end

        rt.graphics.set_stencil_test()
        love.graphics.pop()
    end
end

--- @brief
function ow.Hitbox.notify_frame_advance(delta)
    _elapsed = _elapsed + delta
end

--- @brief
function ow.Hitbox.notify_camera_changed(camera)
    _offset_x, _offset_y = camera:get_offset()
    _scale = camera:get_scale()
end
