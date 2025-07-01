require "common.render_texture"

rt.settings.menu.selection_particle_frame = {
    density = 1 / 50, -- particles per px
    max_scale_factor = 1.5,
    max_velocity = 100, -- px / s
    hold_velocity = 10
}

--- @class mn.SelectionParticleFrame
mn.SelectionParticleFrame = meta.class("SelectionParticleFrame", rt.Widget)

local _particle_shader, _outline_shader

local _particle_mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

local _data_mesh_format = {
    { location = 3, name = "offset", format = "floatvec2" },
    { location = 4, name = "radius", format = "float" }
}

local _mask_mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

-- particle and data mesh indices
local _x = 1
local _y = 2
local _radius = 3
local _origin_x = 4
local _origin_y = 5
local _velocity_x = 6
local _velocity_y = 7
local _velocity_magnitude = 8
local _edge = 9

-- sim modes
local _MODE_COLLAPSE = 1
local _MODE_EXPAND = 2
local _MODE_HOLD = 3
local _MODE_SWIPE = 4

--- @brief
function mn.SelectionParticleFrame:instantiate(n_pages)
    meta.assert(n_pages, "Number")
    if _particle_shader == nil then _particle_shader = rt.Shader("menu/selection_particle_frame_particle.glsl") end
    if _outline_shader == nil then _outline_shader = rt.Shader("menu/selection_particle_frame_outline.glsl") end

    self._particles = {}
    self._canvas = nil -- rt.RenderTexture
    self._is_initialized = false
    self._mode = _MODE_HOLD

    self._n_pages = n_pages
    self._current_page = 1

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "space" then
            if self._mode == _MODE_EXPAND or self._mode == _MODE_HOLD then
                self._mode = _MODE_COLLAPSE
            elseif self._mode == _MODE_COLLAPSE then
                self._mode = _MODE_EXPAND
            end
        elseif which == "up" then
            if self._current_page > 1 then
                self._current_page = self._current_page - 1
                self._mode = _MODE_SWIPE
            end
        elseif which == "down" then
            if self._current_page < self._n_pages then
                self._current_page = self._current_page + 1
                self._mode = _MODE_SWIPE
            end
        elseif which == "b" then
            self:_set_mode(_MODE_EXPAND)
        end
    end)
end

