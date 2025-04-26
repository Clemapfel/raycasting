rt.settings.overworld.hook = {
    cooldown = 0.4,
    radius_factor = 1.5
}

--- @class ow.Hook
ow.Hook = meta.class("OverworldHook", rt.Drawable)

--- @brief
function ow.Hook:instantiate(object, stage, scene)
    local radius = rt.settings.overworld.player.radius * rt.settings.overworld.hook.radius_factor

    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Hook: object is not a point")
    self._scene = scene
    self._radius = radius
    meta.install(self, {
        _body = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            object.x, object.y,
            b2.Circle(0, 0, radius)
        ),

        _joint = nil,
        _deactivated = false,
        _elapsed = 0,
        _input = rt.InputSubscriber()
    })

    local hook = self
    self._body:set_is_sensor(true)
    self._body:add_tag("slippery")
    self._body:set_collides_with(bit.bor(
        rt.settings.overworld.player.player_collision_group,
        rt.settings.overworld.player.player_outer_body_collision_group
    ))

    self._body:signal_connect("collision_start", function(self, player_body)
        local player = player_body:get_user_data()

        if hook._joint == nil and not hook._deactivated then

            player:set_jump_allowed(true) -- mid-air jumpt to escape

            local vx, vy = player:get_velocity() -- maintain upwards momentum
            if vy > 0 then vy = 0 end
            player:set_velocity(0, 0)

            player:teleport_to(self:get_center_of_mass())
            scene:get_camera():move_to(self:get_center_of_mass())

            if player._jump_button_is_down ~= true then -- buffered jump: instantly jump again
                stage:get_physics_world():signal_connect("step", function()
                    if not self._deactivated then
                        local self_x, self_y = self:get_center_of_mass()
                        hook._joint = love.physics.newDistanceJoint(
                            self:get_native(),
                            player:get_physics_body():get_native(),
                            self_x, self_y,
                            self_x, self_y
                        )
                        return meta.DISCONNECT_SIGNAL
                    end
                end)

                local player_signal_id
                player_signal_id = player:signal_connect("jump", function()
                    hook:_unhook()
                    player:signal_disconnect("jump", player_signal_id)
                end)
            else
                player:bounce(0, -1)
            end

            hook._deactivated = true
        end
    end)

    self._body:signal_connect("collision_end", function(self, player_body)
        local player = player_body:get_user_data()
        hook._deactivated = false
        player:set_jump_allowed(nil)
    end)

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.DOWN then
            self:_unhook()
        end
    end)
end

--- @brief
function ow.Hook:_unhook()
    if self._joint ~= nil then
        self._joint:destroy()
        self._joint = nil
    end
end

local _inner_vertices = nil
local _inner_mesh_origin_x, _inner_mesh_origin_y = 0, 0

local _outer_vertices = nil
local _outer_mesh_origin_x, _outer_mesh_origin_y = 0, 0

local _center_vertices = nil


local _n_parts = 7
local _colors = 0

function ow.Hook:update(delta)
    self._elapsed = self._elapsed + delta
end

--- @brief
function ow.Hook:draw()
    if _outer_vertices == nil then
        local x_radius = self._radius / 2
        local y_radius = self._radius / 2 / 2

        local cx, cy = 0, 0
        _outer_vertices = {}
        _colors = {}

        local m = 2
        local n = 0
        local step = 2 * math.pi / 32
        for angle = 0, 2 * math.pi + step, step do
            local x = cx + math.cos(angle) * x_radius
            local y = cy + (math.sin(angle) * math.sin(0.5 * angle)^m) * y_radius
            local r, g, b, a = rt.lcha_to_rgba(rt.LCHA(0.8, 1, angle / (2 * math.pi), 1, 1):unpack())
            table.insert(_outer_vertices, x)
            table.insert(_outer_vertices, y)
            table.insert(_colors, { r, g, b, a })

            n = n + 1
        end

        _outer_mesh_origin_x, _outer_mesh_origin_y = -x_radius, 0
        _colors = {}

        local hue = 0
        for i = 1, _n_parts do
            table.insert(_colors, { rt.lcha_to_rgba(rt.LCHA(0.8, 1, hue, 1, 1):unpack()) })
            hue = hue + 1 / _n_parts
        end
    end

    if _inner_vertices == nil then
        _inner_vertices = { }

        local x_radius, y_radius = self._radius / 8 * 2, self._radius / 4
        local cx, cy = self._radius / 2 - x_radius, 0
        for angle = 0, (2 * math.pi), (2 * math.pi) / 16 do
            table.insert(_inner_vertices, cx + math.cos(angle) * x_radius)
            table.insert(_inner_vertices, cy + math.sin(angle) * y_radius)
        end
        _inner_mesh_origin_x, _inner_mesh_origin_y = _outer_mesh_origin_x, 0
    end

    if _center_vertices == nil then
        _center_vertices = {}
        local cx, cy = 0, 0
        local radius = self._radius - self._radius / 4
        for angle = 0, (2 * math.pi), (2 * math.pi) / 16 do
            table.insert(_center_vertices, cx + math.cos(angle) * radius)
            table.insert(_center_vertices, cy + math.sin(angle) * radius)
        end
    end

    if not self._scene:get_is_body_visible(self._body) then return end

    rt.Palette.PURPLE:bind()

    love.graphics.setLineWidth(1)
    local x, y = self._body:get_position()
    local angle = 0
    for i = 1, _n_parts do
        love.graphics.push()
        love.graphics.translate(x + self._radius / 2, y)

        love.graphics.push()
        love.graphics.translate(_outer_mesh_origin_x, _outer_mesh_origin_y)
        love.graphics.rotate(self._elapsed + angle)
        love.graphics.translate(-_outer_mesh_origin_x, -_outer_mesh_origin_y)

        love.graphics.setColor(table.unpack(_colors[i]))
        love.graphics.polygon("line", _outer_vertices)
        love.graphics.pop()

        love.graphics.push()
        love.graphics.translate(_inner_mesh_origin_x, _inner_mesh_origin_y)
        love.graphics.rotate(1 * self._elapsed + angle + (2 * math.pi) / _n_parts / 2)
        love.graphics.translate(-_inner_mesh_origin_x, -_inner_mesh_origin_y)
        love.graphics.polygon("line", _inner_vertices)
        love.graphics.pop()

        love.graphics.pop()

        angle = angle + (2 * math.pi) / _n_parts
    end

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.setLineWidth(2)
    rt.Palette.GRAY_8:bind()
    love.graphics.polygon("line", _center_vertices)
    love.graphics.pop()

    --self._body:draw()
end
