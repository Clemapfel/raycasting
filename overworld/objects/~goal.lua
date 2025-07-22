rt.settings.overworld.goal = {
    segment_length = 7,
    gravity = 10000
}

--- @class ow.Goal
ow.Goal = meta.class("Goal")

local _shader = nil

--- @brief
function ow.Goal:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.Goal.instantiate: object is not a rectangle")

    self._world = stage:get_physics_world()
    self._stage = stage
    self._scene = scene

    self._x = object.x
    self._y = object.y
    self._width = object.width
    self._height = object.height
    self._stage:_notify_goal_added(self)
    self._activated = false
    self._timestamp = math.huge
    self._is_broken = false

    self:_initialize()

    self._body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
        self._x, self._y,
        self._x, self._y + self._height
    ))
    self._body:set_use_continuous_collision(true)
    self._body:set_is_sensor(true)
    self._body:set_collides_with(bit.bor(
        rt.settings.player.player_outer_body_collision_group,
        rt.settings.player.player_collision_group
    ))

    self._body:signal_connect("collision_start", function()
        self._activated = true
        self._timestamp = self._scene:get_timer()
    end)

    self._stage:signal_connect("respawn", function()
        if self._activated then
            self:_initialize()
            self._activated = false
        end
    end)
end

--- @brief
function ow.Goal:_initialize()
    local n_segments = math.max(math.floor(self._height / rt.settings.overworld.goal.segment_length), 2)
    local segment_length = self._height / (n_segments - 1)
    local radius = segment_length / 2

    local current_x, current_y = self._x, self._y

    for joint in values(self._segment_joints) do
        if not joint:isDestroyed() then
            joint:destroy()
        end
    end

    for body in values(self._segment_bodies) do
        body:destroy()
    end

    self._segment_bodies = {}
    self._segment_joints = {}
    self._segment_points = {}
    self._segment_colors = {}

    self._n_segments = n_segments
    self._thickness = 2 * radius
    for i = 1, n_segments do
        local body
        if i == 1 or i == n_segments then
            local anchor_width = 10
            body = b2.Body(self._world, b2.BodyType.STATIC, current_x, current_y, b2.Rectangle(-0.5 * anchor_width, -1 * radius, anchor_width, 2 * radius))
            body:set_mass(1)
        else
            body = b2.Body(self._world, b2.BodyType.DYNAMIC, current_x, current_y, b2.Circle(0, 0, radius))
            body:set_mass(self._height / self._n_segments * 0.025)
        end

        body._goal_is_marked = false

        body:set_collides_with(rt.settings.player.bounce_collision_group)
        body:set_collision_group(rt.settings.player.bounce_collision_group)
        body:set_is_rotation_fixed(false)
        body:signal_connect("collision_start", function(self_body, other_body)
            if other_body:has_tag("player") then
                self_body._goal_is_marked = true
            end
        end)

        self._segment_bodies[i] = body
        self._segment_colors[i] = rt.RGBA(rt.lcha_to_rgba(0.8, 1, (i - 1) / n_segments, 1))
        current_y = current_y + segment_length
    end

    for i = 1, n_segments - 1 do
        local a, b = self._segment_bodies[i], self._segment_bodies[i+1]
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

        self._segment_joints[i] = joint
        table.insert(self._segment_points, {a_x, a_y})
        table.insert(self._segment_points, {b_x, b_y})
    end

    self._is_broken = false
end

--- @brief
function ow.Goal:_break()
    if self._is_broken then return end

    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()

    local joint_broken = false
    for i, joint in ipairs(self._segment_joints) do
        if i > self._n_segments - 1 then break end

        local a_x, a_y = self._segment_bodies[i]:get_position()
        local b_x, b_y = self._segment_bodies[i+1]:get_position()
        if player_y >= a_y and player_y <= b_y then
            joint_broken = true
            joint:destroy()
            break
        end
    end

    if joint_broken then
        self._stage:finish_stage(self._timestamp)
        self._segment_bodies[1]:set_type(b2.BodyType.DYNAMIC)
        self._segment_bodies[self._n_segments]:set_type(b2.BodyType.DYNAMIC)

        self._is_broken = true
    end
end

--- @brief
function ow.Goal:draw()
    --if not self._scene:get_is_body_visible(self._body) then return end
    self._body:draw()

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(self._thickness + 1)
    for i = 1, self._n_segments - 1 do
        if not self._segment_joints[i]:isDestroyed() then
            local a = self._segment_bodies[i]
            local b = self._segment_bodies[i+1]
            local a_x, a_y = a:get_position()
            local b_x, b_y = b:get_position()

            love.graphics.line(a_x, a_y, b_x, b_y)
            love.graphics.circle("fill", a_x, a_y, self._thickness / 2 + 1)
        end
    end

    love.graphics.setLineWidth(self._thickness)
    for i = 1, self._n_segments - 1 do
        if not self._segment_joints[i]:isDestroyed() then
            local a = self._segment_bodies[i]
            local b = self._segment_bodies[i+1]
            local a_x, a_y = a:get_position()
            local b_x, b_y = b:get_position()

            self._segment_colors[i]:bind()
            love.graphics.line(a_x, a_y, b_x, b_y)
            love.graphics.circle("fill", a_x, a_y, self._thickness / 2)
        end
    end
    --self._segment_bodies[self._n_segments]:draw()
end

--- @brief
function ow.Goal:update(delta)
    if not self._activated then return end

    if not self._is_broken then
        local total_force = 0
        local step = 1 / self._world:get_timestep()
        for joint in values(self._segment_joints) do
            local force_x, force_y = joint:getReactionForce(step)
            total_force = total_force + -1 * force_x
        end

        local max_displacement = -math.huge
        for body in values(self._segment_bodies) do
            local body_x, body_y = body:get_position()
            max_displacement = math.max(max_displacement, body_x - self._x) -- signed
        end

        local player = self._scene:get_player()
        if max_displacement > player:get_radius() then
            self:_break()
        end
    else
        local gravity = rt.settings.overworld.goal.gravity * delta
        for body in values(self._segment_bodies) do
            body:apply_force(0, gravity)
        end
    end
end
