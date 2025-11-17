require "common.path"
require "common.contour"
require "overworld.normal_map"
require "overworld.mirror"
require "overworld.objects.moving_hitbox_path"

rt.settings.overworld.moving_hitbox = {
    default_velocity = 100, -- px per second
}

--- @class ow.MovingHitbox
--- @types Polygon, Rectangle
--- @field velocity Number?
--- @field target ow.MovingHitboxTarget! pointer to path
ow.MovingHitbox = meta.class("MovingHitbox")

--- @class ow.MovingHitboxTarget
--- @types Point
--- @field target ow.MovingHitboxTarget!
ow.MovingHitboxTarget = meta.class("MovingHitboxTarget")

--- @brief
function ow.MovingHitbox:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.KINEMATIC)
    self._body:set_collision_group(bit.bor(
        rt.settings.overworld.hitbox.collision_group
    ))

    self._body:set_use_continuous_collision(true)

    self._elapsed = 0
    self._is_active = false
    self._body:signal_connect("collision_start", function(_, other_body)
        if not other_body:has_tag("player") then return end
        self._is_active = true
    end)

    self._body:signal_connect("collision_end", function(_, other_body)
        if not other_body:has_tag("player") then return end
        self._is_active = true
    end)

    -- match tags from ow.Hitbox
    for property in range(
        "slippery",
        "sticky"
    ) do
        if object:get_boolean(property) then
            self._body:add_tag(property)
        end
    end

    if self._body:has_tag("slippery") then
        self._body:add_tag("no_blood")
    end
    self._body:add_tag("moving", "hitbox", "stencil")

    local start_x, start_y = self._body:get_position()

    -- read path by iterating through nodes
    local target = object:get_object("target", true)
    local path = {}
    local path_offset_x, path_offset_y
    repeat
        assert(target:get_type() == ow.ObjectType.POINT, "In ow.MovingHitbox: `MovingHitboxTarget` (" .. object:get_id() .. ") is not a point")
        if path_offset_x == nil and path_offset_y == nil then
            path_offset_x = start_x - target.x
            path_offset_y = start_y - target.y
        end

        -- move path to align with center of mass
        table.insert(path, target.x + path_offset_x)
        table.insert(path, target.y + path_offset_y)
        target = target:get_object("target")
    until target == nil

    do -- proxy bodies used for on camera query
        self._camera_test_bodies = {}
        local camera_body_shape = b2.Circle(0, 0, 2)
        for i = 1, #path, 2 do
            local x = path[i+0]
            local y = path[i+1]
            local body = b2.Body(
                self._stage:get_physics_world(),
                b2.BodyType.STATIC,
                x, y,
                camera_body_shape
            )

            body:set_collides_with(0x0)
            body:set_collision_group(0x0)

            table.insert(self._camera_test_bodies, body)
        end
    end

    self._should_loop = object:get_boolean("should_loop", false)
    if self._should_loop == nil then self._should_loop = false end

    if self._should_loop then
        table.insert(path, path[1])
        table.insert(path, path[2])
        self._path = rt.Path(path)
    else
        self._path = rt.Path(path)
    end

    local centroid_x, centroid_y = object:get_centroid()
    self._velocity = object:get_number("velocity", false) or rt.settings.overworld.moving_hitbox.default_velocity

    local easing = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
    local easing_name = object:get_string("easing", false)
    if easing_name ~= nil then
        easing = rt.InterpolationFunctions[easing_name]
        if easing == nil then
            rt.error("In ow.MovingPlatform: for object `",  object:get_id(),  "`: unknown easing `",  easing_name,  "`")
        end
    end
    self._easing = easing

    -- reset cycle on player respawn
    self._start_timestamp = love.timer.getTime()
    self._stage:signal_connect("respawn", function()
        self._start_timestamp = love.timer.getTime()
    end)

    -- mesh
    local _, tris, mesh_data
    _, tris, mesh_data = object:create_mesh()

    self._offset_x, self._offset_y = -start_x, -start_y
    for i, data in ipairs(mesh_data) do
        data[1] = data[1] - start_x
        data[2] = data[2] - start_y
    end

    for tri in values(tris) do
        for j = 1, #tri, 2 do
            tri[j+0] = tri[j+0] - start_x
            tri[j+1] = tri[j+1] - start_y
        end
    end

    self._offset_x, self._offset_y = -start_x, -start_y
    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._tris = tris

    -- graphics
    self._normal_map = ow.NormalMap(
        object:get_id(), -- id for caching
        function() return self._tris end, -- get triangles
        function() self._mesh:draw() end -- draw mask
    )

    self._is_slippery = object:get_boolean("slippery")
    if self._is_slippery == nil then self._is_slippery = false end

    if self._is_slippery then
        self._mirror = ow.Mirror(
            self._scene,
            function() self._mesh:draw() end, -- mirror mask
            nil  -- occluding mask
        )

        self._mirror:create_contour(
            self._tris, -- mirror tris
            {} -- occluding tris
        )
    else
        self._blood_splatter = ow.BloodSplatter(
            self._scene
        )

        self._blood_splatter:create_contour(
            self._tris
        )
    end

    -- lighting
    if self._blood_splatter ~= nil then
        self._body:add_tag("segment_light_source")
        self._body:set_user_data(self)
        self.get_segment_light_sources = function(self)
            return self._blood_splatter:get_visible_segments(self._scene:get_camera():get_world_bounds())
        end
    end

    self._rail = ow.MovingHitboxPath(self._path)
end

local dt = math.eps * 10e2

