rt.settings.overworld.checkpoint = {
    max_spawn_duration = 5,
    width = 5
}

--- @class ow.Checkpoint 
ow.Checkpoint = meta.class("Checkpoint")

--- @class ow.CheckpointBody
ow.CheckpointBody = meta.class("CheckpointBody") -- dummy for `body` property

--- @class ow.PlayerSpawn
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, true)
end

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, is_player_spawn)
    meta.install(self, {
        _scene = scene,
        _x = object.x,
        _y = object.y,

        _target_x = nil,
        _target_y = nil,

        _body = nil,
    })

    if is_player_spawn == true then
        stage:set_player_spawn(self._x, self._y)
    end

    stage:signal_connect("initialized", function()
        local world = stage:get_physics_world()
        local ground_x, ground_y, nx, ny, body = world:query_ray(self._x, self._y, 0, 10e9)
        if ground_x == nil then -- no ground
            rt.error("In ow.Checkpoint: checkpoint `" .. object:get_id() .. "` is not above solid ground")
        end

        self._target_x, self._target_y = ground_x, ground_y

        local target = object:get_object("body")

        if target == nil then

            local width = rt.settings.overworld.checkpoint.width
            local left_nx, left_ny = math.turn_left(nx, ny)
            local right_nx, right_ny = math.turn_right(nx, ny)
            local left_x, left_y = ground_x + left_nx * width, ground_y + left_ny * width
            local right_x, right_y = ground_x + right_nx * width, ground_y + right_ny * width

            local bottom_y = math.max(left_y, right_y)
            self._body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, 0, 0, b2.Polygon(
                self._x - width, self._y,
                self._x + width, self._y,
                self._x + width, bottom_y,
                self._x - width, bottom_y
            ))
        else
            self._body = target:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC)
        end

        self._body:set_is_sensor(true)
        self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
        self._body:signal_connect("collision_start", function(_, other_body)
            assert(other_body:has_tag("player"))
            other_body:get_user_data():set_last_player_spawn(self)
        end)

        if is_player_spawn == true then
            scene:get_camera():set_position(self._target_x, self._target_y) -- smash cut on spawn
        end
        self:spawn()

        local radius = rt.settings.overworld.player.radius

        local top_x, top_y = self._x, self._y
        local data = {
            { top_x, top_y, 0, 0, 1, 1, 1, 0 }
        }


        self._mesh = rt.MeshCircle(top_x, top_y, radius)
        self._mesh:set_vertex_color(1, 0, 0, 0, 0)

        local bottom_x, bottom_y = self._target_x, self._target_y
        local w = 0.1 * radius
        self._beam_mesh = rt.Mesh({
            { top_x - w, top_y, 0, 0, 1, 1, 1, 1 },
            { top_x, top_y, 0, 0, 1, 1, 1, 0 },
            { top_x + w, top_y, 0, 0, 1, 1, 1, 1},
            { bottom_x - w, bottom_y, 0, 0, 1, 1, 1, 1 },
            { bottom_x, bottom_y, 0, 0, 1, 1, 1, 0 },
            { bottom_x + w, bottom_y, 0, 0, 1, 1, 1, 1 }
        }, rt.MeshDrawMode.TRIANGLES)
        self._beam_mesh._native:setVertexMap(
            1, 2, 4,
            2, 4, 5,
            2, 3, 6,
            2, 5, 6
        )

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Checkpoint:update(delta)
    if self._waiting_for_player then
        self._elapsed = self._elapsed + delta
        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        -- once player reached location, unfreeze, with timer as failsafe
        if player_y >= (self._target_y - player:get_radius()) or self._elapsed > rt.settings.overworld.checkpoint.max_spawn_duration then
            player:enable()
            player:set_trail_visible(true)
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
            self._waiting_for_player = false
        end
    end
end

--- @brief
function ow.Checkpoint:spawn()
    self._scene:set_camera_mode(ow.CameraMode.MANUAL)

    local player = self._scene:get_player()
    player:disable()
    local vx, vy = player:get_velocity()
    player:set_velocity(0, rt.settings.overworld.player.air_target_velocity_x)
    player:set_trail_visible(false)
    player:teleport_to(self._x, self._y)
    self._waiting_for_player = true
    self._elapsed = 0

    self._scene:get_camera():move_to(self._target_x, self._target_y - player:get_radius()) -- jump cut at start of level
    player:set_last_player_spawn(self)
    player:signal_emit("respawn")
end

--- @brief
function ow.Checkpoint:draw()
    self._mesh:draw()
    self._beam_mesh:draw()
end