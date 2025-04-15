--- @class ow.BoostField
ow.BoostField = meta.class("BoostField")

local _shader = nil

--- @brief
function ow.BoostField:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
    self._body:signal_connect("collision_start", function(_, other)
        self._is_active = true
        self._player = other:get_user_data()
    end)

    self._body:signal_connect("collision_end", function()
        self._is_active = false
        self._player = nil
    end)

    self._target = object
    self._elapsed = 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "q" then
            _shader:recompile()
        end
    end)
end


--- @brief
function ow.BoostField:draw()
    if _shader == nil then _shader = rt.Shader("overworld/objects/boost_field.glsl") end
    rt.Palette.AQUAMARINE:bind()

    _shader:bind()
    _shader:send("elapsed", self._elapsed)
    self._body:draw()
    _shader:unbind()
end

--- @brief
function ow.BoostField:update(delta)
    self._elapsed = self._elapsed + delta

    if self._is_active then
        local vx, vy = self._player:get_velocity()
        local target_vx, target_vy = 0, -1500
        local duration = 0.2 -- Adjust this factor to control the speed of interpolation

        local new_vx = vx + (target_vx - vx) * (1 / duration) * delta
        local new_vy = vy + (target_vy - vy) * (1 / duration)  * delta

        self._player:set_velocity(new_vx, new_vy)
    end
end