--- @brief
function mn.SelectionParticleFrame:size_allocate(x, y, width, height)
    self._pages = {}

    if self._canvas == nil or self._canvas:get_width() ~= width or self._canvas.get_height() ~= height then
        local x, y = 0, 0 -- sic
        self._top = { x, y, x + width, y }
        self._right = { x + width, y, x + width, y + height }
        self._bottom = { x + width, y + height, x, y + height,  }
        self._left = { x, y + height, x, y }

        local particle_mesh_data
        do
            particle_mesh_data = {
                { 0, 0, 1, 1, 1, 1 }
            }

            local step = (2 * math.pi) / 16
            for angle = 0, 2 * math.pi + step, step  do
                table.insert(particle_mesh_data, {
                    math.cos(angle),
                    math.sin(angle),
                    1, 1, 1, 0
                })
            end
        end

        -- init particles
        local density = rt.settings.menu.selection_particle_frame.density
        local radius_factor = rt.settings.menu.selection_particle_frame.max_scale_factor

        self._pages = {} --[[
            particles
            n_particles
            data_mesh_data
            data_mesh
            particle_mesh
            mask
        ]]--

        local max_particle_r = -math.huge
        local center_x, center_y = x + 0.5 * width, y + 0.5 * height
        self._center_x, self._center_y = center_x, center_y
        self._page_size = height

        for page_i = 1, self._n_pages do
            local particles = {}
            local n_particles = 0
            local data_mesh_data = {}

            for edge in range(
                self._top, self._right, self._bottom, self._left
            ) do
                local ax, ay, bx, by = table.unpack(edge)
                local length = math.distance(ax, ay, bx, by)
                n_particles = math.ceil(density * length)
                local particle_radius = (length / n_particles)
                n_particles = 2 * n_particles
                local dx, dy = math.normalize(bx - ax, by - ay)

                for i = 0, n_particles - 1 do
                    local fraction = i / n_particles
                    local px, py = ax + dx * fraction * length, ay + dy * fraction * length
                    local radius = rt.random.number(particle_radius, radius_factor * particle_radius)
                    local particle = {
                        [_edge] = edge,
                        [_radius] = radius,
                        [_origin_x] = px,
                        [_origin_y] = py,
                        [_velocity_x] = math.cos(rt.random.number(0, 2 * math.pi)),
                        [_velocity_y] = math.sin(rt.random.number(0, 2 * math.pi)),
                        [_velocity_magnitude] = rt.random.number(1, 2)
                    }

                    if self._mode == _MODE_EXPAND then
                        particle[_x] = center_x
                        particle[_y] = center_y
                    else
                        particle[_x] = px
                        particle[_y] = py
                    end

                    table.insert(data_mesh_data, {
                        px, py, radius
                    })

                    table.insert(self._particles, particle)
                    n_particles = n_particles + 1
                    max_particle_r = math.max(max_particle_r, radius)
                end
            end

            local data_mesh = rt.Mesh(
                data_mesh_data,
                rt.MeshDrawMode.POINTS,
                _data_mesh_format,
                rt.GraphicsBufferUsage.DYNAMIC
            )

            local particle_mesh = rt.Mesh(
                particle_mesh_data,
                rt.MeshDrawMode.TRIANGLE_FAN,
                _particle_mesh_format,
                rt.GraphicsBufferUsage.STATIC
            )

            self._particle_mesh:attach_attribute(self._data_mesh, _data_mesh_format[1].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
            self._particle_mesh:attach_attribute(self._data_mesh, _data_mesh_format[2].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)

            self._pages[page_i] = {
                particles = particles,
                n_particles = n_particles,
                data_mesh_data = data_mesh_data,
                particle_mesh = particle_mesh,
                data_mesh = data_mesh,
                mask = {0, 0, 1, 1, 0.5, 0.5}
            }
        end

        local padding = 20 + 2 * max_particle_r
        self._canvas = rt.RenderTexture(width + 2 * padding, height + 2 * padding)
        self._canvas_padding = padding
    end

    self._x, self._y = x, y
    self._is_initialized = true
end

--- @brief
function mn.SelectionParticleFrame:_get_active_pages()
    if self._mode == _MODE_SWIPE then
        local out = {}
        if self._current_page > 1 then
            table.insert(out, self._current_page - 1)
        end

        if self._current_page < self._n_pages then
            table.insert(out, self._current_page + 1)
        end

        return out
    else
        return { self._current_page }
    end
end

--- @brief
function mn.SelectionParticleFrame:update(delta)
    if not self._is_initialized then return end

    local distance_threshold = 10
    local y_offset = self._swipe_offset * self._swipe_step

    for page_i in values(self:_get_active_pages()) do
        local page = self._pages[page_i]
        local particles = page.particles
        local data_mesh_data = page.data_mesh_data
        local n_particles = page.n_particles

        if self._mode == _MODE_EXPAND then
            -- move towards outer frame
            mask = {}
            local average_distance = 0
            for i, particle in ipairs(particles) do
                local x, y = particle[_x], particle[_y]
                local target_x, target_y = particle[_origin_x], particle[_origin_y] + y_offset
                local dx, dy = target_x - x, target_y - y
                local magnitude = particle[_velocity_magnitude]
                x = x + dx * delta * magnitude
                y = y + dy * delta * magnitude

                particle[_x], particle[_y] = x, y

                local data = data_mesh_data[i]
                data[_x] = x
                data[_y] = y

                table.insert(mask, x)
                table.insert(mask, y)
                average_distance = average_distance + math.distance(target_x, target_y, x, y)
            end
            average_distance = average_distance / n_particles
            if average_distance < distance_threshold then self._mode = _MODE_HOLD end

        elseif self._mode == _MODE_COLLAPSE then
            -- move towards center
            mask = {}
            local average_distance = 0
            for i, particle in ipairs(particles) do
                local x, y = particle[_x], particle[_y]
                local target_x, target_y = self._center_x, self._center_y + y_offset
                local dx, dy = target_x - x, target_y - y
                local magnitude = particle[_velocity_magnitude]
                x = x + dx * delta * magnitude
                y = y + dy * delta * magnitude

                particle[_x], particle[_y] = x, y

                local data = data_mesh_data[i]
                data[_x] = x
                data[_y] = y

                table.insert(mask, x)
                table.insert(mask, y)
                average_distance = average_distance + math.distance(target_x, target_y, x, y)
            end
            average_distance = average_distance / n_particles
            if average_distance < distance_threshold then self._mode = _MODE_EXPAND end

        elseif self._mode == _MODE_HOLD then
            local hold_velocity = rt.settings.menu.selection_particle_frame.hold_velocity * rt.get_pixel_scale()
            local max_range = 20
            mask = {}
            for i, particle in ipairs(particles) do
                local x, y = particle[_x], particle[_y]
                local vx, vy = particle[_velocity_x], particle[_velocity_y]
                local magnitude = particle[_velocity_magnitude]

                x = x + delta * vx * magnitude * hold_velocity
                y = y + delta * vy * magnitude * hold_velocity

                local origin_x, origin_y = particle[_origin_x], particle[_origin_y] + y_offset
                if math.distance(x, y, origin_x, origin_y) > max_range then
                    --x, y = origin_x + vx * max_range, origin_y + vy * max_range
                    particle[_velocity_x] = math.cos(rt.random.number(0, 2 * math.pi))
                    particle[_velocity_y] = math.sin(rt.random.number(0, 2 * math.pi))
                end

                particle[_x] = x
                particle[_y] = y

                local data = self._data_mesh_data[i]
                data[_x] = x
                data[_y] = y

                table.insert(mask, x)
                table.insert(mask, y)
            end
        elseif self._mode == _MODE_SWIPE then
            local max_velocity = rt.settings.menu.selection_particle_frame.max_velocity * rt.get_pixel_scale()
            local top_y = self._top_y
            local bottom_y = self._bottom_y

            local average_distance = 0
            for i, particle in ipairs(particles) do
                local target_x, target_y = self._center_x, self._center_y + y_offset

                local x, y = particle[_x], particle[_y]
                local dx, dy = target_x - x, target_y - y
                local magnitude = particle[_velocity_magnitude]

                x = x + delta * dx * magnitude
                y = y + delta * dy * magnitude

                particle[_x] = x
                particle[_y] = y

                local data = self._data_mesh_data[i]
                data[_x] = x
                data[_y] = y

                average_distance = average_distance + math.distance(x, y, target_x, target_y)
            end

            average_distance = average_distance / n_particles
            if average_distance < distance_threshold then
                self._mode = _MODE_EXPAND
            end
        end
    end
end

--- @brief
function mn.SelectionParticleFrame:draw()
    if not self._is_initialized then return end

    self._canvas:bind()
    love.graphics.clear(0, 0, 0, 0)

    love.graphics.push()
    love.graphics.translate(self._canvas_padding, self._canvas_padding)

    for page_i in values(self._get_active_pages()) do
        if self._mode ~= _MODE_SWIPE then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.polygon("fill", mask)
        end

        _particle_shader:bind()
        love.graphics.setColor(1, 1, 1, 1)
        self._particle_mesh:draw_instanced(n_particles)
        _particle_shader:unbind()
    end

    love.graphics.pop()
    self._canvas:unbind()

    love.graphics.push()
    _outline_shader:bind()
    love.graphics.translate(self._x - self._canvas_padding, self._y - self._canvas_padding)
    love.graphics.setColor(1, 0, 1, 1)
    love.graphics.rectangle("fill", 0, 0, self._canvas:get_size())
    self._canvas:draw()
    _outline_shader:unbind()
    love.graphics.pop()
end