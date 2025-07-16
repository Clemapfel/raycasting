
--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _shader

local _first = true -- TODO

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)

    if _first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "c" then
                _shader:recompile()
            end
        end)
        _first = false
    end

    if _shader == nil then _shader = rt.Shader("overworld/objects/accelerator_surface.glsl") end
    self._scene = scene

    -- mesh
    self._contour = rt.round_contour(object:create_contour(), 10)
    self._mesh = object:create_mesh()

    -- collision
    do
        local shapes = {}
        local slick = require "dependencies.slick.slick"
        for shape in values(slick.polygonize(6, { self._contour })) do
            table.insert(shapes, b2.Polygon(shape))
        end

        self._body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, 0, 0, shapes)
    end

    self._body:add_tag(
        "use_friction",
        "stencil",
        "slippery"
    )

    self._body:set_friction(object:get_number("friction") or -1)
    self._body:set_user_data(self)
    self._body:set_collides_with(bit.bor(
        rt.settings.player.player_collision_group,
        rt.settings.player.player_outer_body_collision_group
    ))

    self._mesh = object:create_mesh()
end

--- @brief
function ow.AcceleratorSurface:draw()
    _shader:bind()
    _shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _shader:send("camera_scale", self._scene:get_camera():get_scale())
    _shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    love.graphics.pop("all")
    _shader:unbind()
end
