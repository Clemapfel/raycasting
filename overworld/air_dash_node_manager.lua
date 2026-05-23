require "common.stable_sort"
require "common.path"

rt.settings.overworld.air_dash_node_manager = {
    node_collision_group = b2.CollisionGroup.GROUP_09,
    dash_velocity = 850,
    exit_velocity = 700,

    dash_velocity_bubble = 500,
    exit_velocity_bubble = 350,

    stuck_detection_radius = rt.settings.player.radius / 8, -- px
    stuck_detection_duration = 30 / 60, -- seconds

    jump_buffer_duration = 5 / 60, -- before
}

--- @class ow.AirDashNodeManager
ow.AirDashNodeManager = meta.class("AirDashNodeManager")

local function _get_side(px, py, line)
    local x1, y1, x2, y2 = table.unpack(line)

    local dx = x2 - x1
    local dy = y2 - y1

    local dpx = px - x1
    local dpy = py - y1

    return math.sign(math.cross(dx, dy, dpx, dpy))
end

--- @brief
function ow.AirDashNodeManager:instantiate(scene, stage)
    self._scene = scene
    self._stage = stage
    self._max_node_radius = 0

    self._next_node = nil -- if player initiates tether and is in range, this is the target
    self._recommended_node = nil -- this is the next recommended next_node
    self._tethered_node = nil -- bound node, player actively dashing

    self._tether_path = rt.Path(0, 0, 0, 0)
    self._tether_exit_sign_line = { 0, 0, 0, 0 } -- Array<Number, 4>
    self._tether_exit_sign = 0

    self._tether_mid_sign_line = { 0, 0, 0, 0 }
    self._tether_mid_sign = 0

    self._tether_elapsed = math.huge
    self._t_history = {}

    self._tether_velocity_magnitude = 0
    self._node_to_cooldown_timestamp = meta.make_weak({})

    self._tether_allowed_timestamp = nil
    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP then
            self._tether_allowed_timestamp = love.timer.getTime()

            local px, py = self._scene:get_player():get_position()
            local pr = 2 * self._scene:get_player():get_radius()

            if self._tethered_node ~= nil then
                dbg("tether", meta.hash(self._tethered_node), self._tethered_node:check_player_overlap(px, py, pr))
            else
                dbg("tether")
            end

            if self._next_node ~= nil then
                dbg("next", meta.hash(self._next_node), self._next_node:check_player_overlap(px, py, pr))
            else
                dbg("next")
            end

            if self._recommended_node ~= nil then
                dbg("recommended", meta.hash(self._recommended_node), self._recommended_node:check_player_overlap(px, py, pr))
            else
                dbg("recommended")
            end

            dbg("\n")
        end
    end)

    self._input:signal_connect("released", function(_, which)
        if which == rt.InputAction.JUMP then
            self._tether_allowed_timestamp = nil
        end
    end)
end

--- @brief
function ow.AirDashNodeManager:_tether(node)
    if self._tethered_node ~= nil then
        self._tethered_node:set_is_tethered(false)
    end

    if node == nil then return end

    self._tethered_node = node

    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()
    local player_vx, player_vy = player:get_velocity()
    local node_x, node_y = node:get_position()

    local dx, dy, _ = node:get_direction()

    local radius = node:get_radius()
    local end_x, end_y = node_x + dx * radius, node_y + dy * radius

    local left_x, left_y = math.turn_left(dx, dy)
    local right_x, right_y = math.turn_right(dx, dy)

    self._tether_exit_sign_line = {
        end_x + left_x,
        end_y + left_y,
        end_x + right_x,
        end_y + right_y
    }

    self._tether_exit_sign = _get_side(
        player_x, player_y,
        self._tether_exit_sign_line
    )

    self._tether_mid_sign_line = {
        node_x + left_x,
        node_y + left_y,
        node_x + right_x,
        node_y + right_y
    }

    self._tether_mid_sign = _get_side(
        player_x, player_y,
        self._tether_mid_sign_line
    )

    self._tether_exit_dx, self._tether_exit_dy = dx, dy
    self._tether_path = rt.Path(rt.Spline(
        player_x, player_y,
        node_x, node_y,
        end_x, end_y
    ):discretize())

    self._tether_elapsed = 0
    self._tethered_node:set_is_tethered(true)

    local velocity_magnitude = math.magnitude(player:get_velocity())
    self._tether_velocity_magnitude = math.max(
        velocity_magnitude,
        ternary(player:get_is_bubble(),
            rt.settings.overworld.air_dash_node_manager.dash_velocity_bubble,
            rt.settings.overworld.air_dash_node_manager.dash_velocity
        ) * node:get_velocity_factor()
    )

    player:set_velocity(0, 0) -- overridden next update
    player:pulse(node:get_color())
    self._scene:get_camera():shake()

    self._t_history = {}
end

--- @brief
function ow.AirDashNodeManager:notify_node_added(node)
    -- prepare body for aabb query
    local body = node:get_body()
    body:set_user_data(node)
    body:set_collision_group(rt.settings.overworld.air_dash_node_manager.node_collision_group)

    self._max_node_radius = math.max(self._max_node_radius, node:get_radius())
end

