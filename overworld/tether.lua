require "common.player_body"
require "common.path"

rt.settings.overworld.tether = {
    segment_length = 4,
    min_n_nodes = 3,
    max_n_nodes = 1024,
    length_overshoot = 1.1, -- fraction
    line_width = 3,

    n_sub_steps = 2,
    n_constraint_iterations = 4,
    bending_compliance = 0,
    distance_compliance = 0.001,
    damping = 1 - 0.5,
    gravity = 1000
}

--- @class ow.Tether
ow.Tether = meta.class("Tether")

--- @brief
function ow.Tether:instantiate()
    self._particle_data = {}
    self._n_particles = 0
    self._is_tethered = false
    self._path = nil -- rt.Path

    self._from_x, self._from_y = 0, 0
    self._to_x, self._to_y = 0, 0
end

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2 -- last sub step
local _previous_y_offset = 3
local _velocity_x_offset = 4
local _velocity_y_offset = 5
local _mass_offset = 6
local _inverse_mass_offset = 7
local _segment_length_offset = 8
local _distance_lambda_offset = 9
local _bending_lambda_offset = 10

local _stride = _bending_lambda_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end

--- @brief
function ow.Tether:tether(attachment_x, attachment_y, target_x, target_y)
    meta.assert(attachment_x, "Number", attachment_y, "Number")

    local settings = rt.settings.overworld.tether
    local length = math.distance(attachment_x, attachment_y, target_x, target_y) * settings.length_overshoot

    local step = settings.segment_length
    local new_n_particles = math.clamp(
        math.ceil(length / step),
        settings.min_n_nodes,
        settings.max_n_nodes
    )
    local data = self._particle_data
    self._path_needs_update = self._n_particles ~= new_n_particles
    self._is_tethered = true

    local mass_easing = function(i, n)
        return 1
    end

    self._from_x, self._from_y = attachment_x, attachment_y
    self._to_x, self._to_y = target_x, target_y

    if self._n_particles < new_n_particles then -- grow

        if true then --rt.GameState:get_is_performance_mode_enabled() then
            -- allocate points in a straight line starting from current end

            local dx, dy = math.normalize(target_x - attachment_x, target_y - attachment_y)

            -- start position
            local x, y
            if self._n_particles == 0 then
                x, y = attachment_x, attachment_y
            else
                local i = _particle_i_to_data_offset(self._n_particles)
                x = data[i + _x_offset]
                y = data[i + _y_offset]
            end

            -- allocate new nodes, leave old alone
            for particle_i = self._n_particles + 1, new_n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local t = (particle_i - 1) / new_n_particles
                data[i + _x_offset] = x
                data[i + _y_offset] = y
                data[i + _previous_x_offset] = x
                data[i + _previous_y_offset] = y
                data[i + _velocity_x_offset] = 0
                data[i + _velocity_y_offset] = 0

                local mass = mass_easing(i, new_n_particles)
                data[i + _mass_offset] = mass
                data[i + _inverse_mass_offset] = 1 / mass
                data[i + _segment_length_offset] = step

                data[i + _distance_lambda_offset] = 0
                data[i + _bending_lambda_offset] = 0

                x = x + dx * step
                y = y + dy * step
            end
        else
            -- fit spline through all current points, use it for continuation
            local points = self:as_path():get_points()
            table.insert(points, target_x)
            table.insert(points, target_y)
            local spline = rt.Spline(points)

            for particle_i = 1, new_n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local t = (particle_i - 1) / new_n_particles
                local x, y = spline:at(t)
                data[i + _x_offset] = x
                data[i + _y_offset] = y
                data[i + _previous_x_offset] = x
                data[i + _previous_y_offset] = y
                data[i + _velocity_x_offset] = 0
                data[i + _velocity_y_offset] = 0

                local mass = mass_easing(i, new_n_particles)
                data[i + _mass_offset] = mass
                data[i + _inverse_mass_offset] = 1 / mass
                data[i + _segment_length_offset] = step

                if particle_i > self._n_particles then
                    data[i + _distance_lambda_offset] = 0
                    data[i + _bending_lambda_offset] = 0
                end
            end
        end

        self._n_particles = new_n_particles
    end

    -- shrink if necessary
    while self._n_particles > new_n_particles do
        local last_i = _particle_i_to_data_offset(self._n_particles)
        for offset = 1, _stride - 1 do
            data[last_i + offset] = nil
        end
        self._n_particles = self._n_particles - 1
    end

    return self
