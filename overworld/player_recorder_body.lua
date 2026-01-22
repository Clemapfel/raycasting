require "common.smoothed_motion_1d"
require "common.player_body"

rt.settings.overworld.player_recorder_body = {
    opacity = 0.75,
    gray_value = 0.175,

    splatter_gray = 0.8,
    splatter_opacity = 0.2, -- bloom will still render
    blood_should_override = true,

    mass = 1
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

    self._body = nil
    self._color = rt.Palette.GRAY_2
    self._body_color = rt.RGBA(_settings.gray_value, _settings.gray_value, _settings.gray_value, _settings.opacity)
    self._splatter_color = rt.RGBA(_settings.splatter_gray, _settings.splatter_gray, _settings.splatter_gray, _settings.splatter_opacity)

    self._radius = rt.settings.player.radius
    self._max_radius = self._radius * rt.settings.player.bubble_radius_factor
    self._graphics_body = rt.PlayerBody(0, 0)

    self._graphics_body:set_world(stage:get_physics_world())
    self._graphics_body:set_color(self._color)

    -- core shape
    do
        local n_outer_vertices = rt.settings.player.n_outer_bodies
        local positions = {}
        local r = self._radius - (self._radius * 2 * math.pi) / rt.settings.player.n_outer_bodies / 1.5
        self._blood_splatter_radius = r
        for i = 1, n_outer_vertices do
            local angle = (i - 1) / n_outer_vertices * 2 * math.pi
            table.insert(positions, math.cos(angle) * r)
            table.insert(positions, math.sin(angle) * r)
        end

        self._graphics_body:set_shape(positions)
        self._graphics_body:set_body_color(self._body_color)
        self._graphics_body:set_saturation(0)
    end

    self._graphics_body:set_up_squish(false)
    self._graphics_body:set_down_squish(false)
    self._graphics_body:set_left_squish(false)
    self._graphics_body:set_right_squish(false)

    self._is_bubble = false
    self._position_x = 0
    self._position_y = 0
    self._velocity_x = 0
    self._velocity_y = 0

    self._core_offset_x = 0
    self._core_offset_y = 0
    self._is_initialized = false

    -- sim component
    self._is_simulated = false

    self._bounce_direction_x = 0
    self._bounce_direction_y = 0
    self._bounce_force = 0
    self._bounce_elapsed = math.huge

    self._last_velocity_x = 0
    self._last_velocity_y = 0

    self._gravity_direction_x = 0
    self._gravity_direction_y = 1
end

--- @brief
function ow.PlayerRecorderBody:initialize(x, y, body_type, is_collidable)
    if self._is_initialized == true then return end

    if body_type == nil then body_type = b2.BodyType.KINEMATIC end
    if is_collidable == nil then is_collidable = false end

    -- physics shape
    local player_settings = rt.settings.player

    self._position_x, self._position_y = x, y

    self._world = self._stage:get_physics_world()
    self._body = b2.Body(
        self._world,
        body_type,
        x, y,
        b2.Circle(0, 0, rt.settings.player.radius)
    )
    self._body:set_is_enabled(false)
    self._is_collidable = is_collidable

    self._bubble_body = b2.Body(
        self._world,
        body_type,
        x, y,
        b2.Circle(0, 0, rt.settings.player.radius * rt.settings.player.bubble_radius_factor)
    )
    self._bubble_body:set_is_enabled(false)

    for body in range(self._body, self._bubble_body) do
        local group = ternary(self._is_collidable, rt.settings.player.bounce_collision_group, 0x0)
        body:set_collides_with(group)
        body:set_collision_group(group)
        body:set_user_data(self)

        body:set_mass(rt.settings.overworld.player_recorder_body.mass)

        body:set_user_data(self)
        body:add_tag("point_light_source")
        self.get_point_light_sources = function(self)
            local body = ternary(self._is_bubble, self._bubble_body, self._body)
            local x, y = body:get_position()
            return { { x, y, self._radius } }, { self:get_color() }
        end

        body:add_tag("slippery", "unjumpable", "unwalkable", "stencil", "core_stencil")
    end

    self._graphics_body:set_use_stencils(false)
    self._graphics_body:set_use_contour(self._is_bubble)

    self:set_is_bubble(self._is_bubble)
    self._is_initialized = true
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    local body = self:get_physics_body()
    if body == nil or not self._stage:get_is_body_visible(body) then return end

    if self._is_simulated then
        self:_step(delta)
    end

    -- graphics

    local px, py = body:get_predicted_position()
    self._graphics_body:set_position(px, py)
    self._graphics_body:set_use_contour(self._is_bubble)

    local run_solver = true
    do
        local aabb = self._scene:get_camera():get_world_bounds()
        local r = 4 * self._radius
        aabb.x = aabb.x - r
        aabb.y = aabb.y - r
        aabb.width = aabb.width + 2 * r
        aabb.height = aabb.height + 2 * r
        run_solver = aabb:contains(px, py)
    end

    if run_solver then
        self._graphics_body:update(delta)
    else
        self._graphics_body:relax()
    end

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
    local cx, cy = body:get_position()
    local ray_length = self._max_radius

    for ray_i = 1, n_rays do
        local angle = (ray_i - 1) / n_rays * 2 * math.pi
        local dx, dy = math.cos(angle), math.sin(angle)

        local tx, ty, nx, ny, hit_body = self._world:query_ray(
            cx, cy,
            ray_length * dx,
            ray_length * dy,
            mask
        )

        if hit_body ~= nil then
            local color_r, color_g, color_b, color_a = self._splatter_color:unpack()
            blood_splatter:add(tx, ty, self._blood_splatter_radius,
                color_r, color_g, color_b, color_a,
                _settings.blood_should_override -- override
            )
        end
    end
end

--- @brief
function ow.PlayerRecorderBody:_step(delta)
    local body = self:get_physics_body()
    if body == nil then return end

    local next_velocity_x, next_velocity_y = body:get_velocity()
    local player_settings = rt.settings.player

    -- bounce
    local fraction = self._bounce_elapsed / player_settings.bounce_duration
    if fraction <= 1 then
        if _settings.bounce_duration == 0 then
            next_velocity_x = next_velocity_x + self._bounce_direction_x * self._bounce_force
            next_velocity_y = next_velocity_y + self._bounce_direction_y * self._bounce_force
        else
            local bounce_force = (1 - fraction) * self._bounce_force
            next_velocity_x = next_velocity_x + self._bounce_direction_x * bounce_force
            next_velocity_y = next_velocity_y + self._bounce_direction_y * bounce_force
        end
    else
        self._bounce_force = 0
    end
    self._bounce_elapsed = self._bounce_elapsed + delta

    local gravity = player_settings.gravity * delta
    if self._is_bubble then
        --[[
        local mass_multiplier = self._scene:get_player():get_bubble_mass_factor()
        local bubble_gravity = gravity * (mass_multiplier / delta) * player_settings.bubble_gravity_factor
        self._bubble_body:apply_force(
            self._gravity_direction_x * bubble_gravity,
            self._gravity_direction_y * bubble_gravity
        )
        ]]--

        -- no gravity as bubble
    else
        next_velocity_x = next_velocity_x + self._gravity_direction_x * gravity
        next_velocity_y = next_velocity_y + self._gravity_direction_y * gravity
    end

    body:set_velocity(next_velocity_x, next_velocity_y)
    self._last_velocity_x = next_velocity_x
    self._last_velocity_y = next_velocity_y
end

--- @brief
function ow.PlayerRecorderBody:relax()
    self._graphics_body:relax()
end

--- @brief
function ow.PlayerRecorderBody:set_position(x, y)
    self._bubble_body:set_position(x, y)
    self._body:set_position(x, y)
    self._graphics_body:set_position(x, y)
end

--- @brief
function ow.PlayerRecorderBody:get_position()
    return self:get_physics_body():get_position()
end

--- @brief
function ow.PlayerRecorderBody:set_velocity(vx, vy)
    self._bubble_body:set_velocity(vx, vy)
    self._body:set_velocity(vx, vy)
end

--- @brief
function ow.PlayerRecorderBody:get_velocity()
    return self:get_physics_body():get_velocity()
end

--- @brief
function ow.PlayerRecorderBody:set_core_offset(dx, dy)
    self._core_offset_x = dx
    self._core_offset_y = dy
end

--- @brief
function ow.PlayerRecorderBody:draw()
    local body = self:get_physics_body()
    if body == nil or not self._stage:get_is_body_visible(body) then return end

    self._graphics_body:draw_body()

    love.graphics.push()
    love.graphics.translate(self._core_offset_x, self._core_offset_y)
    self._graphics_body:draw_core()
    love.graphics.pop()
end

--- @brief
function ow.PlayerRecorderBody:draw_bloom()
    local body = self:get_physics_body()
    if body == nil or not self._stage:get_is_body_visible(body) then return end

    self._graphics_body:draw_bloom()
end

--- @brief
function ow.PlayerRecorderBody:set_is_bubble(is_bubble)
    meta.assert(is_bubble, "Boolean")
    self._is_bubble = is_bubble

    self._bubble_body:set_is_enabled(false)
    self._body:set_is_enabled(false)

    if self._is_bubble then
        self._bubble_body:set_is_enabled(true)
    else
        self._body:set_is_enabled(true)
    end

    self._graphics_body:set_use_contour(self._is_bubble)
end

--- @brief
function ow.PlayerRecorderBody:get_is_bubble()
    return self._is_bubble
end

--- @brief
function ow.PlayerRecorderBody:get_radius()
    return self._radius
end

--- @brief
function ow.PlayerRecorderBody:get_physics_body()
    return ternary(self._is_bubble, self._bubble_body, self._body)
end

--- @brief
function ow.PlayerRecorderBody:get_color()
    return self._color
end

--- @brief
function ow.PlayerRecorderBody:bounce(nx, ny, magnitude)
    local settings = rt.settings.player
    self._bounce_direction_x = nx
    self._bounce_direction_y = ny

    local nvx, nvy = self._last_velocity_x, self._last_velocity_y

    if magnitude == nil then
        magnitude = math.mix(settings.bounce_min_force, settings.bounce_max_force, math.min(1, math.magnitude(nvx, nvy) / settings.bounce_relative_velocity))
    end

    self._bounce_force = magnitude
    self._bounce_elapsed = 0

    return self._bounce_force / settings.bounce_max_force
end

--- @brief
function ow.PlayerRecorderBody:set_is_simulated(b)
    self._is_simulated = b
end

--- @brief
function ow.PlayerRecorderBody:get_is_simulated()
    return self._is_simulated
end