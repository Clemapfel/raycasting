require "common.path1d"

local n_nodes = 128
rt.settings.overworld.fireflies = {
    radius = 10, -- px
    texture_radius = 15, -- px
    core_radius = 3.5,
    path_n_nodes = n_nodes,

    max_glow_offset = 0.75,
    glow_cycle_duration = n_nodes / 10,

    max_hover_offset = 18, -- px
    hover_cycle_duration = n_nodes / 2, -- seconds,

    noise_speed = 2, -- unitless, in phase space
    light_color_alpha = 0.25,

    flow_source_duration = 2, -- seconds
    flow_source_magnitude = 1000, --0.25, -- fraction
}

--- @class ow.Fireflies
ow.Fireflies = meta.class("Fireflies")

local _texture -- rt.RenderTexture
local _circle_radius
local _glow_noise_path -- Path1D
local _hover_offset_path -- Path2D

local _MODE_STATIONARY = 1
local _MODE_FOLLOW_PLAYER = 2

local _fly_hue_t = 0
local _fly_hue_t_step = 1 / 9

--- @brief
function ow.Fireflies:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.POINT, "In ow.Fireflies: object `", object:get_id(), "` is not a point")
    local settings = rt.settings.overworld.fireflies

    do -- init shared globals
        if _texture == nil then
            local r = settings.texture_radius
            local padding = 2
            local texture_w = 2 * (r + padding)
            _texture = rt.RenderTexture(texture_w, texture_w)

            local x, y = 0.5 * texture_w, 0.5 * texture_w

            local inner_inner_r, inner_outer_r = 0.05, 0.25
            local outer_inner_r, outer_outer_r = 0.15, 1
            _circle_radius = inner_inner_r * texture_w
            local inner_color = rt.RGBA(1, 1, 1, 1)
            local outer_color = rt.RGBA(0, 0, 0, 0.0)

            local inner_glow = rt.MeshRing(
                x, y,
                math.max(settings.core_radius, inner_inner_r * r),
                inner_outer_r * r,
                true, -- fill center
                nil,  -- n_outer_vertices
                inner_color, outer_color
            )

            local outer_glow = rt.MeshRing(
                x, y,
                math.max(settings.core_radius, outer_inner_r * r),
                outer_outer_r * r,
                true,
                nil,
                inner_color, outer_color
            )

            love.graphics.push("all")
            love.graphics.reset()
            love.graphics.setColor(1, 1, 1, 1)
            _texture:bind()
            inner_glow:draw()
            outer_glow:draw()
            _texture:unbind()
            love.graphics.pop()
        end

        local function randomize_parameterization(interval_start, interval_end, n, min_size)
            local interval_length = interval_end - interval_start
            local min_total = n * min_size

            local remaining_length = interval_length - min_total

            local split_points = {}
            for i = 1, n - 1 do
                split_points[i] = rt.random.number(0, remaining_length)
            end

            table.sort(split_points)

            local segments = {}
            local previous_point = 0
            for i = 1, n - 1 do
                segments[i] = (split_points[i] - previous_point) + min_size
                previous_point = split_points[i]
            end

            segments[n] = (remaining_length - previous_point) + min_size
            return table.unpack(segments)
        end

        local n_path_nodes = settings.path_n_nodes
        if _glow_noise_path == nil then
            local values = {}
            for i = 1, n_path_nodes do
                table.insert(values, rt.random.number(
                    1 - settings.max_glow_offset,
                    1
                ))
            end

            table.insert(values, values[1])
            _glow_noise_path = rt.Path1D(values)
            _glow_noise_path:override_parameterization(randomize_parameterization(
            0, 1, n_path_nodes, 0
        ))
        end

        if _hover_offset_path == nil then
            local points = {}
            local max_offset = settings.max_hover_offset
            for i = 1, n_path_nodes do
                table.insert(points, rt.random.number(-max_offset, max_offset))
                table.insert(points, rt.random.number(-max_offset, max_offset))
            end

            table.insert(points, points[1])
            table.insert(points, points[2])
            _hover_offset_path = rt.Path2D(points)
            _hover_offset_path:override_parameterization(randomize_parameterization(
                0, 1, n_path_nodes, 1 / n_path_nodes
            ))
        end
    end

    self._stage = stage
    self._scene = scene
    self._world = stage:get_physics_world()

    self._body = b2.Body(
        self._world,
        b2.BodyType.DYNAMIC,
        object.x, object.y,
        b2.Circle(0, 0, settings.radius + settings.max_hover_offset)
    )
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            local player = self._scene:get_player()
            local x, y = self._body:get_position()
            for entry in values(self._fly_entries) do
                if entry.mode ~= _MODE_FOLLOW_PLAYER then
                    player:pulse(entry.color)
                    player:add_flow_source(
                        rt.settings.overworld.fireflies.flow_source_magnitude,
                        rt.settings.overworld.fireflies.flow_source_duration
                    )
                    entry.follow_x, entry.follow_y =
                        x + entry.hover_value_x + entry.x_offset,
                        y + entry.hover_value_y + entry.y_offset

                    entry.mode = _MODE_FOLLOW_PLAYER
                end
            end
        end
    end)

    self._stage:signal_connect("respawn", function(_)
        local x, y = self._body:get_position()
        for entry in values(self._fly_entries) do
            self:_reset_entry(entry)
        end
    end)

    self._should_move_in_place = object:get_boolean("should_move_in_place", false)
    if self._should_move_in_place == nil then self._should_move_in_place = true end

    -- individual flies
    local n_flies = object:get_number("count") or rt.random.number(3, 5)
    local glow_cycle_duration = settings.glow_cycle_duration
    local hover_cycle_duration = settings.hover_cycle_duration
    local noise_speed = settings.noise_speed
    local radius = settings.radius
    local min_factor, max_factor = 0.75, 1.25

    self._fly_entries = {}

    for i = 1, n_flies do
        local hue = _fly_hue_t
        _fly_hue_t = _fly_hue_t + _fly_hue_t_step
        local color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, hue, 1))

        -- light source proxy
        local body = b2.Body(
            self._world,
            b2.BodyType.DYNAMIC,
            object.x, object.y,
            b2.Circle(0, 0,1)
        )

        local follow_speed = object:get_number("velocity") or rt.random.number(0, 1)

        local entry = {
            glow_offset_t = rt.random.number(0, 1),
            glow_cycle_duration = rt.random.number(min_factor * glow_cycle_duration, max_factor * glow_cycle_duration),
            glow_elapsed = 0,
            glow_value = _glow_noise_path:at(0),

            hover_offset_t = rt.random.number(0, 1),
            hover_cycle_duration = rt.random.number(min_factor * hover_cycle_duration, max_factor * hover_cycle_duration),
            hover_elapsed = 0,
            hover_value_x = 0,
            hover_value_y = 0,

            noise_position = rt.random.number(-10e6, 10e6),
            noise_speed = rt.random.number(min_factor * noise_speed, max_factor * noise_speed),

            x_offset = rt.random.number(-2 * radius, 2 * radius),
            y_offset = rt.random.number(-2 * radius, 2 * radius),
            scale = rt.random.number(min_factor, max_factor),

            hue = hue,
            color = color,
            light_color = color:clone(),

            follow_motion = rt.SmoothedMotion2D(
                object.x, object.y,
                math.mix(1 / 8, 1 + 1 / 8, follow_speed), -- speed factor
                true -- linear instead of exponential
            ),

            follow_x = object.x,
            follow_y = object.y,

            body = body
        }

        entry.light_color.a = rt.settings.overworld.fireflies.light_color_alpha
        body:set_collides_with(0x0)
        body:set_collision_group(0x0)
        body:add_tag("point_light_source")
        body:set_user_data({
            get_point_light_sources = function()
                return {{ entry.follow_x + 0.5 * _texture:get_width(), entry.follow_y + 0.5 * _texture:get_height(), 1 }}, { entry.light_color }
            end
        })

        table.insert(self._fly_entries, entry)
    end
