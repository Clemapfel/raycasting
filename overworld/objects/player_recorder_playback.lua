--- @class ow.PlayerRecorderPlayback
ow.PlayerRecorderPlayback = meta.class("PlayerRecorderPlayback")

--- @brief
function ow.PlayerRecorderPlayback:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

    rt.assert(object:get_type() == ow.ObjectType.POINT, "In ow.PlayerRecorderPlayer: object `", object:get_id(), "` is not a POINT")

    self._player_recorder = ow.PlayerRecorder(stage, scene, object.x, object.y)
    self._path_directory = object:get_string("path", true)

    self._player_recorder:import(self._path_directory, object.x, object.y) -- relative path
    self._player_recorder:play()
end

--- @brief
function ow.PlayerRecorderPlayback:update(delta)
    if not self._stage:get_is_body_visible(self._player_recorder:get_physics_body()) then return end
    self._player_recorder:update(delta)
end

--- @brief
function ow.PlayerRecorderPlayback:draw()
    if not self._stage:get_is_body_visible(self._player_recorder:get_physics_body()) then return end
    self._player_recorder:draw()
end