do
    local n_nodes = 32
    rt.settings.overworld.firefly_manager = {
        path_n_nodes = n_nodes,
        n_hues = 13,

        max_glow_offset = 0.5,
        min_glow_cycle_duration = n_nodes / 10 / 2,
        max_glow_cycle_duration = n_nodes / 10 * 2,

        min_hover_cycle_duration = n_nodes / 2 / 2,
        max_hover_cycle_duration = n_nodes / 2 * 2,

        min_noise_speed = 2 * 0.5,
        max_noise_speed = 2 * 1.5,

        min_repel_intensity = 100,
        max_repel_intensity = 200,
        repel_decay = 0.99,

        max_hover_offset = 18, -- px
        hover_cycle_duration = n_nodes / 2, -- seconds,

        min_radius_factor = 0.75,
        max_radius_factor = 1.25,
        n_radii = 7,

        max_follow_offset = 300,

        min_speed = 0.25, -- fraction
        max_speed = 1,
        speed_multiplier = 5,

        max_velocity = 70, -- px / s

        max_follow_target_offset = 2 * rt.settings.player.radius * rt.settings.player.bubble_radius_factor,

        composition_opacity = 1
    }
end

--- @class ow.FireflyManager
ow.FireflyManager = meta.class("FireflyManager")

local _possible_hues = nil -- Table<Number>
local _possible_radii = nil -- Table<Number>

local _glow_noise_path -- Path1D
local _hover_offset_path -- Path2D

local _batch_home_texture = nil
local _batch_home_texture_shader = rt.Shader("overworld/firefly_manager_batch_home_texture.glsl")

--- @brief
function ow.FireflyManager:instantiate(scene, stage)
    self._scene = scene
    self._stage = stage

    local settings = rt.settings.overworld.firefly_manager
    if _possible_hues == nil then
        _possible_hues = {}
        local n = settings.n_hues
        for i = 1, n do
            table.insert(_possible_hues, (i - 1) / n)
        end
    end

    if _possible_radii == nil then
        _possible_radii = {}
        local n = settings.n_radii

        for i = 1, n do
            table.insert(_possible_radii, math.mix(
                settings.min_radius_factor,
                settings.max_radius_factor,
                (i - 1) / (n - 1)
            )* rt.settings.overworld.fireflies.radius)
        end
    end

    local function randomize_parameterization(interval_start, interval_end, n, min_size)
        local interval_length = interval_end - interval_start
        local min_total = n * min_size

        local remaining_length = interval_length - min_total

        local split_points = {}
        for i = 1, n - 1 do
            split_points[i] = rt.random.number(0, remaining_length)
        end

        table.sort(split_points)

        local segments = {}
        local previous_point = 0
        for i = 1, n - 1 do
            segments[i] = (split_points[i] - previous_point) + min_size
            previous_point = split_points[i]
        end

        segments[n] = (remaining_length - previous_point) + min_size
        return table.unpack(segments)
    end

    local n_path_nodes = settings.path_n_nodes
    if _glow_noise_path == nil then
        local values = {}
        for i = 1, n_path_nodes do
            table.insert(values, rt.random.number(
                1 - settings.max_glow_offset,
                1
            ))
        end

        table.insert(values, values[1])
        _glow_noise_path = rt.Path1D(values)
        _glow_noise_path:override_parameterization(randomize_parameterization(
            0, 1, n_path_nodes, 0
        ))
    end

    if _hover_offset_path == nil then
        local points = {}
        local max_offset = settings.max_hover_offset
        for i = 1, n_path_nodes do
            table.insert(points, rt.random.number(-max_offset, max_offset))
            table.insert(points, rt.random.number(-max_offset, max_offset))
        end

        table.insert(points, points[1])
        table.insert(points, points[2])
        _hover_offset_path = rt.Path2D(points)
        _hover_offset_path:override_parameterization(randomize_parameterization(
            0, 1, n_path_nodes, 1 / n_path_nodes
        ))
    end

    require "overworld.firefly_particle_texture_atlas"
    stage.firefly_particle_texture_atlas = ow.FireflyParticleTextureAtlas(
        _possible_hues,
        _possible_radii
    )

    if _batch_home_texture == nil then
        local r = settings.max_hover_offset + 3 -- padding
        _batch_home_texture = rt.RenderTexture(
            2 * r,
            2 * r
        )

        love.graphics.push("all")
        love.graphics.reset()
        _batch_home_texture:bind()
        _batch_home_texture_shader:bind()
        love.graphics.rectangle("fill", 0, 0, _batch_home_texture:get_size())
        _batch_home_texture_shader:unbind()
        _batch_home_texture:unbind()
        love.graphics.pop()
    end

    self._current_batch_id = 0
    self._n_particles = 0
    self._current_follow_offset = 0
    self._data = {}
    self._batch_id_to_entry = {}
    self._index_order = {}
    self._visible_data_is = {} -- data offset, not particle i
    self._data_i_to_rgba = {}