--- @brief
function ow.AirDashNodeManager:update(delta)
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local pvx, pvy = player:get_velocity()
    local pr = 2 * player:get_radius() -- sic

    local get_is_on_cooldown = function(node)
        return self._node_to_cooldown_timestamp[node] ~= nil
    end

    if self._tethered_node ~= nil then
        -- move player

        local t = self._tether_path:get_fraction(px, py)
        local dx, dy = self._tether_path:tangent_at(t)

        player:set_velocity(
            self._tether_velocity_magnitude * dx,
            self._tether_velocity_magnitude * dy
        )

        local should_emergency_untether = false
        do -- detect if player is stuck
            self._tether_elapsed = self._tether_elapsed + delta

            table.insert(self._t_history, 1, {
                t = t,
                elapsed = self._tether_elapsed
            })

            local t_radius = rt.settings.overworld.air_dash_node_manager.stuck_detection_radius / self._tether_path:get_length()
            local duration = rt.settings.overworld.air_dash_node_manager.stuck_detection_duration
            local t_velocity_cutoff = t_radius / duration

            local total_elapsed = 0
            local now_t, last_t = t, math.huge

            -- compute t velocity in last `duration` time window
            for i = 1, #self._t_history - 1 do
                local current = self._t_history[i + 0]
                local previous = self._t_history[i + 1]
                local elapsed = current.elapsed - previous.elapsed
                total_elapsed = total_elapsed + elapsed

                if total_elapsed > duration then
                    last_t = previous.t
                    break
                end
            end

            -- if t-velocity is too low, player appears stuck, untether
            if total_elapsed > duration then
                should_emergency_untether = math.abs(last_t - now_t) / total_elapsed < t_velocity_cutoff
            end
        end

        -- exit condition: moved past end line
        local side = _get_side(px, py, self._tether_exit_sign_line)
        if should_emergency_untether or side ~= self._tether_exit_sign then
            local exit_velocity = ternary(not player:get_is_bubble(),
                rt.settings.overworld.air_dash_node_manager.exit_velocity,
                rt.settings.overworld.air_dash_node_manager.exit_velocity_bubble
            ) * self._tethered_node:get_velocity_factor()

            player:set_velocity( -- ensure exit velocity
                exit_velocity * self._tether_exit_dx,
                exit_velocity * self._tether_exit_dy
            )

            -- untether
            self._tethered_node:set_is_tethered(false)
            self._tethered_node = nil
            self._tether_elapsed = math.huge
            dbg("called")
        end

        -- particles
        if self._tethered_node ~= nil then
            self._tethered_node:emit_particles()
        end
    end

    -- find next candidate

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    local padding = rt.settings.overworld.stage.visible_area_padding * camera:get_final_scale()
        + self._max_node_radius

    bounds.x = bounds.x - padding
    bounds.y = bounds.y - padding
    bounds.width = bounds.width + 2 * padding
    bounds.height = bounds.height + 2 * padding

    local bodies = self._stage:get_physics_world():query_aabb(
        bounds.x, bounds.y, bounds.width, bounds.height,
        rt.settings.overworld.air_dash_node_manager.node_collision_group
    )

    local disable_double_jump = false -- in range of at least one node

    local entries = {}
    for body in values(bodies) do
        local node = body:get_user_data()
        local on_cooldown = get_is_on_cooldown(node)
        if not on_cooldown then
            local node_x, node_y = node:get_position()
            local dx, dy = math.normalize(px - node_x, py - node_y)
            local distance = math.distance(px, py, node_x, node_y)
            local alignment = math.dot(dx, dy, pvx, pvy)
            table.insert(entries, {
                node = node,
                distance = distance,
                dx = dx,
                dy = dy,
                alignment = alignment
            })

            if distance < node:get_radius() + 2 * player:get_radius() then
                disable_double_jump = true
            end
        end
    end

    -- if mid air, prefer node towards direction player is traveling
    local is_player_midair = player:get_is_grounded() == false and (#player:get_colliding_bodies() == 0)
    if is_player_midair then
        table.stable_sort(entries, function(a, b) return a.alignment < b.alignment end)
    end

    table.stable_sort(entries, function(a, b) return a.distance < b.distance end)

    -- find best active entry
    local best_entry = nil
    for _, entry in ipairs(entries) do
        if entry.distance < entry.node:get_radius() + 2 * pr
            and not get_is_on_cooldown(entry.node)
        then
            best_entry = entry
            break
        end
    end

    if self._recommended_node ~= nil then
        self._recommended_node:set_is_outline_visible(false)
    end

    if self._next_node ~= nil then
        self._next_node:set_is_current(false)
    end

    if best_entry == nil then
        -- no candidate, highlight closest
        self._next_node = nil

        if #entries > 0 then
            self._recommended_node = entries[1].node
        else
            self._recommended_node = nil
        end
    else
        local before = self._next_node
        self._next_node = best_entry.node
        self._next_node:set_is_current(true)
        self._recommended_node = self._next_node
    end

    -- regular tether
    if self._tethered_node == nil
        and self._next_node ~= nil
        and self._tether_allowed_timestamp ~= nil
        and (love.timer.getTime() - self._tether_allowed_timestamp) < rt.settings.overworld.air_dash_node_manager.jump_buffer_duration
        and self._next_node ~= self._tethered_node
        and self._next_node:check_player_overlap(px, py, 2 * pr)
    then
        self:_tether(self._next_node)
        self._tether_allowed_timestamp = nil -- consume
    end

    if self._recommended_node ~= nil then
        self._recommended_node:set_is_outline_visible(true)
    end

    -- disable double jump while in range
    player:request_is_double_jump_disabled(self, disable_double_jump)
end

--- @brief
function ow.AirDashNodeManager:draw()
    if self._tethered_node == nil then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)

    if self._tether_exit_sign_line ~= nil and self._tethered_node ~= nil then
        love.graphics.line(self._tether_exit_sign_line)
    end
end