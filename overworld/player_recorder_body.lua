require "common.smoothed_motion_1d"
require "common.player_body"

do
    local radius = rt.settings.player.radius * 1.5
    rt.settings.overworld.player_recorder_body = {
        radius = radius,
        max_radius = radius * rt.settings.player.bubble_radius_factor,
        n_rings = 7,
        n_ropes_per_ring = 27,
        n_segments_per_rope = 12,
        rope_length_radius_factor = 7
    }
end

--- @class ow.PlayerRecorderBody
ow.PlayerRecorderBody = meta.class("PlayerRecorderBody")

local _settings = rt.settings.overworld.player_recorder_body

--- @brief
function ow.PlayerRecorderBody:instantiate(stage, scene)
    meta.assert(
        stage, ow.Stage,
        scene, ow.OverworldScene
    )

    self._stage = stage
    self._scene = scene
    self._radius = _settings.radius

    self._body = nil
    self._graphics_body = rt.PlayerBody({
        radius = _settings.radius,
        max_radius = _settings.max_radius,

        n_rings = _settings.n_rings,
        n_ropes_per_ring = _settings.n_ropes_per_ring,
        n_segments_per_rope = _settings.n_segments_per_rope,
        rope_length_radius_factor = _settings.rope_length_radius_factor,
        node_mesh_radius = _settings.node_mesh_radius
    })
    self._graphics_body:set_world(stage:get_physics_world())
end

--- @brief
function ow.PlayerRecorderBody:initialize(x, y)
    if self._body ~= nil then -- already initialized
        self:set_position(x, y)
        return
    end

    -- physics shape
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
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    if self._body == nil then return end
    self._graphics_body:set_position(self._body:get_predicted_position())
    self._graphics_body:update(delta)
end

--- @brief
function ow.PlayerRecorderBody:relax()
    self._graphics_body:relax()
end

--- @brief
function ow.PlayerRecorderBody:set_position(x, y)
    self._body:set_position(x, y)
    self._graphics_body:set_position(x, y)
    self._graphics_body:relax()
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
    self._graphics_body:draw_body()
    self._graphics_body:draw_core()
end

--- @brief
function ow.PlayerRecorderBody:update_input(
    up_pressed,
    right_pressed,
    down_pressed,
    left_pressed,
    sprint_pressed,
    jump_pressed,
    is_bubble
)
    self._graphics_body:set_is_bubble(is_bubble)
end

--- @brief
function ow.PlayerRecorderBody:get_radius()
    return self._radius
end