end

local STATE_IDLE, STATE_FOLLOWING, STATE_REPELLING = 0, 1, 2
local FALSE, TRUE = 0, 1

local _x_offset = 0
local _y_offset = 1
local _speed_offset = 2
local _state_offset = 3
local _noise_position_offset = 4
local _noise_speed_offset = 5
local _glow_offset_t_offset = 6
local _glow_cycle_duration_offset = 7
local _glow_elapsed_offset = 8
local _glow_value_offset = 9
local _hover_offset_t_offset = 10
local _hover_cycle_duration_offset = 11
local _hover_elapsed_offset = 12
local _follow_offset = 13
local _repel_target_x_offset = 14
local _repel_target_y_offset = 15
local _repel_intensity_offset = 16
local _should_move_in_place_offset = 17
local _radius_offset = 18
local _hue_offset = 19
local _home_x_offset = 20
local _home_y_offset = 21
local _follow_target_offset_x = 22
local _follow_target_offset_y = 23
local _batch_id_offset = 24

local _stride = _batch_id_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

--- @brief
function ow.FireflyManager:register(x, y, count, should_move_in_place)
    local batch_id = self._current_batch_id
    self._current_batch_id = self._current_batch_id + 1

    local settings = rt.settings.overworld.firefly_manager
    local data = self._data

    local add = function(batch_id, home_x, home_y, should_move_in_place)
        local hue = rt.random.choose(_possible_hues)
        local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, hue, 1)

        home_x = home_x + rt.random.number(-settings.max_hover_offset, settings.max_hover_offset)
        home_y = home_y + rt.random.number(-settings.max_hover_offset, settings.max_hover_offset)

        local i = #data + 1
        data[i + _x_offset] = home_x
        data[i + _y_offset] = home_y
        data[i + _speed_offset] = settings.speed_multiplier * rt.random.number(settings.min_speed, settings.max_speed)
        data[i + _state_offset] = STATE_IDLE

        data[i + _noise_position_offset] = rt.random.number(-10e6, 10e6)
        data[i + _noise_speed_offset] = rt.random.number(
            settings.min_noise_speed,
            settings.max_noise_speed
        )

        data[i + _glow_elapsed_offset] = 0
        data[i + _glow_cycle_duration_offset] = rt.random.number(
            settings.min_glow_cycle_duration,
            settings.max_glow_cycle_duration
        )
        data[i + _glow_offset_t_offset] = rt.random.number(0, 1)
        data[i + _glow_value_offset] = 0

        data[i + _hover_offset_t_offset] = rt.random.number(0, 1)
        data[i + _hover_cycle_duration_offset] = rt.random.number(
            settings.min_hover_cycle_duration,
            settings.max_hover_cycle_duration
        )
        data[i + _hover_elapsed_offset] = 0

        data[i + _follow_offset] = 0 -- updated on notify_collected_by_player
        data[i + _repel_target_x_offset] = 0
        data[i + _repel_target_y_offset] = 0
        data[i + _repel_intensity_offset] = math.max(1, rt.random.number(
            settings.min_repel_intensity,
            settings.max_repel_intensity
        ))

        data[i + _should_move_in_place_offset] = ternary(should_move_in_place, TRUE, FALSE)

        data[i + _radius_offset] = rt.random.choose(_possible_radii)

        data[i + _hue_offset] = hue
        data[i + _home_x_offset] = home_x
        data[i + _home_y_offset] = home_y

        local angle = rt.random.number(0, 2 * math.pi)
        local magnitude = rt.random.number(-settings.max_follow_target_offset, settings.max_follow_target_offset)
        data[i + _follow_target_offset_x] = math.cos(angle) * magnitude
        data[i + _follow_target_offset_y] = math.sin(angle) * magnitude
        data[i + _batch_id_offset] = batch_id

        assert(#data - i == _stride - 1)

        self._data_i_to_rgba[i] = rt.RGBA(r, g, b, 1)
        self._n_particles = self._n_particles + 1
        return self._n_particles, hue
    end

    for _ = 1, count do
        local particle_index, hue = add(batch_id, x, y, should_move_in_place)
        local entry = self._batch_id_to_entry[batch_id]
        if entry == nil then
            entry = {
                indices = {},
                x = x,
                y = y,
                is_collected = false
            }
            entry.indices = {}
            entry.hues = {}
            self._batch_id_to_entry[batch_id] = entry
        end

        table.insert(entry.indices, particle_index)
    end

    return batch_id
end

--- @brief
function ow.FireflyManager:notify_collected_by_player(id)
    local entry = self._batch_id_to_entry[id]
    if entry == nil then
        rt.error("In ow.FireflyManager.notify_collected_by_player: no batch with id `", id, "`")
    end

    for particle_i in values(entry.indices) do
        local i = _particle_i_to_data_offset(particle_i)
        if self._data[i + _state_offset] ~= STATE_FOLLOWING then
            self._data[i + _state_offset] = STATE_FOLLOWING
            table.insert(self._index_order, particle_i)
            self._scene:get_player():pulse(rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._data[i + _hue_offset], 1)))
        end
    end

    entry.is_collected = true

    for particle_i in values(self._index_order) do
        local i = _particle_i_to_data_offset(particle_i)
        self._data[i + _follow_offset] = 1 - ((particle_i - 1) / #self._index_order)
    end
end

--- @brief
function ow.FireflyManager:notify_reset(id)
    local entry = self._batch_id_to_entry[id]
    if entry == nil then
        rt.error("In ow.FireflyManager.notify_collected_by_player: no batch with id `", id, "`")
    end

    local data = self._data
    local indices_set = {}

    for particle_i in values(entry.indices) do
        local i = _particle_i_to_data_offset(particle_i)
        data[i + _state_offset] = STATE_IDLE
        data[i + _x_offset] = data[i + _home_x_offset]
        data[i + _y_offset] = data[i + _home_y_offset]

        indices_set[particle_i] = true
    end

    entry.is_collected = false

    local new_index_order = {}
    for particle_i in values(self._index_order) do
        if not indices_set[particle_i] then
            table.insert(new_index_order, particle_i)
        end
    end
    self._index_order = new_index_order
end

--- @brief
function ow.FireflyManager:update(delta)
    local settings = rt.settings.overworld.firefly_manager
    local player_radius = rt.settings.player.radius
    local core_radius_factor = rt.settings.overworld.firefly_particle.core_radius_factor
    local px, py = self._scene:get_player():get_position()

    local path =  self._scene:get_player():get_past_position_path()
    local max_path_t = math.min(1, settings.max_follow_offset / path:get_length())

    local data = self._data
    local radius = rt.settings.overworld.fireflies.radius

    local distance_easing = function(x)
        return math.sqrt(x)
    end

    local padding = rt.settings.overworld.firefly_manager.max_radius_factor * rt.settings.overworld.fireflies.radius
    local bounds_x, bounds_y, bounds_w, bounds_h = self._scene:get_camera():get_world_bounds():unpack()
    bounds_x = bounds_x - padding
    bounds_y = bounds_y - padding
    bounds_w = bounds_w + 2 * padding
    bounds_h = bounds_h + 2 * padding

    local repel_decay = settings.repel_decay
    local speed_multiplier = settings.speed_multiplier
    local max_velocity = settings.max_velocity

    table.clear(self._visible_data_is)
    local is_in_bounds = function(x, y)
        return x >= bounds_x
            and y >= bounds_y
            and x <= bounds_x + bounds_w
            and y <= bounds_y + bounds_h
    end

    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)

        local state = data[i + _state_offset]
        local x, y = data[i + _x_offset], data[i + _y_offset]

        local noise_position = data[i + _noise_position_offset]
        data[i + _noise_position_offset] = noise_position + data[i + _noise_speed_offset] * delta

        if is_in_bounds(x, y) then table.insert(self._visible_data_is, i) end

        -- find target
        local target_x, target_y
        if state == STATE_FOLLOWING then
            target_x, target_y = path:at(math.mix(0, max_path_t, data[i + _follow_offset]))

            local dx, dy = data[i + _repel_target_x_offset], data[i + _repel_target_y_offset]
            target_x = target_x + dx + data[i + _follow_target_offset_x]
            target_y = target_y + dy + data[i + _follow_target_offset_y]

            local magnitude = math.magnitude(dx, dy) * repel_decay
            dx, dy = math.normalize(dx, dy)

            data[i + _repel_target_x_offset] = dx * magnitude
            data[i + _repel_target_y_offset] = dy * magnitude
        elseif state == STATE_IDLE then
            target_x = data[i + _home_x_offset]
            target_y = data[i + _home_y_offset]

            if not (
                x >= bounds_x
                and y >= bounds_y
                and x <= bounds_x + bounds_w
                and y <= bounds_y + bounds_h
            ) then
                goto next_particle
            end
        end

        -- hover
        if data[i + _should_move_in_place_offset] == TRUE then
            local hover_elapsed = data[i + _hover_elapsed_offset]
            data[i + _hover_elapsed_offset] = hover_elapsed + delta
            local hover_x, hover_y = _hover_offset_path:at(
                math.fract(
                    hover_elapsed / data[i + _hover_cycle_duration_offset]
                        + data[i + _hover_offset_t_offset]
                )
            )

            target_x = target_x + hover_x
            target_y = target_y + hover_y
        end

        do
            local distance_x = target_x - x
            local distance_y = target_y - y

            local dx, dy = math.normalize(distance_x, distance_y)
            local distance = math.magnitude(distance_x, distance_y)

            local eased_speed = speed_multiplier * distance_easing(distance) * data[i + _speed_offset]
            eased_speed = math.min(eased_speed, data[i + _speed_offset] * max_velocity)

            x = x + dx * eased_speed * delta
            y = y + dy * eased_speed * delta
        end

        -- resolve player overlap
        if state == STATE_FOLLOWING then
            local dx = x - px
            local dy = y - py
            local distance = math.magnitude(dx, dy)

            local min_distance = player_radius + core_radius_factor * data[i + _radius_offset] * 2
            if distance < min_distance and distance > math.eps then
                local nx, ny = math.normalize(dx, dy)
                local push = min_distance - distance

                x = x + push
                y = y + push

                local repel_intensity = data[i + _repel_intensity_offset]
                data[i + _repel_target_x_offset] = nx * repel_intensity
                data[i + _repel_target_y_offset] = ny * repel_intensity
            end
        end

        data[i + _x_offset] = x
        data[i + _y_offset] = y

        do -- glow
            local glow_elapsed = data[i + _glow_elapsed_offset]
            data[i + _glow_elapsed_offset] = glow_elapsed + delta
            data[i + _glow_value_offset] = _glow_noise_path:at(
                math.fract(
                    glow_elapsed / data[i + _glow_cycle_duration_offset]
                    + data[i + _glow_offset_t_offset]
                )
            )
        end

        ::next_particle::
    end
