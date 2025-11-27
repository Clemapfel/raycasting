require "common.stable_sort"
require "common.path"

rt.settings.overworld.air_dash_node_handler = {
    node_collision_group = b2.CollisionGroup.GROUP_09,
    dash_velocity = 1000 -- on exit
}

--- @class ow.AirDashNodeHandler
ow.AirDashNodeHandler = meta.class("AirDashNodeHandler")

--- @brief
function ow.AirDashNodeHandler:instantiate(scene, stage)
    self._scene = scene
    self._stage = stage
    self._node_to_entry = meta.make_weak({})
    self._max_node_radius = 0

    self._next_node = nil -- if player initiates tether, this is the target
    self._tethered_node = nil -- bound node

    self._tether_path = nil -- rt.Path
    self._tether_dx, self._tether_dy = 0, 0 -- direction
    self._tether_exit_line = {} -- Array<Number, 4>
    self._tether_exit_sign = 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP then
            if self._tethered_node ~= nil
                and self._next_node ~= nil
                and self._next_node ~= self._tethered_node
            then
                -- if already tethered, swap to new node
                self:_tether(self._next_node)
            elseif self._tethered_node == nil
                and self._next_node ~= nil
            then
                -- if not tethered, tether
                self:_tether(self._next_node)
            end
        end
    end)
end

function _get_side(px, py, line)
    local x1, y1, x2, y2 = table.unpack(line)

    local dx = x2 - x1
    local dy = y2 - y1

    local dpx = px - x1
    local dpy = py - y1

    return math.sign(math.cross(dx, dy, dpx, dpy))
end

--- @brief
function ow.AirDashNodeHandler:_tether(node)
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
end

--- @brief
function ow.AirDashNodeHandler:_untether()
    if self._tethered_node == nil then return end
    self._tethered_node:set_is_tethered(false)
    self._tethered_node = nil
end

function _temp()
    local duration = rt.settings.overworld.air_dash_node.dash_duration
    local target_velocity = rt.settings.overworld.air_dash_node.dash_velocity

    local ax, ay = self._tether_path:at(0)
    local bx, by = self._tether_path:at(1)
    local t = rt.InterpolationFunctions.SINUSOID_EASE_IN(
        math.mix(0.5, 1, (1 - math.distance(px, py, self._x, self._y) / math.distance(ax, ay, bx, by)))
    )

    local tangent_x, tangent_y = self._tether_path:get_tangent(t)

    local target_vx = t * target_velocity * -tangent_x
    local target_vy = t * target_velocity * -tangent_y

    player:set_velocity(target_vx, target_vy)
    self._tether_elapsed = self._tether_elapsed + delta

    if _get_side(px, py, table.unpack(self._tether_sign_line)) ~= self._tether_sign
        or (t > 0.5 and #(player:get_colliding_bodies()) ~= 0) -- if past mid point, skip if hitting obstacle
    then
        player:set_velocity(target_vx, target_vy) -- exit velocity always consistent
        self:_untether()
    end
end

--- @brief
function ow.AirDashNodeHandler:notify_node_added(node)
    local x, y = node:get_position()
    local radius = node:get_radius()

    local entry = {
        cooldown_elapsed = math.huge,
        x = x,
        y = y,
        radius = radius
    }

    self._node_to_entry = entry

    -- prepare body for aabb query
    local body = node:get_body()
    body:set_user_data(node)
    body:set_collision_group(rt.settings.overworld.air_dash_node_handler.node_collision_group)

    self._max_node_radius = math.max(self._max_node_radius, radius)
end

--- @brief
function ow.AirDashNodeHandler:update(delta)
    local bounds = self._scene:get_camera():get_world_bounds()
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local pvx, pvy = player:get_velocity()
    local pr = player:get_radius()

    if self._tethered_node ~= nil then
        -- move player
        local target_velocity = rt.settings.overworld.air_dash_node_handler.dash_velocity
        local ax, ay = self._tether_path:at(0)
        local bx, by = self._tether_path:at(1)
        local t = rt.InterpolationFunctions.SINUSOID_EASE_IN(
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

    local padding = self._max_node_radius
    bounds.x = bounds.x - padding
    bounds.y = bounds.y - padding
    bounds.width = bounds.width + 2 * padding
    bounds.height = bounds.height + 2 * padding

    local bodies = self._stage:get_physics_world():query_aabb(
        bounds.x, bounds.y, bounds.width, bounds.height,
        rt.settings.overworld.air_dash_node_handler.node_collision_group
    )

    local entries = {}
    for body in values(bodies) do
        local node = body:get_user_data()
        if not node:get_is_on_cooldown() then
            local node_x, node_y = node:get_position()
            local dx, dy = math.normalize(px - node_x, py - node_y)
            table.insert(entries, {
                node = node,
                distance = math.distance(px, py, node_x, node_y),
                dx = dx,
                dy = dy,
                alignment = math.dot(dx, dy, pvx, pvy)
            })
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

    if self._next_node ~= nil then
        self._next_node:set_is_current(false)
    end

    if best_entry == nil then
        self._next_node = nil
    else
        self._next_node = best_entry.node
        self._next_node:set_is_current(true)
    end
end