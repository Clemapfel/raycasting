require "common.stable_sort"
require "common.path"

rt.settings.overworld.air_dash_node_manager = {
    node_collision_group = b2.CollisionGroup.GROUP_09,
    dash_velocity = 1000, -- on exit
    dash_velocity_bubble = 500
}

--- @class ow.AirDashNodeManager
ow.AirDashNodeManager = meta.class("AirDashNodeManager")

--- @brief
function ow.AirDashNodeManager:instantiate(scene, stage)
    self._scene = scene
    self._stage = stage
    self._node_to_entry = meta.make_weak({})
    self._max_node_radius = 0

    self._next_node = nil -- if player initiates tether and is in range, this is the target
    self._recommended_node = nil -- this is the next recommended next_node
    self._tethered_node = nil -- bound node, player actively dashing

    self._tether_path = nil -- rt.Path
    self._tether_dx, self._tether_dy = 0, 0 -- direction
    self._tether_exit_line = {} -- Array<Number, 4>
    self._tether_exit_sign = 0

    self._input = rt.InputSubscriber(rt.settings.player.input_subscriber_priority + 1)
    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP and self._next_node ~= nil then
            if self._tethered_node ~= self._next_node then
                self:_tether(self._next_node)
            end
        end
    end)
end

local function _get_side(px, py, line)
    local x1, y1, x2, y2 = table.unpack(line)

    local dx = x2 - x1
    local dy = y2 - y1

    local dpx = px - x1
    local dpy = py - y1

    return math.sign(math.cross(dx, dy, dpx, dpy))
end

--- @brief
function ow.AirDashNodeManager:_update_damping(value)
    local player = self._scene:get_player()
    self._damping_entry_id = player:request_damping(self,
        nil, -- up
        nil, -- right
        value, -- down
        nil -- left
    )
end

--- @brief
function ow.AirDashNodeManager:_tether(node)
    if self._tethered_node ~= nil then
        self._tethered_node:set_is_tethered(false)
    end

    if node == nil then return end

    self._tethered_node = node
    self._tethered_node:set_is_tethered(true)

    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()
    local node_x, node_y = node:get_position()

    self._tether_path = rt.Path(
        player_x, player_y,
        node_x, node_y
    )

    self._tether_dx, self._tether_dy = math.normalize(
        node_x - player_x,
        node_y - player_y
    )

    local left_x, left_y = math.turn_left(self._tether_dx, self._tether_dy)
    local right_x, right_y = math.turn_right(self._tether_dx, self._tether_dy)

    local length = 50 -- irrelevant for math as points define infinite line
    self._tether_sign_line = {
        node_x + left_x * length,
        node_y + left_y * length,
        node_x + right_x * length,
        node_y + right_y * length
    }

    self._tether_sign = _get_side(
        player_x, player_y,
        self._tether_sign_line
    )

    player:pulse(node:get_color())
    self._scene:get_camera():shake()
end

--- @brief
function ow.AirDashNodeManager:_untether()
    if self._tethered_node == nil then return end
    self._tethered_node:set_is_tethered(false)
    self._tethered_node = nil
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
    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    local padding = rt.settings.overworld.stage.visible_area_padding * camera:get_final_scale()
    bounds.x = bounds.x - padding
    bounds.y = bounds.y - padding
    bounds.width = bounds.width + 2 * padding
    bounds.height = bounds.height + 2 * padding

    local player = self._scene:get_player()
    local px, py = player:get_position()
    local pvx, pvy = player:get_velocity()
    local pr = player:get_radius()

    local non_bubble_easing = rt.InterpolationFunctions.SINUSOID_EASE_IN
    local bubble_easing = rt.InterpolationFunctions.CONSTANT

    if self._tethered_node ~= nil then
        -- move player
        self:_update_damping(1) -- to prevent downwards dash being dampened

        local target_velocity = ternary(not player:get_is_bubble(),
            rt.settings.overworld.air_dash_node_manager.dash_velocity,
            rt.settings.overworld.air_dash_node_manager.dash_velocity_bubble
        )

        local ax, ay = self._tether_path:at(0)
        local bx, by = self._tether_path:at(1)

        local easing = ternary(not player:get_is_bubble(), non_bubble_easing, bubble_easing)
        local t = easing(
            math.mix(0.5, 1, (1 - math.distance(px, py, bx, by) / math.distance(ax, ay, bx, by)))
        )


        player:set_velocity(
            t * target_velocity * self._tether_dx,
            t * target_velocity * self._tether_dy
        )

        -- exit condition: moved past midline
        local side = _get_side(px, py, self._tether_sign_line)
        if side ~= self._tether_sign then
            player:set_velocity( -- ensure exit velocity
                target_velocity * self._tether_dx,
                target_velocity * self._tether_dy
            )
            self:_untether()
        end
    end

    -- find next candidate

    if player:get_is_ghost() then goto skip end

    local padding = self._max_node_radius
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
        local on_cooldown = node:get_is_on_cooldown()
        if not on_cooldown then
            local node_x, node_y = node:get_position()
            local dx, dy = math.normalize(px - node_x, py - node_y)
            local distance =  math.distance(px, py, node_x, node_y)
            table.insert(entries, {
                node = node,
                distance = distance,
                dx = dx,
                dy = dy,
                alignment = math.dot(dx, dy, pvx, pvy)
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
        if entry.distance < entry.node:get_radius() + pr then
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
        if self._next_node ~= nil then
            self:_update_damping(1)
        end

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

        if not player:get_is_grounded() then
            self:_update_damping(
                math.mix(0.94, 0.98, (math.distance(px, py, self._next_node:get_position()) / self._next_node:get_radius()))
            )
        else
            self:_update_damping(1)
        end
    end

    if self._recommended_node ~= nil then
        self._recommended_node:set_is_outline_visible(true)
    end

    -- disable double jump while in range
    player:request_is_jump_disabled(self, disable_double_jump)

    ::skip::
end