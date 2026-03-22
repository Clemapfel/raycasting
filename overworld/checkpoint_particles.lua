
rt.settings.overworld.checkpoint_particles = {
    -- default settings
    min_radius = 5,
    max_radius = 7,

    min_velocity = 300,
    max_velocity = 600,

    gravity = 50,

    min_mass = 1,
    max_mass = 1, -- fraction

    min_angle = 0,
    max_angle = 2 * math.pi,

    min_damping = 0.98,
    max_damping = 0.99,

    n_particles = 200,

    min_hue = 0,
    max_hue = 1,

    min_lifetime = 5,
    max_lifetime = 5,

    n_path_points = 20,

    min_tail_length_factor = 4, -- radius factor
    use_fill_color = true
}


--- @class ow.CheckpointParticles
ow.CheckpointParticles = meta.class("CheckpointParticles")

--- @brief
function ow.CheckpointParticles:instantiate()
    self._batches = {}
    self._bounds = rt.AABB(
        -math.huge,
        -math.huge,
        math.huge,
        math.huge
    )
end

--- @brief
function ow.CheckpointParticles:spawn(origin_x, origin_y, settings)
    settings = table.deepcopy(settings or rt.settings.overworld.checkpoint_particles)

    local batch = {
        particles = {},
        settings = settings
    }

    table.insert(self._batches, batch)

    -- fill in missing default setting keys
    for key, value in pairs(rt.settings.overworld.checkpoint_particles) do
        if settings[key] == nil then
            settings[key] = value
        end
    end

    self:_init_batch(batch, origin_x, origin_y, settings)
end

--- @brief
function ow.CheckpointParticles:update(delta)
    local to_remove = {}
    for i, batch in ipairs(self._batches) do
        if self:_update_batch(batch, delta) then
            table.insert(to_remove, 1, i)
        end
    end

    for i in values(to_remove) do
        table.remove(self._batches, i)
    end
end

--- @brief
function ow.CheckpointParticles:draw()
    for batch in values(self._batches) do
        self:_draw_batch(batch)
    end
end

--- @brief
function ow.CheckpointParticles:clear()
    self._batches = {}
end

--- @brief
function ow.CheckpointParticles:set_bounds(aabb_or_x, y, width, height)
    local aabb
    if meta.is_number(aabb_or_x) then
        local x = aabb_or_x
        meta.assert(x, "Number", y, "Number", width, "Number", height, "Number")
        self._bounds:reformat(x, y, width, height)
    else
        aabb = aabb_or_x
        meta.assert(aabb, rt.AABB)
        self._bounds:reformat(aabb:unpack())
    end
end

local _position_x = 1
local _position_y = 2
local _velocity_dx = 3
local _velocity_dy = 4
local _mass = 5
local _radius = 6
local _damping = 7
local _lifetime_elapsed = 8
local _lifetime = 9
local _color_r = 10
local _color_g = 11
local _color_b = 12
local _color_a = 13
local _is_disabled = 14
local _arc_min = 15
local _arc_max = 16
local _path = 17
local _path_length = 18
local _path_left_normals = 19
local _path_right_normals = 20
local _polygon = 21

