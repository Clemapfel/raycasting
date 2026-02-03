require "common.path"
require "common.spline"
require "overworld.normal_map"
require "overworld.mirror"
require "overworld.movable_object"
require "overworld.path_rail"

rt.settings.overworld.path = {
    draw_line_width = 3,
    segment_length = 5,

    -- needed for stage config
    class_id = "Path",
    is_target_property_pattern = function(str)
        local pattern1 = "^target$"
        local pattern2 = "^target_%d+$"
        return string.match(str, pattern1) or string.match(str, pattern2)
    end
}

--- @class ow.Path
--- @types Polygon, Rectangle
--- @field velocity Number?
--- @field next ow.PathNode! pointer to path
--- @field cycle_offset Number? in [0, 1]
--- @field target Any object with set_velocity and set_position
--- @field target_x Any additional targets, where x is 0-9
ow.Path = meta.class("OverworldPath")

--- @class ow.PathNode
--- @types Point
--- @field target ow.PathNode!
ow.PathNode = meta.class("OverworldPathNode")

--- @brief
function ow.Path:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Path: object `" .. object:get_id() .. "` is not a point")
    self._scene = scene
    self._stage = stage
    self._color = rt.RGBA(1, 1, 1, 1)

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then
            self:reset()
        end
    end)

    self._elapsed = 0
    self._n_cycles = 0

    self._max_n_cycles = object:get_number("n_cycles", false) or math.huge
    self._should_loop = object:get_boolean("should_loop", false)
    if self._should_loop == nil then self._should_loop = false end

    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end

    self._is_smooth = object:get_boolean("is_smooth", false)
    if self._is_smooth == nil then self._is_smooth = false end

    self._cycle_offset = object:get_number("cycle_offset", false) or 0

    self._is_absolute = object:get_boolean("is_absolute", false)
    if self._is_absolute == nil then self._is_absolute = false end

    self._is_absolute = object:get_boolean("is_absolute", false)
    if self._is_absolute == nil then self._is_absolute = false end

    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = false end

    self._stage:signal_connect("respawn", function()
        self:reset()
    end)

    local targets = {}

    -- get additional targets
    for property_name in values(object:get_property_names()) do
        if rt.settings.overworld.path.is_target_property_pattern(property_name) then
            local target = object:get_object(property_name, false)
            if target ~= nil then
                table.insert(targets, target)
            end
        end
    end

    self._entries = {}
    self._last_t = 0

    self._stage:signal_connect("initialized", function(_)
        for target in values(targets) do
            local instance = self._stage:object_wrapper_to_instance(target)
            if not meta.isa(instance, ow.MovableObject) or meta.isa(instance, ow.Hitbox) then
                rt.error("In ow.Path: instance type `" .. meta.typeof(instance) .. "` of object `" .. target:get_id() .. "` does not inherit from `ow.MovableObject`")
            end

            local start_x, start_y = instance:get_position()
            local entry = {
                target = instance,
                offset_x = start_x,  -- will be transformed to offset below
                offset_y = start_y,
            }

            table.insert(self._entries, entry)
        end

        -- read path by iterating through nodes
        local node = object
        local path = {}
        repeat
            assert(node:get_type() == ow.ObjectType.POINT, "In ow.Path: `PathNode` (" .. object:get_id() .. ") is not a point")

            -- move path to align with center of mass
            table.insert(path, node.x)
            table.insert(path, node.y)
            node = node:get_object("next", false)
        until node == nil

        if self._should_loop then
            table.insert(path, path[1])
            table.insert(path, path[2])
        end

        if self._is_absolute then
            for entry in values(self._entries) do
                entry.offset_x = 0
                entry.offset_y = 0
            end
        else
            for entry in values(self._entries) do
                entry.offset_x = entry.offset_x - path[1]
                entry.offset_y = entry.offset_y - path[2]
            end
        end

        if self._is_smooth then
            local spline = rt.Spline(path)
            local length = spline:get_length()
            local segment_length = rt.settings.overworld.path.segment_length
            local n_segments = math.ceil(length / segment_length)

            local spline_path = {}
            for i = 1, n_segments do
                local t = (i - 1) / n_segments
                local x, y = spline:at(t)
                table.insert(spline_path, x)
                table.insert(spline_path, y)
            end

            self._path = rt.Path(spline_path)
        else
            self._path = rt.Path(path)
        end

        if self._is_visible then
            self._camera_body = b2.Body(
                self._stage:get_physics_world(),
                b2.BodyType.STATIC,
                0, 0,
                b2.Segment(path)
            )
            self._camera_body:set_collides_with(0x0)
            self._camera_body:set_collision_group(0x0)

            if self._is_visible then
                self._rail = ow.PathRail(self._path)
                self._rail_attachment_x, self._rail_attachment_y = self._path:at(0)
            end
        end

        self:reset() -- apply cycle offset
    end)

    local centroid_x, centroid_y = object:get_centroid()
    self._velocity = rt.settings.overworld.moving_hitbox.default_velocity
    self._velocity_factor = object:get_number("velocity", false) or 1
    self._velocity = self._velocity * self._velocity_factor

    local easing = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
    local easing_name = object:get_string("easing", false)
    if easing_name ~= nil then
        easing = rt.InterpolationFunctions[easing_name]
        if easing == nil then
            rt.error("In ow.Path: for object `",  object:get_id(),  "`: unknown easing `",  easing_name,  "`")
        end
    end
    self._easing = easing
