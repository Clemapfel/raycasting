require "common.smoothed_motion_1d"

rt.settings.overworld.player_recorder_body = {
    rope_n_ropes = 16,
    rope_n_segments = 16,
    rope_length = 45,
    rope_thickness = 10
}

--- @class ow.PlayerRecorderBody
ow.PlayerRecorderBody = meta.class("PlayerRecorderBody")

local _NOT_PRESSED = 0
local _PRESSED = 1

local _settings = rt.settings.overworld.player_recorder_body

local _outline_shader = rt.Shader("common/player_body_outline.glsl", { MODE = 1 })

--- @brief
function ow.PlayerRecorderBody:instantiate(player_recorder, stage, scene)
    meta.assert(
        player_recorder, ow.PlayerRecorder,
        stage, ow.Stage,
        scene, ow.OverworldScene
    )

    self._recorder = player_recorder
    self._stage = stage
    self._scene = scene

    self._radius = rt.settings.player.radius
    self._body = nil
    self._ropes = {}
    self._n_ropes = 0
    self._is_bubble = false

    -- canvases
    self._canvas_scale = rt.settings.player_body.canvas_scale
    self._canvas_needs_update = true

    local padding = rt.settings.player_body.canvas_padding
    local radius = _settings.rope_length + self._radius
    self._canvas = rt.RenderTexture(
        self._canvas_scale * (radius + 2 * padding),
        self._canvas_scale * (radius + 2 * padding),
    4) -- msaa

end

--- @brief
function ow.PlayerRecorderBody:initialize(x, y)
    if self._body == nil then
        self._body = b2.Body(
            self._stage:get_physics_world(),
            b2.BodyType.DYNAMIC,
            x, y,
            b2.Circle(0, 0, self._radius)
        )

        local player_settings = rt.settings.player
        self._body:set_collides_with(bit.bnot(bit.bor(
            player_settings.player_collision_group,
            player_settings.player_outer_body_collision_group,
            player_settings.bounce_collision_group,
            player_settings.ghost_collision_group
        )))
        self._body:set_collision_group(player_settings.exempt_collision_group)
        self._body:signal_connect("collision_start", function(_, other_body, normal_x, normal_y, x1, y1, x2, y2)
            if x1 ~= nil then
                self._stage:get_blood_splatter():add(x1, y1, self._radius, 0, 0)
            end
        end)

        self._ropes = {}
        self._n_ropes = _settings.rope_n_ropes
        for rope_i = 1, self._n_ropes do
            local current_x, current_y = x, y
            local angle = (rope_i - 1) / self._n_ropes * 2 * math.pi
            local rope = {
                current_positions = {},
                last_positions = {},
                last_velocities = {},
                masses = {},
                anchor_x = math.cos(angle) * self._radius, -- offset
                anchor_y = math.sin(angle) * self._radius,
                target_x = 0,
                target_y = 0,
                n_segments = _settings.rope_n_segments,
                length = _settings.rope_length
            }

            rope.segment_length = rope.length / rope.n_segments

            for segment_i = 1, _settings.rope_n_segments do
                table.insert(rope.current_positions, x)
                table.insert(rope.current_positions, y)

                table.insert(rope.last_positions, x)
                table.insert(rope.last_positions, y)
                table.insert(rope.last_velocities, 0)
                table.insert(rope.last_velocities, 0)
                table.insert(rope.masses,  1) -- TODO: determine easing

                current_y = current_y + rope.segment_length * 0.5
            end

            table.insert(self._ropes, rope)
        end
    else -- body == nil
        self:set_position(x, y)
    end
end

