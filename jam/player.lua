Player_t = "Player"

local _settings_min_node_count = 16
local _settings_node_density = 1 / 40
local _settings_outline_width = 4

player_new = function(...)
    return player_init(object_new(Player_t, {
        softbody = nil,
        radius = nil,

        position_x = 0,
        position_y = 0,

        linear_velocity_requests = {}, -- Table<Any, { dx, dy }>
        angular_velocity_requests = {}, -- Table<Any, { theta }>
        volume_requests = {}, -- Table<Any, { volume }>

        is_active = false,
        is_clickable = false,
    }), ...)
end

player_init = function(self, x, y, radius)
    log_typecheck(self, Player_t, x, Number_t, y, Number_t, radius, Number_t)

    local n_nodes = math_max(
        _settings_min_node_count,
        _settings_node_density * math_tau * radius
    )

    if self.body ~= nil and radius == self.radius then
        self.body = softbody_init(self.body, x, y, radius, n_nodes)
    else
        self.body = softbody_new(x, y, radius, n_nodes)
    end

    self.position_x = x
    self.position_y = y
    self.radius = radius

    return self
end

player_update = function(self, delta)
    log_typecheck(self, Player_t, delta, Number_t)

    -- integrate forces
    local dx, dy = 0, 0
    for entry in iter_values(self.linear_velocity_requests) do
        dx = dx + entry.dx
        dy = dy + entry.dy
    end

    local theta = 0
    for entry in iter_values(self.angular_velocity_requests) do
        theta = theta + entry.dtheta
    end

    local volume = 1
    for entry in iter_values(self.volume_requests) do
        volume = volume * entry.volume
    end

    softbody_set_target_linear_velocity(self.body, dx, dy)
    softbody_set_target_angular_velocity(self.body, theta)
    softbody_set_target_volume(self.body, volume)

    softbody_update(self.body, delta)

    return self
end

player_request_linear_velocity = function(self, instance, dx, dy)
    log_typecheck(self, Player_t, instance, Table_t)

    if dx == nil or dy == nil then
        -- remove request
        log_typecheck_arg_i(dx, Nil_t, 3)
        log_typecheck_arg_i(dy, Nil_t, 4)

        self.linear_velocity_requests[instance] = nil
    else
        -- add / update request
        log_typecheck_arg_i(dx, Number_t, 3)
        log_typecheck_arg_i(dy, Number_t, 4)

        local current = self.linear_velocity_requests[instance]
        if current ~= nil then
            current.dx = dx
            current.dy = dy
        else
            self.linear_velocity_requests[instance] = {
                dx = dx,
                dy = dy
            }
        end
    end

    return self
end

player_request_angular_velocity = function(self, instance, dtheta)
    log_typecheck(self, Player_t, instance, Table_t)

    if dtheta == nil then
        self.angular_velocity_requests[instance] = nil
    else
        log_typecheck_arg_i(dtheta, Number_t, 3)
        local current = self.angular_velocity_requests[instance]
        if current ~= nil then
            current.dtheta = dtheta
        else
            self.angular_velocity_requests[instance] = {
                dtheta = dtheta
            }
        end
    end

    return self
end

player_request_volume_multiplier = function(self, instance, fraction)
    log_typecheck(self, Player_t, instance, Table_t)
    log_assert(fraction >= 0, "In player_request_volume_multiplier: fraction must be non-negative")

    if fraction == nil then
        self.volume_requests[instance] = nil
    else
        log_typecheck_arg_i(dtheta, Number_t, 3)
        local current = self.volume_requests[instance]
        if current ~= nil then
            current.volume = fraction
        else
            self.volume_requests[instance] = {
                volume = fraction
            }
        end
    end

    return self
end

player_clear_linear_velocity_requests = function(self)
    log_typecheck(self, Player_t)

    table_clear(self.linear_velocity_requests)
    return self
end

player_clear_angular_velocity_requests = function(self)
    log_typecheck(self, Player_t)

    table_clear(self.angular_velocity_requests)
    return self
end

player_clear_volume_requests = function(self)
    log_typecheck(self, Player_t)

    table_clear(self.volume_requests)
    return self
end

player_set_collision_contours = function(self, contours)
    log_typecheck(self, Player_t, contours, Table_t)
    softbody_set_collision_contours(self.body, contours)

    return self
end

player_set_is_clickable = function(self, b)
    if b == nil then b = true end
    log_typecheck(self, Player_t, b, Boolean_t)
    self.is_clickable = b
end

player_get_is_clickable = function(self)
    log_typecheck(self, Player_t)
    return self.is_clickable
end

player_set_is_active = function(self, b)
    if b == nil then b = true end
    log_typecheck(self, Player_t, b, Boolean_t)
    self.is_active = b
end

player_get_is_active = function(self)
    log_typecheck(self, Player_t)
    return self.is_active
end

player_draw = function(self)
    log_typecheck(self, Player_t)

    local outline = softbody_get_draw_contour(self.body)

    if self.is_active then
        graphics_set_color(palette_get_current_color())
    else
        graphics_set_color(palette_white)
    end
    graphics_draw_mesh(softbody_get_draw_mesh(self.body))

    rgba_bind(palette_black)
    graphics_set_line_state(_settings_outline_width + 2)
    polyline_draw(outline)

    if self.is_clickable or self.is_active then
        graphics_set_color(palette_get_current_color())
    else
        graphics_set_color(palette_white)
    end
    graphics_set_line_state(_settings_outline_width)
    polyline_draw(outline)

    return self
end

player_get_player_collision_contour = function(self)
    log_typecheck(self, Player_t)

    return softbody_get_contour(self.body)
end


