rt.settings.overworld.goal = {

}

--- @class ow.Goal
ow.Goal = meta.class("Goal")

local _shader = nil

--- @brief
function ow.Goal:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.Goal.instantiate: object is not a rectangle")

    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._stage = stage
    self._scene = scene

    self._stage:_notify_goal_added(self)

    self._x = object.x
    self._y = object.y
    self._width = object.width
    self._height = object.height

    self._elapsed = 0
    self._camera_offset = { 0, 0 }
    self._camera_scale = 1
    self._player_position = { 0, 0 }
    self._player_radius = 0
    self._size = { self._width, self._height }
    self._color = { rt.Palette.GOAL:unpack() }

    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function()
        self._scene:finish_stage()
        ---self._color = { rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1) }
        --return meta.DISCONNECT_SIGNAL
    end)

    if _shader == nil then
        _shader = rt.Shader("overworld/objects/goal.glsl")
    end

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "t" then
            local before = love.timer.getTime()
            _shader:recompile("overworld/objects/goal.glsl")
            dbg((love.timer.getTime() - before) / (1 / 60))
        end
    end)
end

--- @brief
function ow.Goal:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    local camera = self._scene:get_camera()
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    local player = self._scene:get_player()
    local px, py = player:get_position()
    px = (px - self._x) / self._width
    py = (py - self._y) / self._height
    self._player_position = { px, py }
    self._player_radius = player:get_radius()

    self._elapsed = self._elapsed + delta
end

--- @brief
function ow.Goal:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    love.graphics.setColor(table.unpack(self._color))

    _shader:bind()
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("elapsed", self._elapsed)
    _shader:send("color", self._color)
    _shader:send("player_position", self._player_position)
    _shader:send("player_radius", self._player_radius)
    _shader:send("size", self._size)

    love.graphics.rectangle("fill", self._x, self._y, self._width, self._height)
    _shader:unbind()

    love.graphics.setLineWidth(3)
    love.graphics.line(self._x, self._y, self._x, self._y + self._height)
end