end

--- @brief
function ow.FireflyManager:draw()
    love.graphics.push("all")

    local data = self._data
    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.NORMAL)
    love.graphics.setLineWidth(2)
    love.graphics.setLineStyle("smooth")
    local black_r, black_b, black_g = rt.Palette.BLACK:unpack()
    local core_radius = rt.settings.overworld.firefly_particle.core_radius_factor
    local composition_opacity = rt.settings.overworld.firefly_manager.composition_opacity

    for _, i in ipairs(self._visible_data_is) do
        local alpha = data[i + _glow_value_offset] * composition_opacity
        love.graphics.setColor(alpha, alpha, alpha, alpha)
        love.graphics.circle("fill",
            data[i + _x_offset],
            data[i + _y_offset],
            data[i + _radius_offset] * core_radius
        )

        love.graphics.setColor(black_r, black_b, black_g, 1)
        love.graphics.circle("line",
            data[i + _x_offset],
            data[i + _y_offset],
            data[i + _radius_offset] * core_radius
        )
    end

    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.NORMAL)
    rt.Palette.TRUE_WHITE:bind()

    local atlas = self._stage.firefly_particle_texture_atlas
    for _, i in ipairs(self._visible_data_is) do
        local alpha = data[i + _glow_value_offset] * composition_opacity
        love.graphics.setColor(1, 1, 1, 1)
        atlas:draw(
            data[i + _hue_offset],
            data[i + _radius_offset],
            data[i + _x_offset],
            data[i + _y_offset]
        )
    end

    love.graphics.pop()
end

--- @brief
function ow.FireflyManager:reset()
    self._current_batch_id = 0
    self._n_particles = 0
    self._current_follow_offset = 0
    self._data = {}
    self._batch_id_to_entry = {}
    self._index_order = {}
    self._visible_data_is = {}
    self._data_i_to_rgba = {}
end

--- @brief
function ow.FireflyManager:get_point_light_sources()
    local data = self._data
    local core_radius_factor = rt.settings.overworld.firefly_particle.core_radius_factor

    local circles, colors = {}, {}
    for _, i in ipairs(self._visible_data_is) do
        table.insert(circles, {
            data[i + _x_offset],
            data[i + _y_offset],
            data[i + _radius_offset] * core_radius_factor
        })
        
        table.insert(colors, self._data_i_to_rgba[i])
    end

    return circles, colors
end 