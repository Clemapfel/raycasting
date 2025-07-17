
--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _body_shader, _outline_shader

local _first = true -- TODO

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)

    if _first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "c" then
                _body_shader:recompile()
                _outline_shader:recompile()
            end
        end)
        _first = false
    end

    if _body_shader == nil then _body_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 0 }) end
    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 1 }) end

    self._scene = scene
    self._elapsed = 0

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
    self._outline = object:create_contour()

    table.insert(self._outline, self._outline[1])
    table.insert(self._outline, self._outline[2])
end

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()
    if player:get_collision_normal(self._body) ~= nil then
        local factor = 1 / 1000
        self._elapsed = self._elapsed + delta * math.magnitude(player:get_velocity()) * factor
    end
end

--- @brief
function ow.AcceleratorSurface:draw()
    local outline_width = 2
    local outline_color = rt.Palette.GRAY_3;
    love.graphics.setColor(1, 1, 1, 1)


    local offset_x, offset_y = self._scene:get_camera():get_offset()

    _body_shader:bind()
    _body_shader:send("camera_offset", { offset_x, offset_y })
    _body_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _body_shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    _body_shader:send("elapsed", self._elapsed + meta.hash(self) * 100)
    _body_shader:send("outline_width", outline_width)
    _body_shader:send("outline_color", { outline_color:unpack() })
    _body_shader:send("player_hue", self._scene:get_player():get_hue())
    _body_shader:send("shape_centroid", { self._scene:get_camera():world_xy_to_screen_xy(self._body:get_center_of_mass())})
    love.graphics.push("all")
    self._mesh:draw()
    love.graphics.pop("all")
    _body_shader:unbind()

    outline_color:bind()
    _outline_shader:bind()
    _outline_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outline_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _outline_shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    _outline_shader:send("elapsed", self._elapsed + meta.hash(self) * 100)
    love.graphics.setLineWidth(outline_width)
    love.graphics.line(self._outline)
    _outline_shader:unbind()
end
