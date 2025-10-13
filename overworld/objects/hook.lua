require "common.smoothed_motion_1d"

rt.settings.overworld.hook = {
    radius_factor = 1.8,
    hook_animation_duration = 3,
    hook_sound_id = "hook",
    outline_width = 2
}

--- @class ow.Hook
--- @types Point
ow.Hook = meta.class("OverworldHook", rt.Drawable)

local _shader = rt.Shader("overworld/objects/hook.glsl")

-- global hue queue such that two elements don't have the same hue
local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

--- @brief
function ow.Hook:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Hook: object `" .. object:get_id() .. "` is not a point")
    self._radius = rt.settings.player.radius * rt.settings.overworld.hook.radius_factor

    self._scene = scene
    self._stage = stage
    self._radius = rt.settings.player.radius * rt.settings.overworld.hook.radius_factor
    self._motion = rt.SmoothedMotion1D(1, 1 / rt.settings.overworld.hook.hook_animation_duration)

    self._world = stage:get_physics_world()
    self._body = b2.Body(
        self._world,
        b2.BodyType.STATIC,
        object.x, object.y,
        b2.Circle(0, 0, self._radius)
    )

    self._x, self._y = object.x, object.y

    self._hue = _current_hue_step
    self._original_hue = self._hue
    _current_hue_step = (_current_hue_step % _n_hue_steps) + 1
    self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }

    self._stage:signal_connect("respawn", function(_)
        -- revert hue changes from hooking player
        self._hue = self._original_hue
        self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }
    end)

    -- collision
    self._is_hooked = false
    self._is_blocked = false -- prevent rehook until player left sensor
    self._jump_callback_id = nil

    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._body:signal_connect("collision_start", function(_)
        self:_hook()
    end)

    self._body:signal_connect("collision_end", function(_)
        if self._is_blocked == true then
            self._motion:set_target_value(1)
        end
        self._is_blocked = false
    end)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if self._is_hooked == false then return end

        local player = self._scene:get_player()
        if player:get_is_bubble() == true then
            -- when bubble, any direction unhooks
            if which == rt.InputAction.UP or which == rt.InputAction.RIGHT or which == rt.InputAction.DOWN or which == rt.InputAction.LEFT then
                self:_unhook()
            end
        elseif player:get_is_bubble() == false then
            -- when not bubble, down unhooks, or jump unhooks (connect in _hook)
            if which == rt.InputAction.DOWN then
                self:_unhook()
            end
        end
    end)

    local r = self._radius
    self._outline = {}
    for angle = 0, 2 * math.pi, (2 + math.pi) / 32 do
        table.insert(self._outline, math.cos(angle) * r * 0.95)
        table.insert(self._outline, math.sin(angle) * r * 0.95)
    end

    table.insert(self._outline, self._outline[1])
    table.insert(self._outline, self._outline[2])
end

--- @brief
function ow.Hook:update(delta)
    if not self._is_hooked and not self._stage:get_is_body_visible(self._body) then return end
    self._motion:update(delta)
end

--- @brief
function ow.Hook:_hook()
    if self._is_hooked == true or self._is_blocked then return end
    local player = self._scene:get_player()
    self._hue = player:get_hue()
    self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }

    if player:get_is_bubble() and (
        self._input:get_is_down(rt.InputAction.UP) or
        self._input:get_is_down(rt.InputAction.RIGHT) or
        self._input:get_is_down(rt.InputAction.DOWN) or
        self._input:get_is_down(rt.InputAction.LEFT)
    ) then
        -- if bubble and direction is held, only teleport
        local bubble, non_bubble = player:get_physics_body(true), player:get_physics_body(false)
        bubble:set_position(self._x, self._y)
        non_bubble:set_position(self._x, self._y)
        self._is_blocked = true
    elseif player:get_is_bubble() == false and self._input:get_is_down(rt.InputAction.DOWN) then
        -- if holding down, teleport but keep momentum
        local vx, vy = player:get_velocity()
        local bubble, non_bubble = player:get_physics_body(true), player:get_physics_body(false)
        bubble:set_position(self._x, self._y)
        non_bubble:set_position(self._x, self._y)
        player:set_velocity(vx, vy)
        self._is_blocked = true
    elseif player:get_is_bubble() == false and self._input:get_is_down(rt.InputAction.JUMP) then
        -- if holding jump, jump again
        local bubble, non_bubble = player:get_physics_body(true), player:get_physics_body(false)
        bubble:set_position(self._x, self._y)
        non_bubble:set_position(self._x, self._y)
        player:set_velocity(0, 0)
        player:set_jump_allowed(true)
        player:jump()
        self._is_blocked = true
    else
        -- hook properly
        self._world:signal_connect("step", function(_) -- delay to after box2d update because world is locked
            local bubble, non_bubble = player:get_physics_body(true), player:get_physics_body(false)
            bubble:set_position(self._x, self._y)
            non_bubble:set_position(self._x, self._y)

            self._bubble_hook = love.physics.newDistanceJoint(
                self._body:get_native(),
                bubble:get_native(),
                self._x, self._y,
                self._x, self._y
            )

            self._non_bubble_hook = love.physics.newDistanceJoint(
                self._body:get_native(),
                non_bubble:get_native(),
                self._x, self._y,
                self._x, self._y
            )

            if player:get_is_bubble() == false then
                player:set_jump_allowed(true)
                self._jump_callback_id = player:signal_connect("jump", function()
                    self:_unhook()
                    self._jump_callback_id = nil
                    return meta.DISCONNECT_SIGNAL
                end)
            end

            self._is_hooked = true
            return meta.DISCONNECT_SIGNAL
        end)
    end

    self._motion:set_target_value(0)
    self._motion:set_value(0)
end

--- @brief
function ow.Hook:_unhook()
    if self._is_hooked == false then return end

    -- hook has to be delay to after box2d collision step
    self._world:signal_connect("step", function(_)
        if self._bubble_hook ~= nil then
            self._bubble_hook:destroy()
            self._bubble_hook = nil
        end

        if self._non_bubble_hook ~= nil then
            self._non_bubble_hook:destroy()
            self._non_bubble_hook = nil
        end

        self._is_hooked = false
        self._is_blocked = true

        if self._jump_callback_id ~= nil then
            self._scene:get_player():signal_try_disconnect("jump", self._jump_callback_id)
        end

        return meta.DISCONNECT_SIGNAL
    end)

    self._motion:set_target_value(0)
    self._motion:set_value(0)
end

--- @brief
function ow.Hook:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._x, self._y)

    local value = self._motion:get_value()
    local r = self._radius

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("fraction", rt.InterpolationFunctions.SIGMOID(1 - value))
    _shader:send("player_color", self._color)
    _shader:send("hue", self._hue)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", -r, -r, 2 * r, 2 * r)
    _shader:unbind()


    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(rt.settings.overworld.hook.outline_width + 2)
    love.graphics.line(self._outline)

    love.graphics.setColor(self._color)
    love.graphics.setLineWidth(rt.settings.overworld.hook.outline_width)
    love.graphics.line(self._outline)

    love.graphics.pop()
end

--- @brief
function ow.Hook:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._x, self._y)

    love.graphics.setColor(self._color)
    love.graphics.setLineWidth(rt.settings.overworld.hook.outline_width * 1.5)
    love.graphics.line(self._outline)

    love.graphics.pop()
end