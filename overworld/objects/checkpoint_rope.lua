rt.settings.overworld.checkpoint_rope = {
    segment_length = 10, -- px
    segment_hue_speed = 2,
    segment_gravity = 10000,
    radius = rt.settings.player.radius
}

--- @class ow.CheckpointRope
ow.CheckpointRope = meta.class("CheckpointRope")

local _shader = rt.Shader("overworld/objects/checkpoint_rope.glsl")

function rotate_segment_around_point(x1, y1, x2, y2, px, py, angle)
    local x1_translated = x1 - px
    local y1_translated = y1 - py
    local x2_translated = x2 - px
    local y2_translated = y2 - py

    local cos_angle = math.cos(angle)
    local sin_angle = math.sin(angle)

    local x1_rotated = x1_translated * cos_angle - y1_translated * sin_angle
    local y1_rotated = x1_translated * sin_angle + y1_translated * cos_angle
    local x2_rotated = x2_translated * cos_angle - y2_translated * sin_angle
    local y2_rotated = x2_translated * sin_angle + y2_translated * cos_angle

    local new_x1 = x1_rotated + px
    local new_y1 = y1_rotated + py
    local new_x2 = x2_rotated + px
    local new_y2 = y2_rotated + py

    return new_x1, new_y1, new_x2, new_y2
end

local _collision_group = bit.bnot(bit.bor(
    rt.settings.player.player_collision_group,
    rt.settings.player.player_outer_body_collision_group,
    rt.settings.player.bounce_collision_group
))

--- @brief
function ow.CheckpointRope:instantiate(scene, stage, world, x1, y1, x2, y2)
    self._scene = scene
    self._stage = stage
    self._world = world
    self._top_x, self._top_y, self._bottom_x, self._bottom_y = x1, y1, x2, y2

    self._is_cut = false
    self._cut_index = -1
    self._should_despawn = false
    self._is_despawned = false
    self._color = { 1, 1, 1, 1 }

    self:_init_bodies()

    if not self._is_despawned then
        self:_update_mesh()
    end
end

--- @brief
function ow.CheckpointRope:_init_bodies()
    self._bodies = {}
    self._joints = {}
    self._n_segments = 0

    local collision_group = rt.settings.player.exempt_collision_group

    local height = self._bottom_y - self._top_y
    local n_segments = math.max(math.floor(height / rt.settings.overworld.checkpoint_rope.segment_length), 2)
    local segment_length = height / (n_segments - 1)
    local radius = 5 -- experimentally determines for mass, solver stability

    self._n_segments = n_segments

    local current_x, current_y = self._top_x, self._top_y
    for i = 1, n_segments do
        local body
        if i == 1 or i == n_segments then
            local anchor_width = 10
            local dx_left, dy_left, dx_right, dy_right = -0.5 * anchor_width, -1 * radius, 0.5 * anchor_width, 1 * radius
            body = b2.Body(self._world, b2.BodyType.STATIC, current_x, current_y, b2.Rectangle(dx_left, dy_left, math.abs(dx_right - dx_left), math.abs(dy_right - dy_left)))
            body:set_mass(1)
        else
            body = b2.Body(self._world, b2.BodyType.DYNAMIC, current_x, current_y, b2.Circle(0, 0, radius))
            body:set_mass(height / n_segments * 0.015)
        end

        -- dummy instance for light source
        body:add_tag("segment_light_source")
        local instance = {
            get_segment_light_sources = function()
                local angle = body:get_rotation()
                local x, y = body:get_position()
                local left_x, left_y = x, y - radius
                local right_x, right_y = x, y + radius

                left_x, left_y, right_x, right_y = rotate_segment_around_point(
                    left_x, left_y,
                    right_x, right_y,
                    x, y,
                    angle
                )

                local color = table.deepcopy(self._color)
                return {{ left_x, left_y, right_x, right_y }}, { color }
            end
        }
        body:set_user_data(instance)
        body:set_collides_with(_collision_group)
        body:set_collision_group(collision_group)

        body:set_collision_disabled(true)
        body:set_is_rotation_fixed(false)

        self._bodies[i] = body
        current_y = current_y + segment_length
    end

    for i = 1, n_segments - 1 do
        local a, b = self._bodies[i], self._bodies[i+1]
        local a_x, a_y = a:get_position()
        local b_x, b_y = b:get_position()

        if i ~= 1 and i ~= n_segments then
            a_y = a_y + radius
            b_y = b_y - radius
        end

        local anchor_x, anchor_y = math.mix2(a_x, a_y, b_x, b_y, 0.5)
        local axis_x, axis_y = math.normalize(b_x - a_x, b_y - a_y)
        local joint = love.physics.newPrismaticJoint(
            a:get_native(), b:get_native(),
            anchor_x, anchor_y,
            axis_x, axis_y,
            false
        )
        joint:setLimitsEnabled(true)
        joint:setLimits(0, 0)

        self._joints[i] = joint
    end
