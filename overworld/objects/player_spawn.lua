rt.settings.overworld.player_spawn = {
    max_spawn_duration = 5
}

--- @class ow.PlayerSpawn
ow.PlayerSpawn = meta.class("PlayerSpawn")

--- @brief
function ow.PlayerSpawn:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.PlayerSpawn: object hast to be a point")
    meta.install(self, {
        _scene = scene,
        _x = object.x,
        _y = object.y,

        _target_x = nil,
        _target_y = nil,
    })
    stage:set_player_spawn(self._x, self._y)

    stage:signal_connect("initialized", function()
        local world = stage:get_physics_world()
        local x, y, nx, ny, body = world:query_ray(self._x, self._y, 0, 10e9)
        if x == nil then -- no ground
            x, y = self._x, self._y
        end

        self._target_x, self._target_y = x, y
        scene:get_camera():set_position(self._target_x, self._target_y)
        self:spawn()
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.PlayerSpawn:update(delta)
    if self._waiting_for_player then
        self._elapsed = self._elapsed + delta
        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        -- once player reached location, unfreeze, with timer as failsafe
        if player_y >= (self._target_y - player:get_radius()) or self._elapsed > rt.settings.overworld.player_spawn.max_spawn_duration then
            player:enable()
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
            self._waiting_for_player = false
        end
    end
end

--- @brief
function ow.PlayerSpawn:spawn()
    local player = self._scene:get_player()
    player:disable()
    player:set_velocity(0, 0)
    player:teleport_to(self._x, self._y)
    self._waiting_for_player = true
    self._elapsed = 0

    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
    self._scene:get_camera():move_to(self._target_x, self._target_y - player:get_radius()) -- jump cut at start of level

    player:set_last_player_spawn(self)
end