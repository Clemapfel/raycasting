--- @class ow.PlayerRecorderBody
ow.PlayerRecorderBody = meta.class("PlayerRecorderBody")

--- @brief
function ow.PlayerRecorderBody:instantiate(player_recorder, stage, scene)
    meta.assert(
        player_recorder, ow.PlayerRecorder,
        stage, ow.Stage,
        scene, ow.OverworldScene
    )

    self._recorder = player_recorder
    self._stage = stage
    self._scene = scene

    self._radius = rt.settings.player.radius
end

--- @brief
function ow.PlayerRecorderBody:initialize(x, y)
    if self._body == nil then
        self._body = b2.Body(
            self._stage:get_physics_world(),
            b2.BodyType.DYNAMIC,
            x, y,
            b2.Circle(0, 0, self._radius)
        )

        local player_settings = rt.settings.player
        self._body:set_collides_with(bit.bnot(bit.bor(
            player_settings.player_collision_group,
            player_settings.player_outer_body_collision_group,
            player_settings.bounce_collision_group,
            player_settings.ghost_collision_group
        )))
        self._body:set_collision_group(player_settings.exempt_collision_group)
        self._body:signal_connect("collision_start", function(_, other_body, normal_x, normal_y, x1, y1, x2, y2)
            if x1 ~= nil then
                self._stage:get_blood_splatter():add(x1, y1, self._radius, 0, 0)
            end
        end)
    else
        self:set_position(x, y)
    end
end

--- @brief
function ow.PlayerRecorderBody:set_position(x, y)
    self._body:set_position(x, y)
end

--- @brief
function ow.PlayerRecorderBody:get_position()
    return self._body:get_position()
end

--- @brief
function ow.PlayerRecorderBody:set_velocity(dx, dy)
    self._body:set_velocity(dx, dy)
end

--- @brief
function ow.PlayerRecorderBody:draw()
    self._body:draw()
end