end

--- @brief
function ow.Tether:untether()
    self._is_tethered = false

    return self
end

--- @brief
function ow.Tether:update(delta)
    if self._is_tethered == false then return end

    local body_settings = rt.settings.player_body.non_contour
    local tether_settings = rt.settings.overworld.tether
    local damping = tether_settings.damping or body_settings.damping
    local n_sub_steps = tether_settings.n_sub_steps or body_settings.n_sub_steps
    local n_constraint_iterations = tether_settings.n_constraint_iterations or body_settings.n_constraint_iterations
    local sub_delta = delta / n_sub_steps

    local distance_alpha = (tether_settings.bending_compliance or body_settings.distance_compliance) / (sub_delta^2)
    local bending_alpha = (tether_settings.bending_compliance or body_settings.bending_compliance) / (sub_delta^2)

    local data = self._particle_data
    local n_particles = self._n_particles

    local gravity_dx, gravity_dy = 0, 1
    local gravity = tether_settings.gravity or body_settings.gravity

    local pre_solve = rt.PlayerBody._pre_solve
    local post_solve = rt.PlayerBody._post_solve
    local enforce_distance = rt.PlayerBody._enforce_distance
    local enforce_bending = rt.PlayerBody._enforce_bending

    for _ = 1, n_sub_steps do
        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local new_x, new_y, new_vx, new_vy, prev_x, prev_y, dist_lambda, bend_lambda, _ = pre_solve(
                data[i + _x_offset],
                data[i + _y_offset],
                data[i + _velocity_x_offset],
                data[i + _velocity_y_offset],
                data[i + _mass_offset],
                gravity_dx * gravity, gravity_dy * gravity,
                0, 0, -- relative velocity unused
                damping, sub_delta
            )

            data[i + _x_offset] = new_x
            data[i + _y_offset] = new_y
            data[i + _velocity_x_offset] = new_vx
            data[i + _velocity_y_offset] = new_vy
            data[i + _previous_x_offset] = prev_x
            data[i + _previous_y_offset] = prev_y
            data[i + _distance_lambda_offset] = dist_lambda
            data[i + _bending_lambda_offset] = bend_lambda
        end

        for _ = 1, n_constraint_iterations do
            -- distance
            for node_i = 1, self._n_particles - 1, 1 do
                local i1 = _particle_i_to_data_offset(node_i + 0)
                local i2 = _particle_i_to_data_offset(node_i + 1)

                local ax, ay = data[i1 + _x_offset], data[i1 + _y_offset]
                local bx, by = data[i2 + _x_offset], data[i2 + _y_offset]

                local inverse_mass_a = data[i1 + _inverse_mass_offset]
                local inverse_mass_b = data[i2 + _inverse_mass_offset]

                local segment_length = data[i1 + _segment_length_offset]

                local axc, ayc, bxc, byc, lambda_new = enforce_distance(
                    ax, ay, bx, by,
                    inverse_mass_a, inverse_mass_b,
                    segment_length,
                    distance_alpha,
                    data[i1 + _distance_lambda_offset]
                )

                data[i1 + _x_offset] = ax + axc
                data[i1 + _y_offset] = ay + ayc
                data[i2 + _x_offset] = bx + bxc
                data[i2 + _y_offset] = by + byc
                data[i1 + _distance_lambda_offset] = lambda_new
            end

            -- bending
            for node_i = 1, self._n_particles - 2, 1 do
                local i1 = _particle_i_to_data_offset(node_i + 0)
                local i2 = _particle_i_to_data_offset(node_i + 1)
                local i3 = _particle_i_to_data_offset(node_i + 2)

                local ax, ay = data[i1 + _x_offset], data[i1 + _y_offset]
                local bx, by = data[i2 + _x_offset], data[i2 + _y_offset]
                local cx, cy = data[i3 + _x_offset], data[i3 + _y_offset]

                local inverse_mass_a = data[i1 + _inverse_mass_offset]
                local inverse_mass_b = data[i2 + _inverse_mass_offset]
                local inverse_mass_c = data[i3 + _inverse_mass_offset]

                local segment_length_ab = data[i1 + _segment_length_offset]
                local segment_length_bc = data[i2 + _segment_length_offset]
                local target_length = segment_length_ab + segment_length_bc

                local correction_ax, correction_ay, _, _, correction_cx, correction_cy, lambda_new = enforce_bending(
                    ax, ay, bx, by, cx, cy,
                    inverse_mass_a, inverse_mass_b, inverse_mass_c,
                    target_length,
                    bending_alpha,
                    data[i1 + _bending_lambda_offset]
                )

                data[i1 + _x_offset] = ax + correction_ax
                data[i1 + _y_offset] = ay + correction_ay
                data[i3 + _x_offset] = cx + correction_cx
                data[i3 + _y_offset] = cy + correction_cy
                data[i1 + _bending_lambda_offset] = lambda_new
            end

            -- realign first and last
            local first_i, last_i = _particle_i_to_data_offset(1), _particle_i_to_data_offset(self._n_particles)
            data[first_i + _x_offset] = self._from_x
            data[first_i + _y_offset] = self._from_y
            data[first_i + _previous_x_offset] = self._from_x
            data[first_i + _previous_y_offset] = self._from_y

            data[last_i + _x_offset] = self._to_x
            data[last_i + _y_offset] = self._to_y
            data[last_i + _previous_x_offset] = self._to_x
            data[last_i + _previous_y_offset] = self._to_y
        end

        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local new_vx, new_vy = post_solve(
                data[i + _x_offset],
                data[i + _y_offset],
                data[i + _previous_x_offset],
                data[i + _previous_y_offset],
                sub_delta
            )

            data[i + _velocity_x_offset] = new_vx
            data[i + _velocity_y_offset] = new_vy
        end
    end -- n sub steps

    self._path_needs_update = true
