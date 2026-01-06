require "common.smoothed_motion_1d"
require "common.player_body"

rt.settings.overworld.player_recorder_body = {
    opacity = 0.75,
    gray_value = 0.175,

    splatter_gray = 0.8,
    splatter_opacity = 0.2 -- bloom will still render
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
    self._graphics_body = rt.PlayerBody({
        radius = self._radius,
        max_radius = self._max_radius,
        rope_length_radius_factor = 1
    })

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

    self._bubble_body = b2.Body(
        self._world,
        body_type,
        x, y,
        b2.Circle(0, 0, rt.settings.player.radius * rt.settings.player.bubble_radius_factor)
    )
    self._bubble_body:set_is_enabled(false)
    self._is_collidable = is_collidable

    for body in range(self._body, self._bubble_body) do
        if not is_collidable then
            body:set_collides_with(0x0)
            body:set_collision_group(0x0)
        end

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

    self:set_is_bubble(self._is_bubble)
    self._is_initialized = true
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    local body = ternary(self._is_bubble, self._bubble_body, self._body)
    if body == nil or not self._stage:get_is_body_visible(body) then return end

    self._graphics_body:set_position(body:get_predicted_position())
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
    self._position_x, self._position_y = x, y

    self._bubble_body:set_position(x, y)
    self._body:set_position(x, y)

    self._graphics_body:set_position(x, y)
    self._graphics_body:relax()
end

--- @brief
function ow.PlayerRecorderBody:get_position()
    return self._position_x, self._position_y
end

--- @brief
function ow.PlayerRecorderBody:set_velocity(vx, vy)
    self._velocity_x, self._velocity_y = vx, vy

    local body = ternary(self._is_bubble, self._bubble_body, self._body)
    body:set_velocity(vx, vy)
end

--- @brief
function ow.PlayerRecorderBody:set_core_offset(dx, dy)
    self._core_offset_x = dx
    self._core_offset_y = dy
end

--- @brief
function ow.PlayerRecorderBody:draw()
    local body = ternary(self._is_bubble, self._bubble_body, self._body)
    if body == nil or not self._stage:get_is_body_visible(body) then return end

    self._graphics_body:draw_body()

    love.graphics.push()
    love.graphics.translate(self._core_offset_x, self._core_offset_y)
    self._graphics_body:draw_core()
    love.graphics.pop()
end

--- @brief
function ow.PlayerRecorderBody:draw_bloom()
    self._graphics_body:draw_bloom()
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
    self._is_bubble = is_bubble
    self._graphics_body:set_use_contour(is_bubble, rt.PlayerBodyContourType.CIRCLE)
    self:set_position(self._position_x, self._position_y)
    self:set_velocity(self._velocity_x, self._velocity_y)

    -- disable both to prevent interaction
    self._body:set_is_enabled(false)
    self._bubble_body:set_is_enabled(false)

    if self._is_bubble then
        self._bubble_body:set_is_enabled(true)
        self._bubble_body:set_position(self._position_x, self._position_y)
    else
        self._body:set_is_enabled(true)
        self._body:set_position(self._position_x, self._position_y)
    end
end

--- @brief
function ow.PlayerRecorderBody:set_is_bubble(is_bubble)
    self:update_input(
        false, false, false, false,
        false, false,
        is_bubble
    )
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