end

--- @brief
function ow.Fireflies:update(delta)
    local target_x, target_y = self._scene:get_player():get_position()
    local bounds

    for entry in values(self._fly_entries) do
        if self._stage:get_is_body_visible(entry.body) then
            entry.glow_elapsed = entry.glow_elapsed + delta
            entry.glow_value = _glow_noise_path:at(
                math.fract(entry.glow_elapsed / entry.glow_cycle_duration + entry.glow_offset_t)
            )

            if self._should_move_in_place then
                entry.noise_position = entry.noise_position + entry.noise_speed * delta
                local noise = rt.random.noise(
                    entry.noise_position,
                    -entry.noise_position
                )

                entry.hover_elapsed = entry.hover_elapsed + noise * delta
                entry.hover_value_x, entry.hover_value_y = _hover_offset_path:at(
                    math.fract(entry.hover_elapsed / entry.hover_cycle_duration + entry.hover_offset_t)
                )
            end
        end

        if entry.mode == _MODE_FOLLOW_PLAYER then
            if bounds == nil then
                bounds = self._scene:get_camera():get_world_bounds()
                local padding = 0.25
                bounds.x = bounds.x - padding * bounds.width
                bounds.y = bounds.y - padding * bounds.height
                bounds.width = bounds.width + 2 * padding * bounds.width
                bounds.height = bounds.height + 2 * padding * bounds.height
            end

            local before_x, before_y = entry.follow_motion:get_position()
            entry.follow_motion:set_target_position(target_x, target_y)
            entry.follow_motion:update(delta * entry.scale)
            entry.follow_x, entry.follow_y = entry.follow_motion:get_position()

            entry.body:set_velocity(
                (entry.follow_x - before_x) / delta,
                (entry.follow_y - before_y) / delta
            )

            -- when off-screen, reset
            if math.distance(entry.follow_x, entry.follow_y, target_x, target_y) > 0.5 * math.max(bounds.width, bounds.height) then
                self:_reset_entry(entry)
            end
        end
    end