function ow.MovingHitbox:update(delta)
    if self._normal_map:get_is_done() == false then
        self._normal_map:update(delta) -- finish loading coroutine
    end

    local is_visible = self._stage:get_is_body_visible(self._body)

    if is_visible then
        if self._normal_map:get_is_done() then
            self._normal_map:update()
        end

        if self._mirror ~= nil then
            self._mirror:update(delta)
        else
            local player = self._scene:get_player()
            if player:get_is_colliding_with(self._body) then
                local nx, ny, cx, cy = player:get_collision_normal(self._body)
                local r = player:get_radius() / 2
                self._blood_splatter:add(cx, cy, r, player:get_hue())
            end
        end
    end

    self._elapsed = self._elapsed + delta
    local length = self._path:get_length()
    local t, direction, easing_derivative

    if self._should_loop then
        local distance = self._velocity * self._elapsed
        t = (distance / length) % 1.0
        direction = 1

        local easing_t = self._easing(t)
        local easing_t_dt = self._easing((t + dt) % 1.0)
        easing_derivative = (easing_t_dt - easing_t) / dt
    else
        local distance_in_cycle = (self._velocity * self._elapsed) % (2 * length)
        if distance_in_cycle <= length then
            -- going forwards
            t = distance_in_cycle / length
            direction = 1

            local easing_t = self._easing(t)
            local easing_t_dt = self._easing(math.min(t + dt, 1.0))
            easing_derivative = (easing_t_dt - easing_t) / dt
        else
            -- going backwards
            local backward_distance = distance_in_cycle - length
            t = (length - backward_distance) / length
            direction = -1

            -- calculate derivative for backward motion (reversed easing)
            local reversed_t = 1 - t
            local easing_t = self._easing(math.max(reversed_t - dt, 0.0))
            local easing_t_dt = self._easing(reversed_t)
            easing_derivative = (easing_t_dt - easing_t) / dt
        end
    end

    local dx, dy = self._path:get_tangent(math.clamp(t, 0, 1))
    local velocity_x = dx * self._velocity * direction * easing_derivative
    local velocity_y = dy * self._velocity * direction * easing_derivative
    self._body:set_velocity(velocity_x, velocity_y)
end

local _back_priority = -math.huge
local _front_priority = math.huge

--- @brief
function ow.MovingHitbox:draw(priority)
    local box_visible = self._stage:get_is_body_visible(self._body)

    if box_visible then
        if self._mirror ~= nil then
            self._mirror:set_offset(self._body:get_predicted_position())
        else
            self._blood_splatter:set_offset(self._body:get_predicted_position())
        end
    end

    if priority == _back_priority then
        local rail_visible = box_visible
        for body in values(self._camera_test_bodies) do
            if rail_visible then break end
            if self._stage:get_is_body_visible(body) then
                rail_visible = true
            end
        end

        if rail_visible then
            self._rail:draw_rail(self._body:get_center_of_mass())
        end

        if box_visible then
            love.graphics.push()
            love.graphics.translate(self._body:get_position())
            love.graphics.rotate(self._body:get_rotation())

            if self._is_slippery then
                rt.Palette.SLIPPERY:bind()
            else
                rt.Palette.STICKY:bind()
            end
            self._mesh:draw()

            local camera = self._stage:get_scene():get_camera()
            local camera_offset_x, camera_offset_y = camera:get_position()
            camera_offset_x = -camera_offset_x
            camera_offset_y = -camera_offset_y

            if self._normal_map:get_is_done() then
                -- set offset to compensate for camera movement, and for translation of
                -- tris to origin in instantiate
                self._normal_map:set_offset(camera_offset_x, camera_offset_y)
                self._normal_map:draw_shadow(camera)

                local point_lights, point_colors = self._stage:get_point_light_sources()
                local segment_lights, segment_colors = self._stage:get_segment_light_sources()
                self._normal_map:draw_light(
                    camera,
                    point_lights,
                    point_colors,
                    segment_lights,
                    segment_colors
                )
            end

            local stencil_value = rt.graphics.get_stencil_value()
            rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
            self._mesh:draw()
            rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

            if self._is_slippery then
                rt.Palette.SLIPPERY_OUTLINE:bind()
            else
                rt.Palette.STICKY_OUTLINE:bind()
            end

            love.graphics.setLineWidth(3)
            love.graphics.setLineJoin("bevel")

            for tri in values(self._tris) do
                love.graphics.line({
                    tri[1], tri[2], tri[3], tri[4], tri[5], tri[6], tri[1], tri[2]
                })
            end

            rt.graphics.set_stencil_mode(nil)

            love.graphics.pop()

            if self._mirror ~= nil then
                self._mirror:draw()

                --[[
                love.graphics.setColor(1, 1, 1, 1)
                local offset_x, offset_y = 0, 0
                for edge in values(self._mirror._edges) do
                    local x1, y1, x2, y2 = table.unpack(edge:getUserData().segment)
                    love.graphics.line(
                        x1 + offset_x,
                        y1 + offset_y,
                        x2 + offset_x,
                        y2 + offset_y
                    )
                end
                ]]--
            elseif self._blood_splatter ~= nil then
                self._blood_splatter:draw()
            end
        end
    elseif priority == _front_priority and box_visible then
        self._rail:draw_attachment(self._body:get_position())
    end
end

--- @brief
function ow.MovingHitbox:get_render_priority()
    return _back_priority, _front_priority
end

--- @brief
function ow.MovingHitbox:reset()
    self._elapsed = 0
end