--- @brief
function ow.PlayerRecorderBody:update_input(
    up_pressed,
    right_pressed,
    down_pressed,
    left_pressed,
    sprint_pressed,
    jump_pressed,
    is_bubble
)
    self._is_bubble = is_bubble
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    for to_update in range(
        self._up_pressed_motion,
        self._right_pressed_motion,
        self._down_pressed_motion,
        self._left_pressed_motion
    ) do
        to_update:update(delta)
    end

    local x, y = self._body:get_position()
    for rope in values(self._ropes) do
        local dx, dy = math.normalize(rope.anchor_x, rope.anchor_y)
        local length = 45
        rope.target_x, rope.target_y = x + dx * length, y + dy * length
    end

    require "common.player_body"

    -- use rope constraint solver from player
    local settings = ternary(self._is_bubble, rt.settings.player_body.bubble, rt.settings.player_body.non_bubble)
    for rope in values(self._ropes) do
        rt.PlayerBody._rope_handler({
            rope = rope,
            is_bubble = self._is_bubble,
            n_velocity_iterations = settings.n_velocity_iterations,
            n_distance_iterations = settings.n_distance_iterations,
            n_axis_iterations = settings.n_axis_iterations,
            n_bending_iterations = settings.n_bending_iterations,
            n_inverse_kinematics_iterations = 1,
            inverse_kinematics_intensity = 0.01,
            inertia = settings.inertia,
            delta = delta,
            velocity_damping = settings.velocity_damping,
            position_x = x,
            position_y = y
        })
    end

    self._canvas_needs_update = true
end

--- @brief
function ow.PlayerRecorderBody:relax()
    for motion in range(
        self._up_pressed_motion,
        self._right_pressed_motion,
        self._down_pressed_motion,
        self._left_pressed_motion
    ) do
        motion:set_value(_NOT_PRESSED)
        motion:set_target_value(_NOT_PRESSED)
    end

    for rope in values(self._ropes) do
        for i = 1, #rope.current_positions do
            rope.last_positions[i] = rope.current_positions[i]
            rope.last_velocities[i] = 0
        end
    end
end

--- @brief
function ow.PlayerRecorderBody:set_position(x, y)
    self._body:set_position(x, y)
end

--- @brief
function ow.PlayerRecorderBody:get_position()
    return self._body:get_position()
end

--- @brief
function ow.PlayerRecorderBody:set_velocity(dx, dy)
    self._body:set_velocity(dx, dy)
end

--- @brief
function ow.PlayerRecorderBody:draw()
    local w, h = self._canvas:get_size()
    local position_x, position_y = self._body:get_position()

    if self._canvas_needs_update then
        love.graphics.push("all")
        love.graphics.reset()

        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(self._canvas_scale, self._canvas_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)

        love.graphics.translate(-position_x, -position_y)
        love.graphics.translate(0.5 * w, 0.5 * h)

        love.graphics.setColor(0, 0, 0,1)
        love.graphics.circle("fill", position_x, position_y, 10)

        love.graphics.setLineWidth(_settings.rope_thickness)
        love.graphics.setLineJoin("none")

        for rope in values(self._ropes) do
            local rope_i = 0
            for i = 1, #rope.current_positions, 2 do
                local v = rope_i / self._n_ropes * 0.2
                love.graphics.setColor(v, v, v, 1)

                if i < #rope.current_positions - 2 then
                    local x1, y1, x2, y2 = rope.current_positions[i+0], rope.current_positions[i+1], rope.current_positions[i+2], rope.current_positions[i+3]
                    love.graphics.line(x1, y1, x2, y2)
                end

                love.graphics.circle("fill",
                    rope.current_positions[i+0],
                    rope.current_positions[i+1],
                    _settings.rope_thickness
                )

                rope_i = rope_i + 1
            end
        end

        self._body:draw()

        self._canvas:unbind()
        love.graphics.pop()
        self._canvas_needs_update = false
    end

    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 1)
    local r = 2 * self._radius
    local x, y = self._body:get_position()

    --[[
    for motion_nx_ny in range(
        { self._up_pressed_motion, 0, -1 },
        { self._right_pressed_motion, 1, 0 },
        { self._down_pressed_motion, 0, 1 },
        { self._left_pressed_motion, -1, 0 }
    ) do
        local motion, nx, ny = table.unpack(motion_nx_ny)
        local v = motion:get_value()
        love.graphics.line(
            x,
            y,
            x + nx * r * v,
            y + ny * r * v
        )
    end
    ]]--

    self._body:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native(),
        position_x, position_y,
        0,
        1 / self._canvas_scale, 1 / self._canvas_scale,
        0.5 * w, 0.5 * h
    )

    _outline_shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native(),
        position_x, position_y,
        0,
        1 / self._canvas_scale, 1 / self._canvas_scale,
        0.5 * w, 0.5 * h
    )
    _outline_shader:unbind()
end