--- @brief
function ow.CheckpointParticles:_init_batch(batch, origin_x, origin_y, settings)
    batch.particles = {}
    batch.settings = settings

    for _ = 1, settings.n_particles do
        local angle = rt.random.number(settings.min_angle, settings.max_angle)
        local dx = math.cos(angle)
        local dy = math.sin(angle)

        local hue = rt.random.number(settings.min_hue, settings.max_hue)
        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue, 1)
        local radius = rt.random.number(settings.min_radius, settings.max_radius)

        local lifetime = rt.random.number(settings.min_lifetime, settings.max_lifetime)
        if lifetime == math.huge then lifetime = 10e9 end -- prevent NaN

        local px, py = origin_x + dx * radius, origin_y + dy * radius
        local velocity_magnitude = rt.random.number(settings.min_velocity, settings.max_velocity)

        local particle = {
            [_position_x] = px,
            [_position_y] = py,
            [_velocity_dx] = dx * velocity_magnitude,
            [_velocity_dy] = dy * velocity_magnitude,
            [_mass] = rt.random.number(settings.min_mass, settings.max_mass),
            [_radius] = radius,
            [_damping] = rt.random.number(settings.min_damping, settings.max_damping),
            [_lifetime_elapsed] = 0,
            [_lifetime] = lifetime,
            [_color_r] = r,
            [_color_g] = g,
            [_color_b] = b,
            [_color_a] = a,
            [_is_disabled] = false,
            [_arc_min] = 0,
            [_arc_max] = 0,
            [_path] = {},
            [_path_length] = 0,
            [_path_left_normals] = {},
            [_path_right_normals] = {},
            [_polygon] = {},
        }

        local left_x, left_y = math.turn_left(dx, dy)
        local right_x, right_y = math.turn_right(dx, dy)
        for _ = 1, settings.n_path_points do
            table.insert(particle[_path], px)
            table.insert(particle[_path], py)
            table.insert(particle[_polygon], px)
            table.insert(particle[_polygon], py)
            table.insert(particle[_path_left_normals], left_x)
            table.insert(particle[_path_left_normals], left_y)
            table.insert(particle[_path_right_normals], right_x)
            table.insert(particle[_path_right_normals], right_y)
        end

        for i = 1, _polygon do
            assert(particle[i] ~= nil, i)
        end

        table.insert(batch.particles, particle)
    end
end

