require "common.sound_manager"

rt.settings.overworld.hook = {
    radius_factor = 1.1,
    color_rotation_speed = 0.8, -- n revolutions per second
    color_cooldown_duration = 2,
    hook_animation_duration = 1,
    hook_sound_id = "hook"
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
        _world = stage:get_physics_world(),

        _x = object.x,
        _y = object.y,
        _radius = radius,

        _hook = nil,
        _deactivated = false,
        _color_elapsed = math.huge,
        _hook_animation_elapsed = math.huge,
        _hook_animation_blocked = false,

        _elapsed = 0,

        _input = rt.InputSubscriber()
    })

    local hook = self
    self._body:set_is_sensor(true)
    self._body:add_tag("slippery")
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    local player_signal_id = nil

    self._body:signal_connect("collision_start", function(_)
        local player = self._scene:get_player()

        player:teleport_to(self._x, self._y)
        player:set_jump_allowed(true)
        if self._hook == nil and not self._deactivated then
            self._color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }
            self._color_elapsed = 0

            if not player._jump_button_is_down then -- buffered jump: jump instantly
                self._world:signal_connect("step", function()
                    -- delay hook to after world step
                    self._hook = love.physics.newDistanceJoint(
                        self._body:get_native(),
                        player:get_physics_body():get_native(),
                        self._x, self._y,
                        self._x, self._y
                    )

                    player_signal_id = player:signal_connect("jump", function()
                        if self._hook ~= nil then
                            self._hook:destroy()
                            self._hook = nil
                        end
                        player_signal_id = nil
                        self._hook_animation_blocked = true
                        return meta.DISCONNECT_SIGNAL
                    end)

                    return meta.DISCONNECT_SIGNAL
                end)
            end

            if not self._hook_animation_blocked then
                self._hook_animation_elapsed = 0
                rt.SoundManager:play(rt.settings.overworld.hook.hook_sound_id)
            end
        end
    end)

    self._body:signal_connect("collision_end", function(_)
        self._color_elapsed = 0
        self._deactivated = false
        self._hook_animation_blocked = false
    end)

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.DOWN and self._hook ~= nil then
            self._hook:destroy()
            self._hook = nil
            self._scene:get_player():signal_disconnect("jump", player_signal_id)
            self._deactivated = true
        end
    end)
end

function ow.Hook:update(delta)
    self._elapsed = self._elapsed + delta
    self._color_elapsed = self._color_elapsed + delta
    self._hook_animation_elapsed = self._hook_animation_elapsed + delta

    if self._hooked == true then
        self._scene:get_player():teleport_to(self._x, self._y)
    end
end

local _segments = nil
local _colors = nil
local _lock_mesh = nil

--- @brief
function ow.Hook:draw()
    local n_segments = 48
    if _segments == nil then
        _segments = {}
        _colors = {}

        local x_radius = self._radius
        local y_radius = self._radius

        local cx, cy = 0, 0
        local step = 2 * math.pi / n_segments
        for angle = 0, 2 * math.pi, step  do
            local hue = angle / (2 * math.pi)
            table.insert(_segments, {
                cx + math.cos(angle) * x_radius,
                cy + math.sin(angle) * y_radius,
                cx + math.cos(angle + step) * x_radius,
                cy + math.sin(angle + step) * y_radius
            })

            table.insert(_colors, { rt.lcha_to_rgba(0.8, 1, hue, 1) })
        end
    end

    if _lock_mesh == nil then
        _lock_mesh = rt.MeshCircle(0, 0, 0, 0, n_segments):get_native()
    end

    if not self._scene:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._body:get_position())
    rt.Palette.HOOK_BASE:bind()
    love.graphics.circle("fill", 0, 0, self._radius)
    love.graphics.setLineWidth(2)

    local speed = rt.settings.overworld.hook.color_rotation_speed

    local fraction = math.min(self._color_elapsed / rt.settings.overworld.hook.color_cooldown_duration, 1)
    if self._hook ~= nil then fraction = 0 end

    for i, color in ipairs(_segments) do
        local segment_color = _colors[math.floor(i - speed * self._elapsed * n_segments) % n_segments + 1]
        if fraction < 1 then
            local r, g, b = math.mix3(
                self._color[1], self._color[2], self._color[3],
                segment_color[1], segment_color[2], segment_color[3],
                fraction
            )
            love.graphics.setColor(r, g, b, 1)
        else
            love.graphics.setColor(table.unpack(segment_color))
        end

        love.graphics.line(table.unpack(_segments[i]))
    end

    love.graphics.pop()

    local lock_fraction = self._hook_animation_elapsed / rt.settings.overworld.hook.hook_animation_duration
    if lock_fraction <= 1 then
        local radius = (self._radius + 20) * lock_fraction

        local data = {
            { 0, 0, 0, 0, 1, 1, 1, 0 }
        }
        for angle = 0, 2 * math.pi, 2 * math.pi / n_segments do
            table.insert(data, {
                math.cos(angle) * radius,
                math.sin(angle) * radius,
                0, 0,
                1, 1, 1, rt.InterpolationFunctions.SQUARE_ROOT_INFLECTION(1 - lock_fraction)
            })
        end
        _lock_mesh:setVertices(data)

        love.graphics.setColor(table.unpack(self._color))
        love.graphics.draw(_lock_mesh, self._body:get_position())
    end
end
