require "common.sound_manager"
require "common.timed_animation"

rt.settings.overworld.coin = {
    radius = 5,
    pulse_animation_duration = 0.4,
    sound_id = "overworld_coin_collected",
    flow_increase = 0.1
}

--- @class ow.Coin
ow.Coin = meta.class("Coin")

local _pulse_mesh = nil

--- @brief
function ow.Coin:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Coin.instantiate: object is not a point")

    self._id = object.id -- TODO: global id

    self._stage = stage
    self._scene = scene
    self._x, self._y = object.x, object.y
    self._pulse_x, self._pulse_y = 0, 0

    stage:add_coin(self, self._id)

    self._color = rt.RGBA(0, 0, 0, 1)

    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, rt.settings.overworld.coin.radius)
    )

    self._x, self._y, self._radius = object.x, object.y, rt.settings.overworld.coin.radius

    self._is_collected = false
    self._timestamp = -math.huge -- timestamp of collection

    self._body:set_is_sensor(true)
    self._body:set_collides_with(bit.bor(
        rt.settings.player.player_collision_group,
        rt.settings.player.player_outer_body_collision_group
    ))

    self._body:signal_connect("collision_start", function(self_body, player_body)
        if self._is_collected then return end
        rt.SoundManager:play(rt.settings.overworld.coin.sound_id)
        self._is_collected = true
        self._stage:set_coin_is_collected(self._id, true)
        self._timestamp = love.timer.getTime()
        self._pulse_opacity_animation:reset()
        self._pulse_active = true

        local player = self._scene:get_player()
        local current = player:get_flow()
        player:set_flow(player:get_flow() + rt.settings.overworld.coin.flow_increase)
        player:set_flow_velocity(0)
    end)

    if _pulse_mesh == nil then
        _pulse_mesh = rt.MeshCircle(0, 0, rt.settings.player.radius * 2)

        _pulse_mesh:set_vertex_color(1, 1, 1, 1, 0)
        for i = 2, _pulse_mesh:get_n_vertices() do
            _pulse_mesh:set_vertex_color(i, 1, 1, 1, 1)
        end
        _pulse_mesh = _pulse_mesh:get_native()
    end

    self._pulse_opacity_animation = rt.TimedAnimation(
        rt.settings.overworld.coin.pulse_animation_duration,
        1, 0
    )
    self._pulse_active = false
end

--- @brief
function ow.Coin:get_render_priority()
    return math.huge
end

--- @brief
function ow.Coin:set_is_collected(b)
    self._is_collected = b
end

--- @brief
function ow.Coin:get_is_collected()
    return self._is_collected
end

--- @brief
function ow.Coin:update(delta)
    if self._is_collected then
        if self._pulse_active then
            self._pulse_active = not self._pulse_opacity_animation:update(delta)
            self._pulse_x, self._pulse_y = self._scene:get_player():get_physics_body():get_predicted_position()
        end
    end
end

--- @brief
function ow.Coin:draw_coin(x, y, r, g, b, a)
    love.graphics.setLineWidth(1)
    local d = 0.35
    love.graphics.setColor(r - d, g - d, b - d, 1)
    love.graphics.circle("fill", x, y, rt.settings.overworld.coin.radius)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("line", x, y, rt.settings.overworld.coin.radius)
end

--- @brief
function ow.Coin:draw()
    if self._is_collected then
        if self._pulse_active then
            local r, g, b = self._color:unpack()
            local x, y = self._pulse_x, self._pulse_y
            local v = self._pulse_opacity_animation:get_value()
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(2 * (1 - v))
            love.graphics.translate(-x, -y)
            love.graphics.setColor(r, g, b, v)
            love.graphics.draw(_pulse_mesh, x, y)
            love.graphics.pop()
        end
    else
        local r, g, b = self._color:unpack()
        ow.Coin:draw_coin(self._x, self._y, r, g, b, 1)
    end
end

--- @brief
function ow.Coin:set_color(color)
    self._color = color
end

--- @brief
function ow.Coin:get_color()
    return self._color
end

--- @brief
function ow.Coin:get_position()
    return self._x, self._y
end

--- @brief
function ow.Coin:get_time_since_collection()
    return love.timer.getTime() - self._timestamp
end