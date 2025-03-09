require "common.scene"

require "overworld.stage"
require "overworld.camera"
require "physics.physics"

--- @class
ow.OverworldScene = meta.class("OverworldScene", rt.Scene)

--- @brief
function ow.OverworldScene:instantiate()
    meta.install(self, {
        _camera = ow.Camera(),
        _current_stage_id = nil,
        _stage = nil,
        _player = ow.Player(),
        _input = rt.InputSubscriber(),

        _player_movement_start_signal_handler = nil,
        _player_movement_stop_signal_handler = nil,
        _player_is_focused = false,
    })

    self._input:signal_connect("pressed", function(_, which)

    end)

    self._input:signal_connect("mouse_moved", function(_, x, y)
    end)
end

--- @brief
function ow.OverworldScene:enter(stage_id)
    if stage_id ~= self._stage_id then
        self._current_stage_id = stage_id
        self._stage = ow.Stage(stage_id)
        self._player:move_to_stage(self._stage)
        self._player_movement_start_signal_handler = self._player:signal_connect("movement_start", function(_, x, y)
            self._camera:move_to(x, y)
            self._player_is_focused = true
        end)

        self._player_movement_stop_signal_handler = self._player:signal_connect("movement_stop", function(_, x, y)
            self._player_is_focused = false
        end)

        self._camera:move_to(self._player:get_position())
    end
end

--- @brief
function ow.OverworldScene:exit()
    self._player:signal_disconnect("movement_start", self._player_movement_start_signal_handler)
    self._player:signal_disconnect("movement_stop", self._player_movement_stop_signal_handler)
end

--- @brief
function ow.OverworldScene:size_allocate(x, y, width, height)

end

--- @brief
function ow.OverworldScene:draw()
    self._camera:bind()
    self._stage:draw()
    self._player:draw()
    self._camera:unbind()
end

--- @brief
function ow.OverworldScene:update(delta)
    self._camera:update(delta)
    self._stage:update(delta)
    self._player:update(delta)

    if self._player_is_focused then
        self._camera:move_to(self._player:get_position())
    end

    local scale_speed = 1
    if self._input:is_down(rt.InputButton.L) then
        self._camera:set_zoom(self._camera:get_zoom() + scale_speed * delta)
    elseif self._input:is_down(rt.InputButton.R) then
        self._camera:set_zoom(self._camera:get_zoom() - scale_speed * delta)
    end

    local rotation_speed = 2 * math.pi / 10
    if love.keyboard.isDown("b") then
        self._camera:set_rotation(self._camera:get_rotation() + rotation_speed * delta)
    elseif love.keyboard.isDown("v") then
        self._camera:set_rotation(self._camera:get_rotation() - rotation_speed * delta)
    end
    self._player:set_facing_angle(self._camera:get_rotation())

    local translate_speed = 400
    local x, y = self._camera:get_position()
    if love.keyboard.isDown("left") then
        self._player_is_focused = false
        self._camera:set_position(x - translate_speed * delta, y)
    elseif love.keyboard.isDown("right") then
        self._player_is_focused = false
        self._camera:set_position(x + translate_speed * delta, y)
    end

    if love.keyboard.isDown("up") then
        self._player_is_focused = false
        self._camera:set_position(x, y - translate_speed * delta)
    elseif love.keyboard.isDown("down") then
        self._player_is_focused = false
        self._camera:set_position(x, y + translate_speed * delta)
    end
end