end

--- @brief
function ow.CheckpointRope:cut()
    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()
    player_x = math.mix(self._top_x, self._bottom_x, 0.5)

    local impulse = 0.05

    local joint_broken = false
    for i, joint in ipairs(self._joints) do
        if i > self._n_segments - 1 then break end

        local a_x, a_y = self._bodies[i+0]:get_position()
        local b_x, b_y = self._bodies[i+1]:get_position()
        if player_y >= a_y and player_y <= b_y then
            joint_broken = true
            self._cut_index = i
            joint:destroy()
            break
        end
    end

    if joint_broken then
        self._bodies[1]:set_type(b2.BodyType.DYNAMIC)
        self._bodies[self._n_segments]:set_type(b2.BodyType.DYNAMIC)

        local offset = player:get_radius()
        local vx, vy = player:get_velocity()
        if vx > 0 then offset = -offset end
        impulse = impulse * math.magnitude(vx, vy)

        for body in values(self._bodies) do
            body:set_collides_with(_collision_group)
            local body_x, body_y = body:get_position()
            local dx, dy = math.normalize(body_x - (player_x + offset), body_y - player_y)
            body:apply_linear_impulse(dx * impulse, dy * impulse)
        end
        self._is_cut = true
        self._should_despawn = true

        if self._is_despawned ~= true then
            self:_update_mesh()
        end
    end
end

--- @brief
function ow.CheckpointRope:get_is_cut()
    return self._is_cut
end

--- @brief
function ow.CheckpointRope:update(delta)
    self._color = { rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1) }

    if self._should_despawn then
        local seen = false
        for body in values(self._bodies) do
            if self._stage:get_is_body_visible(body) then
                seen = true
                break
            end
        end

        if seen == false then
            self:_despawn()
        end
    end

    if not self._is_despawned then
        local gravity = rt.settings.overworld.checkpoint_rope.segment_gravity * delta
        for body in values(self._bodies) do
            body:apply_force(0, gravity)
        end

        -- safeguard against solver becoming unstable
        for joint in values(self._joints) do
            if not joint:isDestroyed() and joint:getJointSpeed() > 1000 then
                self:_despawn()
                break
            end
        end
    end

    if self._is_despawned ~= true then
        self:_update_mesh()
    end
end

--- @brief
function ow.CheckpointRope:_despawn()
    for joint in values(self._joints) do
        if not joint:isDestroyed() then
            joint:destroy()
        end
    end

    for body in values(self._bodies) do
        body:destroy()
    end

    self._bodies = {}
    self._joints = {}
    self._should_despawn = false
    self._is_despawned = true
end

