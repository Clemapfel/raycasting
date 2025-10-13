require "common.smoothed_motion_1d"
require "common.player_body"

rt.settings.overworld.player_recorder_body = {
    radius_factor = 1,
    length_factor = 1
}

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
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, 0, 1))

    local radius_factor = _settings.radius_factor
    local length_factor = _settings.length_factor

    self._radius = radius_factor * self._scene:get_player():get_radius()
    self._max_radius = self._radius * rt.settings.player.bubble_radius_factor
    self._graphics_body = rt.PlayerBody({
        radius = self._radius,
        max_radius = self._max_radius,
        rope_length_radius_factor = rt.settings.player_body.default_rope_length_radius_factor * length_factor,
    })
    self._graphics_body:set_world(stage:get_physics_world())

    -- core shape
    do
        local n_outer_vertices = rt.settings.player.n_outer_bodies
        local positions = {}
        local r = radius_factor * self._scene:get_player():get_core_radius() - 1.5
        for i = 1, n_outer_vertices do
            local angle = (i - 1) / n_outer_vertices * 2 * math.pi
            table.insert(positions, math.cos(angle) * r)
            table.insert(positions, math.sin(angle) * r)
        end

        self._graphics_body:set_shape(positions)
        self._graphics_body:set_opacity(0.5)
    end
end

--- @brief
function ow.PlayerRecorderBody:initialize(x, y)
    if self._body ~= nil then -- already initialized
        self:set_position(x, y)
        return
    end

    -- physics shape
    local player_settings = rt.settings.player
    local mask = bit.bnot(bit.bor(
        player_settings.player_collision_group,
        player_settings.player_outer_body_collision_group,
        player_settings.bounce_collision_group,
        player_settings.ghost_collision_group
    ))

    self._world = self._stage:get_physics_world()
    self._body = b2.Body(
        self._world,
        b2.BodyType.DYNAMIC,
        x, y,
        b2.Circle(0, 0, rt.settings.player.radius)
    )
    self._body:set_collides_with(mask)
    self._body:set_collision_group(player_settings.exempt_collision_group)
    self._body:set_user_data(self)
    self._body:add_tag("light_source")
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    if self._body == nil or not self._stage:get_is_body_visible(self._body) then return end

    self._graphics_body:set_position(self._body:get_predicted_position())
    self._graphics_body:update(delta)

    -- blood splatter
    local player_settings = rt.settings.player
    local mask = bit.bnot(bit.bor(
        player_settings.player_collision_group,
        player_settings.player_outer_body_collision_group,
        player_settings.bounce_collision_group,
        player_settings.ghost_collision_group
    ))

    local blood_splatter = self._stage:get_blood_splatter()
    local n_rays = 8
    local cx, cy = self._body:get_position()
    local ray_length = self._max_radius

    for ray_i = 1, n_rays do
        local angle = (ray_i - 1) / n_rays * 2 * math.pi
        local dx, dy = math.cos(angle), math.sin(angle)

        local tx, ty, nx, ny, body = self._world:query_ray(
            cx, cy,
            ray_length * dx,
            ray_length * dy,
            mask
        )

        if body ~= nil then
            blood_splatter:add(tx, ty, self._radius,
                0,  -- hue
                0.5, -- opacity
                false -- override
            )
        end
    end
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
    if self._body == nil or not self._stage:get_is_body_visible(self._body) then return end

    self._graphics_body:draw_body()
    self._graphics_body:draw_core()

    love.graphics.setColor(1, 1, 1, 1)
    if self._dbg ~= nil then
        for line in values(self._dbg) do
            love.graphics.line(line)
        end
    end
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

--- @brief
function ow.PlayerRecorderBody:get_color()
    return self._color
end