end

--- @brief
function ow.Fireflies:_reset_entry(entry)
    entry.mode = _MODE_STATIONARY
    entry.follow_x, entry.follow_y = self._body:get_position()
    entry.body:set_position(entry.follow_x, entry.follow_y)
    entry.body:set_velocity(0, 0)
end

--- @brief
function ow.Fireflies:get_render_priority()
    return 1 -- in front of player
end

--- @brief
function ow.Fireflies:draw()
    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")
    local x, y = self._body:get_position()

    local get_position = function(entry)
        if self._mode == _MODE_STATIONARY then
            if self._should_move_in_place then
                return x + entry.hover_value_x + entry.x_offset,
                y + entry.hover_value_y + entry.y_offset
            else
                return x, y
            end
        else
            return entry.follow_x + entry.hover_value_x,
                entry.follow_y + entry.hover_value_y
        end
    end

    local texture_w, texture_h = _texture:get_size()
    for entry in values(self._fly_entries) do
        if self._stage:get_is_body_visible(entry.body) then
            local blend = math.mix(0.75, 1.25, entry.glow_value)

            love.graphics.push()
            love.graphics.translate(-0.5 * texture_w, -0.5 * texture_h)
            love.graphics.translate(get_position(entry))

            love.graphics.scale(entry.scale)

            local r, g, b, a = entry.color:unpack()
            love.graphics.setColor(
                blend * r * a,
                blend * g * a,
                blend * b * a,
                a * entry.glow_value
            )
            _texture:draw()
            love.graphics.pop()
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(2)

    local radius = rt.settings.overworld.fireflies.core_radius
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    for entry in values(self._fly_entries) do
        local circle_x, circle_y = get_position(entry)
        circle_x = circle_x + 0.5 * texture_w * entry.scale
        circle_y = circle_y + 0.5 * texture_h * entry.scale

        love.graphics.translate(-0.5 * texture_w, -0.5 * texture_h)

        local r, g, b, a = entry.color:unpack()
        a = math.mix(0.75, 1, entry.glow_value)

        local under = 0.4
        love.graphics.setColor(
            under * r,
            under * g,
            under * b,
            a
        )

        love.graphics.circle("line",
            circle_x, circle_y,
            radius * entry.scale
        )

        local over = math.mix(1.25, 1.75, entry.glow_value)
        love.graphics.setColor(
            over * r,
            over * g,
            over * b,
            a
        )

        love.graphics.circle("fill",
            circle_x, circle_y, radius * entry.scale
        )
    end

    love.graphics.pop()
end