--- @brief
function ow.CheckpointRope:_update_mesh()
    local r = rt.settings.overworld.checkpoint_rope.radius
    local left_a = 0 -- encode side of rope in color.a
    local center_a = 0.5
    local right_a = 1

    local outer_r = 0
    local inner_r = 1

    -- alpha in 0, 0.5, 1, signals which side of the rope we're on
    -- r in 0, 1, signals whether the vertex is internal or external
    local inner = function(a) return inner_r, 1, 1, a end
    local outer = function(a) return outer_r, 0, 0, a end
    local left_u = 0
    local center_u = 1
    local right_u = 0

    local function generate_mesh(start_i, end_i, mesh)
        local data = {}
        local vertex_map = {}
        local vertex_i = 0

        local left_contour, right_contour = {}, {}

        local function miter(previous_normal_x, previous_normal_y, current_normal_x, current_normal_y)
            local sum_x = previous_normal_x + current_normal_x
            local sum_y = previous_normal_y + current_normal_y
            local sum_length = math.sqrt(sum_x * sum_x + sum_y * sum_y)

            if sum_length < math.eps then
                -- opposing normals, fallback to current normal
                return current_normal_x, current_normal_y, r
            end

            local miter_x = sum_x / sum_length
            local miter_y = sum_y / sum_length
            local denom = math.dot(miter_x, miter_y, current_normal_x, current_normal_y)

            if math.abs(denom) < math.eps then
                return current_normal_x, current_normal_y, r
            end

            local miter_length = r / denom

            -- clamp miter length to avoid spikes on very sharp angles
            local miter_limit = 2.0 * r
            if miter_length > miter_limit then
                miter_length = miter_limit
            elseif miter_length < -miter_limit then
                miter_length = -miter_limit
            end

            return miter_x, miter_y, miter_length
        end

        -- iterate segments [start_i, end_i - 1]
        -- precompute node positions (to avoid duplicate get_position calls)
        local node_count = (end_i - start_i + 1)
        local positions_x, positions_y = {}, {}
        for k = 1, node_count do
            local body_index = start_i + (k - 1)
            local x, y = self._bodies[body_index]:get_position()
            positions_x[k], positions_y[k] = x, y
        end

        -- precompute per-segment normals (left/right) for all segments in [start_i, end_i - 1]
        local n_segments = node_count - 1
        local normals_left_x, normals_left_y = {}, {}
        local normals_right_x, normals_right_y = {}, {}

        for s = 1, n_segments do
            local x1, y1 = positions_x[s], positions_y[s]
            local x2, y2 = positions_x[s + 1], positions_y[s + 1]
            local dx, dy = math.normalize(x2 - x1, y2 - y1)
            normals_left_x[s], normals_left_y[s] = math.turn_left(dx, dy)
            normals_right_x[s], normals_right_y[s] = math.turn_right(dx, dy)
        end

        -- main segment iteration using precomputed normals
        for i = start_i, end_i - 1 do
            local seg_idx = (i - start_i + 1)

            local x1, y1 = positions_x[seg_idx], positions_y[seg_idx]
            local x2, y2 = positions_x[seg_idx + 1], positions_y[seg_idx + 1]

            -- current normals
            local current_normal_left_x,  current_normal_left_y  = normals_left_x[seg_idx],  normals_left_y[seg_idx]
            local current_normal_right_x, current_normal_right_y = normals_right_x[seg_idx], normals_right_y[seg_idx]

            -- previous normals (fallback to current at start)
            local prev_idx = seg_idx > 1 and (seg_idx - 1) or seg_idx
            local previous_normal_left_x,  previous_normal_left_y  = normals_left_x[prev_idx],  normals_left_y[prev_idx]
            local previous_normal_right_x, previous_normal_right_y = normals_right_x[prev_idx], normals_right_y[prev_idx]

            -- next normals (fallback to current at end)
            local next_idx = seg_idx < n_segments and (seg_idx + 1) or seg_idx
            local next_normal_left_x,  next_normal_left_y  = normals_left_x[next_idx],  normals_left_y[next_idx]
            local next_normal_right_x, next_normal_right_y = normals_right_x[next_idx], normals_right_y[next_idx]

            -- miters
            local miter_left_x1, miter_left_y1, miter_left_l1 = miter( -- left at start
                previous_normal_left_x, previous_normal_left_y,
                current_normal_left_x, current_normal_left_y
            )
            local miter_right_x1, miter_right_y1, miter_right_l1 = miter( -- right at start
                previous_normal_right_x, previous_normal_right_y,
                current_normal_right_x, current_normal_right_y
            )
            local miter_left_x2, miter_left_y2, miter_left_l2 = miter( -- left at end
                current_normal_left_x, current_normal_left_y,
                next_normal_left_x, next_normal_left_y
            )
            local miter_right_x2, miter_right_y2, miter_right_l2 = miter( -- right at end
                current_normal_right_x, current_normal_right_y,
                next_normal_right_x, next_normal_right_y
            )

            -- vertices
            local left_x1, left_y1   = x1 + miter_left_x1  * miter_left_l1,  y1 + miter_left_y1  * miter_left_l1
            local center_x1, center_y1 = x1 + 0, y1 + 0
            local right_x1, right_y1 = x1 + miter_right_x1 * miter_right_l1, y1 + miter_right_y1 * miter_right_l1

            local left_x2, left_y2   = x2 + miter_left_x2  * miter_left_l2,  y2 + miter_left_y2  * miter_left_l2
            local center_x2, center_y2 = x2 + 0, y2 + 0
            local right_x2, right_y2 = x2 + miter_right_x2 * miter_right_l2, y2 + miter_right_y2 * miter_right_l2

            -- v coords
            local current_v = i / #self._bodies
            local next_v = (i + 1) / #self._bodies

            --[[
            vertex layout
            1   2   3
            4   5   6
            ]]--
            for entry in range(
                { left_x1,   left_y1,   left_u,   current_v, outer(left_a) },   -- 1
                { center_x1, center_y1, center_u, current_v, inner(center_a) }, -- 2
                { right_x1,  right_y1,  right_u,  current_v, outer(right_a) },  -- 3
                { left_x2,   left_y2,   left_u,   next_v,    outer(left_a) },   -- 4
                { center_x2, center_y2, center_u, next_v,    inner(center_a) }, -- 5
                { right_x2,  right_y2,  right_u,  next_v,    outer(right_a) }   -- 6
            ) do
                table.insert(data, entry)
            end

            -- triangulation
            if mesh == nil then
                local j = vertex_i
                for n in range(
                    j + 1, j + 2, j + 5,
                    j + 1, j + 4, j + 5,
                    j + 2, j + 3, j + 6,
                    j + 2, j + 5, j + 6
                ) do
                    table.insert(vertex_map, n)
                end

                -- contours for fill triangles
                for n in range(j + 1, j + 2, j + 4) do
                    table.insert(left_contour, n)
                end
                for n in range(j + 3, j + 2, j + 6) do
                    table.insert(right_contour, n)
                end
            end

            vertex_i = vertex_i + 6
        end

        if mesh == nil then
            -- fill triangles
            for contour in range(left_contour, right_contour) do
                for j = 3, #contour, 3 do
                    local i1 = contour[j+0]
                    local i2 = contour[j+1]
                    local i3 = contour[j+2]

                    if i1 ~= nil and i2 ~= nil and i3 ~= nil then
                        local outer_x1, outer_y1 = table.unpack(data[i1])
                        local inner_x1, inner_y1 = table.unpack(data[i2])
                        local outer_x2, outer_y2 = table.unpack(data[i3])

                        for n in range(
                            i1,
                            i2,
                            i3
                        ) do
                            table.insert(vertex_map, n)
                        end
                    end
                end
            end
        end

        -- end caps
        local add_end_cap = function(i1, i2, up_or_down)
            local start_x1, start_y1 = self._bodies[i1]:get_position()
            local start_x2, start_y2 = self._bodies[i2]:get_position()
            local start_dx, start_dy = math.normalize(start_x2 - start_x1, start_y2 - start_y1)

            local end_cap_r = math.distance(start_x1, start_y1, start_x2, start_y2)

            -- move one segment up or down
            local sign = ternary(up_or_down, -1, 1)
            start_x1 = start_x1 + sign * start_dx * end_cap_r
            start_y1 = start_y1 + sign * start_dy * end_cap_r
            start_x2 = start_x2 + sign * start_dx * end_cap_r
            start_y2 = start_y2 + sign * start_dy * end_cap_r

            local left_nx, left_ny = math.turn_left(start_dx, start_dy)
            local right_nx, right_ny = math.turn_right(start_dx, start_dy)

            left_nx = left_nx * r
            left_ny = left_ny * r
            right_nx = right_nx * r
            right_ny = right_ny * r

            local left_x1, left_y1 = start_x1 + left_nx, start_y1 + left_ny
            local center_x1, center_y1 = start_x1, start_y1
            local right_x1, right_y1 = start_x1 + right_nx, start_y1 + right_ny

            local left_x2, left_y2 = start_x2 + left_nx, start_y2 + left_ny
            local center_x2, center_y2 = start_x2, start_y2
            local right_x2, right_y2 = start_x2 + right_nx, start_y2 + right_ny

            if up_or_down then
                local j = 0
                for entry in range(
                    { right_x1, right_y1,   right_u, 0, outer(left_a) }, -- 3
                    { center_x1, center_y1, center_u, 0, outer(center_a) }, -- 2
                    { left_x1, left_y1,     left_u, 0, outer(right_a) }  -- 1
                ) do
                    table.insert(data, 1, entry) -- push front, so reverse order
                end

                if mesh == nil then
                    for i = 1, #vertex_map do -- shift rest upwads
                        vertex_map[i] = vertex_map[i] + 3
                    end

                    for n in range( -- different triangulation, pointing upwards
                        j + 1, j + 2, j + 4,
                        j + 2, j + 4, j + 5,
                        j + 2, j + 5, j + 6,
                        j + 2, j + 3, j + 6
                    ) do
                        table.insert(vertex_map, 1, n)
                    end
                end
            else
                local j = #data - 3
                for entry in range( -- pointing downwards
                    { left_x2, left_y2,     left_u, 1, outer(left_a) }, -- 4
                    { center_x2, center_y2, center_u, 1, outer(center_a) }, -- 5
                    { right_x2, right_y2,   right_u, 1, outer(right_a) }  -- 6
                ) do
                    table.insert(data, entry)
                end

                if mesh == nil then
                    for n in range(
                        j + 1, j + 2, j + 5,
                        j + 1, j + 4, j + 5,
                        j + 2, j + 3, j + 5,
                        j + 3, j + 5, j + 6
                    ) do
                        table.insert(vertex_map, n)
                    end
                end
            end
        end

        add_end_cap(math.max(end_i - 1, 1), end_i, false)
        add_end_cap(start_i, math.min(start_i + 1, #self._bodies), true)

        if mesh == nil then
            mesh = rt.Mesh(
                data,
                rt.MeshDrawMode.TRIANGLES,
                rt.VertexFormat,
                rt.GraphicsBufferUsage.STREAM
            )
            mesh:set_vertex_map(vertex_map)
        else
            mesh:replace_data(data)
        end

        return mesh
    end

    if not self._is_cut then
        self._pre_cut_mesh = generate_mesh(1, #self._bodies, self._pre_cut_mesh)
    else
        self._post_cut_mesh_top = generate_mesh(1, self._cut_index - 1, self._post_cut_mesh_top)
        self._post_cut_mesh_bottom = generate_mesh(self._cut_index + 1, #self._bodies, self._post_cut_mesh_bottom)
    end
end

--- @brief
function ow.CheckpointRope:_draw(bloom_active)
    if self._is_despawned then return end

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("color", self._color)
    _shader:send("bloom_active", bloom_active)
    love.graphics.setColor(1, 1, 1, 1)
    if not self._is_cut and self._pre_cut_mesh ~= nil then
        self._pre_cut_mesh:draw()
    elseif self._post_cut_mesh_bottom ~= nil and self._post_cut_mesh_bottom ~= nil then
        self._post_cut_mesh_top:draw()
        self._post_cut_mesh_bottom:draw()
    end
    _shader:unbind()
end

--- @brief
function ow.CheckpointRope:draw()
    self:_draw(false)
end

--- @brief
function ow.CheckpointRope:draw_bloom()
    self:_draw(true)
end

--- @brief
function ow.CheckpointRope:reset()
    self:_despawn()
    self._is_despawned = false
    self._is_cut = false
    self:_init_bodies()

    self._pre_cut_mesh = nil
    self._post_cut_mesh_top = nil
    self._post_cut_mesh_bottom = nil
    self:_update_mesh()
end

