rt.settings.overworld.hook = {
    radius_factor = 1.8,
    hook_animation_duration = 1,
    hook_sound_id = "hook"
}

--- @class ow.Hook
ow.Hook = meta.class("OverworldHook", rt.Drawable)

local _shader

--- @brief
function ow.Hook:instantiate(object, stage, scene)
    self._radius = rt.settings.player.radius * rt.settings.overworld.hook.radius_factor
    if _shader == nil then _shader = rt.Shader("overworld/objects/hook.glsl") end

    self._scene = scene
    self._radius = rt.settings.player.radius * rt.settings.overworld.hook.radius_factor

    self._world = stage:get_physics_world()
    self._body = b2.Body(
        self._world,
        b2.BodyType.STATIC,
        object.x, object.y,
        b2.Circle(0, 0, self._radius)
    )

    self._x, self._y = object.x, object.y

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
end

--- @brief
function ow.Hook:_hook()
    if self._is_hooked == true or self._is_blocked then return end
    local player = self._scene:get_player()

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
end

--- @brief
function ow.Hook:_unhook()
    if self._is_hooked == false then return end

    -- hook has to be delay to after box2d collision step
    self._world:signal_connect("step", function(_)
        self._bubble_hook:destroy()
        self._bubble_hook = nil
        self._non_bubble_hook:destroy()
        self._non_bubble_hook = nil
        self._is_hooked = false
        self._is_blocked = true

        if self._jump_callback_id ~= nil then
            self._scene:get_player():signal_disconnect("jump", self._jump_callback_id)
        end

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Hook:draw()
    love.graphics.setColor(1, 1, 1, 1)

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    local r = 2 * self._radius
    love.graphics.rectangle("fill", self._x - r, self._y - r, 2 * r, 2 * r)
    _shader:unbind()
end