end

--- @brief
function ow.Tether:draw()
    if self._is_tethered == false or self._n_particles <= 0 then return end

    love.graphics.push()

    local r, g, b, a = love.graphics.getColor()
    local points = self:as_path():get_points()
    local first_i, last_i = _particle_i_to_data_offset(1), _particle_i_to_data_offset(self._n_particles)

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineStyle("rough")

    local line_width = rt.settings.overworld.tether.line_width
    love.graphics.setLineWidth(line_width + 1.5)
    rt.Palette.BLACK:bind()
    love.graphics.line(points)

    love.graphics.circle("fill",
        self._particle_data[first_i + _x_offset],
        self._particle_data[first_i + _y_offset],
        line_width + 1.5
    )

    love.graphics.circle("fill",
        self._particle_data[last_i + _x_offset],
        self._particle_data[last_i + _y_offset],
        line_width + 1.5
    )

    love.graphics.setLineWidth(line_width)
    love.graphics.setColor(r, g, b, a)
    love.graphics.line(points)

    love.graphics.circle("fill",
        self._particle_data[first_i + _x_offset],
        self._particle_data[first_i + _y_offset],
        line_width
    )

    love.graphics.circle("fill",
        self._particle_data[last_i + _x_offset],
        self._particle_data[last_i + _y_offset],
        line_width
    )

    love.graphics.pop()
end

--- @brief
function ow.Tether:draw_bloom()
    if self._is_tethered == false or self._n_particles <= 0 then return end

    love.graphics.push()

    local r, g, b, a = love.graphics.getColor()
    local points = self:as_path():get_points()
    local first_i, last_i = _particle_i_to_data_offset(1), _particle_i_to_data_offset(self._n_particles)

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineStyle("rough")

    local line_width = 1 --rt.settings.overworld.tether.line_width / 2

    love.graphics.setLineWidth(line_width)
    love.graphics.setColor(r, g, b, a)
    love.graphics.line(points)

    love.graphics.circle("fill",
        self._particle_data[first_i + _x_offset],
        self._particle_data[first_i + _y_offset],
        line_width
    )

    love.graphics.circle("fill",
        self._particle_data[last_i + _x_offset],
        self._particle_data[last_i + _y_offset],
        line_width
    )

    love.graphics.pop()
end

--- @brief
function ow.Tether:as_path()
    if self._path == nil or self._path_needs_update then
        local points = {}
        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            table.insert(points, self._particle_data[i + _x_offset])
            table.insert(points, self._particle_data[i + _y_offset])
        end

        self._path = rt.Path(points)
    end

    return self._path
end

--- @brief
function ow.Tether:get_is_tethered()
    return self._is_tethered
end