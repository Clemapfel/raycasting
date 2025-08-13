rt.settings.overworld.checkpoint_rope = {
    segment_length = 7, -- px
    segment_hue_speed = 2,
    segment_gravity = 10000
}

--- @class ow.CheckpointRope
ow.CheckpointRope = meta.class("CheckpointRope")

--- @brief
function ow.CheckpointRope:instantiate(scene, world, x1, y1, x2, y2)
    self._scene = scene
    self._world = world
    self._top_x, self._top_y, self._bottom_x, self._bottom_y = x1, y1, x2, y2

    self._bodies = {}
    self._joints = {}
    self._n_segments = 0
    self._is_cut = false
    self._should_despawn = false
    self._is_despawned = false
    self._color = { 1, 1, 1, 1 }

    local collision_group = b2.CollisionGroup.GROUP_10

    local height = self._bottom_y - self._top_y
    local n_segments = math.max(math.floor(height / rt.settings.overworld.checkpoint_rope.segment_length), 2)
    local segment_length = height / (n_segments - 1)
    local radius = segment_length / 2

    self._n_segments = n_segments

    local current_x, current_y = self._top_x, self._top_y
    for i = 1, n_segments do
        local body
        if i == 1 or i == n_segments then
            local anchor_width = 10
            body = b2.Body(self._world, b2.BodyType.STATIC, current_x, current_y, b2.Rectangle(-0.5 * anchor_width, -1 * radius, anchor_width, 2 * radius))
            body:set_mass(1)
        else
            body = b2.Body(self._world, b2.BodyType.DYNAMIC, current_x, current_y, b2.Circle(0, 0, radius))
            body:set_mass(height / n_segments * 0.015)
        end

        body:set_collides_with(collision_group)
        body:set_collision_group(bit.bnot(collision_group))
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

    self:_update_mesh()
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
            body:set_collides_with(bit.bnot(bit.bor(
                rt.settings.player.player_collision_group,
                rt.settings.player.player_outer_body_collision_group,
                rt.settings.player.bounce_collision_group
            )))

            local body_x, body_y = body:get_position()
            local dx, dy = math.normalize(body_x - (player_x + offset), body_y - player_y)
            body:apply_linear_impulse(dx * impulse, dy * impulse)
        end
        self._is_cut = true
        self._should_despawn = true
    end
end

--- @brief
function ow.CheckpointRope:get_is_cut()
    return self._is_cut
end

--- @brief
function ow.CheckpointRope:update(delta)
    if self._should_despawn then
        local seen = false
        for body in values(self._bodies) do
            if self._scene:get_is_body_visible(body) then
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

    self:_update_mesh()
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

--- @brie
function ow.CheckpointRope:_update_mesh()
    local m, r = 5, 20
    local inner = function() return 1, 1, 1, 1 end
    local outer = function() return 1, 1, 1, 0 end

    local data = {}
    local vertex_map = {}
    local vertex_i = 0

    local left_contour, right_contour = {}, {}

    for i = 1, self._n_segments - 1 do
        local x1, y1 = self._bodies[i+0]:get_position()
        local x2, y2 = self._bodies[i+1]:get_position()

        local dx, dy = math.normalize(x2 - x1, y2 - y1)
        local left_x, left_y = math.turn_left(dx, dy)
        local right_x, right_y = math.turn_right(dx, dy)

        left_x = left_x * r
        left_y = left_y * r
        right_x = right_x * r
        right_y = right_y * r

        local left_x1, left_y1 = x1 + left_x, y1 + left_y
        local center_x1, center_y1 = x1 + 0, y1 + 0
        local right_x1, right_y1 = x1 + right_x, y1 + right_y

        local left_x2, left_y2 = x2 + left_x, y2 + left_y
        local center_x2, center_y2 = x2 + 0, y2 + 0
        local right_x2, right_y2 = x2 + right_x, y2 + right_y

        for entry in range(
            { left_x1, left_y1, 1, 0, outer() },
            { center_x1, center_y1, 0, 0, inner() },
            { right_x1, right_y1, 1, 0, outer() },
            { left_x2, left_y2, 1, 1, outer() },
            { center_x2, center_y2, 0, 1, inner() },
            { right_x2, right_y2, 1, 1, outer() }
        ) do
            table.insert(data, entry)
        end

        if self._mesh == nil then
            local j = vertex_i
            for n in range(
                j + 1, j + 2, j + 5,
                j + 1, j + 4, j + 5,
                j + 2, j + 3, j + 6,
                j + 2, j + 5, j + 6
            ) do
                table.insert(vertex_map, n)
            end

            vertex_i = vertex_i + 6
        end
    end

    if self._mesh == nil then
        self._mesh = rt.Mesh(
            data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STREAM
        )
        self._mesh:set_vertex_map(vertex_map)
    else
        self._mesh:replace_data(data)
    end
end

--- @brief
function ow.CheckpointRope:draw()
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
end