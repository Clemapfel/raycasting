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
        _input = rt.InputSubscriber()
    })

    self._input:signal_connect("pressed", function(_, which)
        local target = math.random() * 2 * math.pi
        dbg(target)
        self._camera:rotate_to(target)

    end)
end

--- @brief
function ow.OverworldScene:enter(stage_id)
    if stage_id ~= self._stage_id then
        self._current_stage_id = stage_id
        self._stage = ow.Stage(stage_id)
        self._player:move_to_stage(self._stage)
        self._camera:move_to(self._player:get_predicted_position(2 * love.timer.getFPS()))
    end
end

--- @brief
function ow.OverworldScene:exit()

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

    self._camera:move_to(self._player:get_position())

    local speed = 2 * math.pi
end