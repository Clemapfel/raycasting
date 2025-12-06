require "common.path"
require "common.spline"
require "overworld.normal_map"
require "overworld.mirror"
require "overworld.objects.moving_hitbox_path"
require "overworld.movable_object"

rt.settings.overworld.objects.path = {
    draw_line_width = 3,
    segment_length = 5
}

--- @class ow.Path
--- @types Polygon, Rectangle
--- @field velocity Number?
--- @field next ow.PathNode! pointer to path
--- @field target Any object with set_velocity and set_position
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

    self._elapsed = 0

    self._should_loop = object:get_boolean("should_loop", false)
    if self._should_loop == nil then self._should_loop = false end

    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end

    self._is_smooth = object:get_boolean("is_smooth", false)
    if self._is_smooth == nil then self._is_smooth = false end

    if self._is_visible then
        self._color = rt.RGBA(1, 1, 1, 1)
    end

    -- read target
    self._target = nil
    self._start_x, self._start_y = nil, nil
    self._path = nil -- rt.Path
    self._last_t = 0

    local target = object:get_object("target", true)
    self._stage:signal_connect("initialized", function(_)
        local instance = self._stage:object_wrapper_to_instance(target)
        if not meta.isa(instance, ow.MovableObject) then
            rt.error("In ow.Path: instance type `" .. meta.typeof(instance) .. "` of object `" .. target:get_id() .. "` does not inherit from `ow.MovableObject`")
        end

        self._target = instance
        self._start_x, self._start_y = self._target:get_position()

        -- read path by iterating through nodes
        local node = object
        local path = {}
        local path_offset_x, path_offset_y
        repeat
            assert(node:get_type() == ow.ObjectType.POINT, "In ow.Path: `PathNode` (" .. object:get_id() .. ") is not a point")
            if path_offset_x == nil and path_offset_y == nil then
                path_offset_x = self._start_x - node.x
                path_offset_y = self._start_y - node.y
            end

            -- move path to align with center of mass
            table.insert(path, node.x + path_offset_x)
            table.insert(path, node.y + path_offset_y)
            node = node:get_object("next", false)
        until node == nil

        if self._should_loop then
            table.insert(path, path[1])
            table.insert(path, path[2])
        end

            if self._is_smooth then
                local spline = rt.Spline(path)
                local length = spline:get_length()
                local segment_length = rt.settings.overworld.objects.path.segment_length
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
            end
        end)

    local centroid_x, centroid_y = object:get_centroid()
    self._velocity = object:get_number("velocity", false) or rt.settings.overworld.moving_hitbox.default_velocity

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
    self._elapsed = self._elapsed + delta
    local length = self._path:get_length()
    local t, direction

    if self._should_loop then
        local distance = self._velocity * self._elapsed
        t = (distance / length) % 1.0
        direction = 1
    else
        local distance_in_cycle = (self._velocity * self._elapsed) % (2 * length)
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
    local eased_t = self._easing(t)
    local current_x, current_y = self._path:at(math.clamp(eased_t, 0, 1))

    -- set velocity based on last frames position
    if self._last_x ~= nil and self._last_y ~= nil then
        local velocity_x = (current_x - self._last_x) / delta
        local velocity_y = (current_y - self._last_y) / delta
        self._target:set_velocity(velocity_x, velocity_y)
    else
        local easing_t_dt = self._easing(math.clamp(t + dt, 0, 1))
        local easing_derivative = (easing_t_dt - eased_t) / dt

        local dx, dy = self._path:get_tangent(math.clamp(eased_t, 0, 1))
        local velocity_x = dx * self._velocity * direction * easing_derivative
        local velocity_y = dy * self._velocity * direction * easing_derivative
        self._target:set_velocity(velocity_x, velocity_y)
    end

    self._last_x = current_x
    self._last_y = current_y

    -- when object completes loop, snap to start to avoid numerical drift
    local difference = math.abs(self._last_t - t)
    if difference > 0.5 then
        self._target:set_position(self._path:at(0))
    end

    self._last_t = t
end

local _back_priority = -math.huge
local _front_priority = math.huge

--- @brief
function ow.Path:draw(priority)
    if not self._is_visible or not self._stage:get_is_body_visible(self._camera_body) then return end

end

--- @brief
function ow.Path:draw_bloom()
    if not self._is_visible or not self._stage:get_is_body_visible(self._camera_body) then return end

    self._color:bind()
    love.graphics.setLineWidth(rt.settings.overworld.objects.path.draw_line_width)
    love.graphics.line(self._path:get_points())
end

--- @brief
function ow.Path:get_render_priority()
    if not self._is_visible then
        return nil
    else
        return -math.huge
    end
end

--- @brief
function ow.Path:reset()
    self._elapsed = 0
    self._target:set_position(self._start_x, self._start_y)
end