end

function ow.Path:update(delta)
    if self._stage:get_active_checkpoint():get_is_respawning() then
        return -- waiting for respawn to be finished
    end

    self._elapsed = self._elapsed + delta

    if self._n_cycles >= self._max_n_cycles then return end

    local length = self._path:get_length()
    local t, direction

    if self._should_loop then
        local distance = self._velocity * self._elapsed
        -- Apply cycle_offset to the t calculation
        t = ((distance / length) + self._cycle_offset) % 1.0
        direction = 1
    else
        local distance_in_cycle = (self._velocity * self._elapsed) % (2 * length)
        -- Apply cycle_offset by adjusting the distance within the cycle
        local offset_distance = self._cycle_offset * 2 * length
        distance_in_cycle = (distance_in_cycle + offset_distance) % (2 * length)

        if distance_in_cycle <= length then
            -- going forwards
            t = distance_in_cycle / length
            direction = 1
        else
            -- going backwards
            local backward_distance = distance_in_cycle - length
            t = (length - backward_distance) / length
            direction = -1
        end
    end

    local dt = rt.SceneManager:get_timestep()

    -- find target position
    local eased_t = math.clamp(self._easing(t), 0, 1)

    local current_x, current_y = self._path:at(eased_t)

    for entry in values(self._entries) do
        -- set velocity based on last frames position
        if self._last_x ~= nil and self._last_y ~= nil then
            local velocity_x = (current_x - self._last_x) / delta
            local velocity_y = (current_y - self._last_y) / delta
            entry.target:set_velocity(velocity_x, velocity_y)
        else
            local easing_t_dt = self._easing(math.clamp(t + dt, 0, 1))
            local easing_derivative = (easing_t_dt - eased_t) / dt

            local dx, dy = self._path:tangent_at(math.clamp(eased_t, 0, 1))
            local velocity_x = dx * self._velocity * direction * easing_derivative
            local velocity_y = dy * self._velocity * direction * easing_derivative
            entry.target:set_velocity(velocity_x, velocity_y)
        end

        if math.distance(current_x, current_y, entry.target:get_position()) > 1 then
            entry.target:set_position(current_x + entry.offset_x, current_y + entry.offset_y)
        end
    end

    self._last_x = current_x
    self._last_y = current_y

    -- when object completes loop, snap to start to avoid numerical drift
    local difference = math.abs(self._last_t - t)
    if difference > 0.5 then
        local x, y = self._path:at(0)
        for entry in values(self._entries) do
            entry.target:set_position(
                x + entry.offset_x,
                y + entry.offset_y
            )
        end
    end

    self._last_t = t

    if self._last_direction ~= nil and self._last_direction ~= direction then
        self._n_cycles = self._n_cycles + 1
        if self._n_cycles >= self._max_n_cycles then
            local x, y = self._path:at(ternary(direction == 1, 0, 1))
            for entry in values(self._entries) do
                entry.target:set_position(
                    x + entry.offset_x,
                    y + entry.offset_y
                )
            end
        end
    end
    self._last_direction = direction
end

local _back_priority = -math.huge
local _front_priority = math.huge

--- @brief
function ow.Path:draw(priority)
    if not self._is_visible or not self._stage:get_is_body_visible(self._camera_body) then return end

    if priority == _back_priority then
        self._rail:draw_rail()
    elseif priority == _front_priority then
        for entry in values(self._entries) do
            local x, y = entry.target:get_position()
            x = x - entry.offset_x
            y = y - entry.offset_y
            self._rail:draw_attachment(x, y)
        end
    end
end

--- @brief
function ow.Path:draw_bloom()
    if not self._is_visible or not self._stage:get_is_body_visible(self._camera_body) then return end
end

--- @brief
function ow.Path:get_render_priority()
    if not self._is_visible then
        return nil
    else
        return _back_priority, _front_priority
    end
end

--- @brief
function ow.Path:reset()
    self._elapsed = 0
    self._n_cycles = 0
    self._last_direction = nil

    -- Calculate initial position based on cycle_offset
    local length = self._path:get_length()
    local t

    if self._should_loop then
        -- For looping paths, offset directly maps to t
        t = self._cycle_offset % 1.0
    else
        -- For ping-pong paths, offset within a full cycle (forward + backward)
        local offset_in_cycle = (self._cycle_offset * 2) % 2.0
        if offset_in_cycle <= 1.0 then
            t = offset_in_cycle
        else
            t = 2.0 - offset_in_cycle
        end
    end

    local eased_t = math.clamp(self._easing(t), 0, 1)
    local x, y = self._path:at(eased_t)
    self._last_x, self._last_y = x, y

    for entry in values(self._entries) do
        entry.target:set_position(
            x + entry.offset_x,
            y + entry.offset_y
        )

        local dx, dy = self._path:tangent_at(eased_t)
        entry.target:set_velocity(dx * self._velocity, dy * self._velocity)
    end
end