--- @brief
function ow.CheckpointParticles:_update_batch(batch, delta)
    local gravity_dx, gravity_dy, gravity = 0, 1, batch.settings.gravity
    local opacity_easing = rt.InterpolationFunctions.SINUSOID_EASE_OUT
    local tail_easing = rt.InterpolationFunctions.LINEAR
    local bounds = self._bounds
    local despawn_when_leaving_screen = batch.settings.despawn_when_leaving_screen

    local arc_offset = math.pi / 2
    local min_tail_length_factor = batch.settings.min_tail_length_factor
    local n_disabled = 0

    for particle_i, p in ipairs(batch.particles) do
        if p[_is_disabled] == true then
            n_disabled = n_disabled + 1
            goto continue
        end

        -- integrate position
        p[_velocity_dx] = p[_damping] * (p[_velocity_dx] + (gravity_dx * gravity * delta))
        p[_velocity_dy] = p[_damping] * (p[_velocity_dy] + (gravity_dy * gravity * delta))

        p[_position_x] = p[_position_x] + p[_velocity_dx] * delta
        p[_position_y] = p[_position_y] + p[_velocity_dy] * delta
        
        p[_lifetime_elapsed] = p[_lifetime_elapsed] + delta
        local lifetime_t = p[_lifetime_elapsed] / p[_lifetime]

        -- update color
        if p[_lifetime] ~= math.huge then
            p[_color_a] = opacity_easing(1 - math.min(1, lifetime_t))
        else
            p[_color_a] = 1
        end

        if lifetime_t >= 1 then
            p[_is_disabled] = true
            n_disabled = n_disabled + 1
            goto continue
        end

        -- update angle
        local angle = math.angle(p[_velocity_dx], p[_velocity_dy])
        p[_arc_min] = angle - arc_offset
        p[_arc_max] = angle + arc_offset

        -- append to path
        local path, left, right = p[_path], p[_path_left_normals], p[_path_right_normals]

        local removed_length = math.distance(path[1], path[2], path[3], path[4])
        table.remove(path, 1)
        table.remove(path, 1)

        table.insert(path, p[_position_x])
        table.insert(path, p[_position_y])

        local added_length = math.distance(path[#path-3], path[#path-2], path[#path-1], path[#path-0])
        p[_path_length] = p[_path_length] - removed_length + added_length

        -- append new normals
        local path_dx = path[#path-3] - path[#path-1]
        local path_dy = path[#path-2] - path[#path-0]
        path_dx, path_dy = math.normalize(path_dx, path_dy)

        table.remove(left, 1)
        table.remove(left, 1)
        local left_dx, left_dy = math.turn_left(path_dx, path_dy)
        table.insert(left, left_dx)
        table.insert(left, left_dy)

        table.remove(right, 1)
        table.remove(right, 1)
        local right_dx, right_dy = math.turn_right(path_dx, path_dy)
        table.insert(right, right_dx)
        table.insert(right, right_dy)

        -- rebuild polygon tail
        local polygon = p[_polygon]
        if p[_path_length] < min_tail_length_factor * p[_radius] then
            -- if too short, use default tri
            table.clear(polygon)

            local px, py = p[_position_x], p[_position_y]
            local vdx, vdy = math.normalize(p[_velocity_dx], p[_velocity_dy])

            local left_vx, left_vy = math.turn_left(vdx, vdy)
            local right_vx, right_vy = math.turn_right(vdx, vdy)

            local radius = p[_radius]

            table.insert(polygon, px + left_vx * radius)
            table.insert(polygon, py + left_vy * radius)

            table.insert(polygon, px - vdx * min_tail_length_factor * radius)
            table.insert(polygon, py - vdy * min_tail_length_factor * radius)

            table.insert(polygon, px + right_vx * radius)
            table.insert(polygon, py + right_vy * radius)
        else
            -- else, use entire path
            local radius = p[_radius]
            local n_nodes = #path / 2

            local node_i = 1
            local easing_i = 0
            for i = #left - 1, 1, -2 do
                local x, y = path[i+0], path[i+1]

                local width = tail_easing(1 - math.min(1, easing_i / n_nodes)) * radius
                easing_i = easing_i + 1

                polygon[node_i+0] = x + left[i+0] * width
                polygon[node_i+1] = y + left[i+1] * width
                node_i = node_i + 2
            end

            easing_i = easing_i - 1

            for i = 1, #right, 2 do
                local x, y = path[i+0], path[i+1]

                local width = tail_easing(1 - math.min(1, easing_i / n_nodes)) * radius
                easing_i = easing_i - 1

                polygon[node_i+0] = x + right[i+0] * width
                polygon[node_i+1] = y + right[i+1] * width
                node_i = node_i + 2
            end
        end

        ::continue::
    end

    return n_disabled >= #batch.particles
end

    --- @brief
function ow.CheckpointParticles:_draw_batch(batch)
    if batch.settings.use_fill_color == true then
        local fill_r, fill_g, fill_b, fill_a = rt.Palette.BLACK:unpack()
        for p in values(batch.particles) do
            love.graphics.setColor(fill_r, fill_g, fill_b, fill_a * p[_color_a])
            love.graphics.arc("fill", "closed",
                p[_position_x], p[_position_y],
                p[_radius],
                p[_arc_min], p[_arc_max]
            )
            love.graphics.polygon("fill", p[_polygon])

            love.graphics.setColor(p[_color_r], p[_color_g], p[_color_b], p[_color_a])
            love.graphics.arc("line", "open",
                p[_position_x], p[_position_y],
                p[_radius],
                p[_arc_min], p[_arc_max]
            )
            love.graphics.line(p[_polygon])
        end
    else
        for p in values(batch.particles) do
            love.graphics.setColor(p[_color_r], p[_color_g], p[_color_b], p[_color_a])
            love.graphics.polygon(p[_polygon])
            love.graphics.arc("fill", "closed",
                p[_position_x], p[_position_y],
                p[_radius],
                p[_arc_min], p[_arc_max]
            )
            love.graphics.polygon("fill", p[_polygon])
        end
    end
end

--- @brief
function ow.CheckpointParticles:collect_point_lights(callback)
    if true then return end
    for batch in values(self._batches) do
        for particle in values(batch.particles) do
            callback(
                particle[_position_x], particle[_position_y],
                particle[_radius],
                particle[_color_r], particle[_color_g], particle[_color_b], particle[_color_a]
            )
        end
    end
end