require "common.render_texture"

rt.settings.menu.selection_particle_frame = {
    density = 1 / 30, -- particles per px
    max_scale_factor = 1.5,
    max_velocity = 0.5,
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
local _y = _x + 1
local _radius = _y + 1
local _origin_x = _radius + 1
local _origin_y = _origin_x + 1
local _velocity_x = _origin_y + 1
local _velocity_y = _velocity_x + 1
local _velocity_magnitude = _velocity_y + 1
local _edge = _velocity_magnitude + 1

-- sim modes
local _MODE_COLLAPSE = 1
local _MODE_EXPAND = 2
local _MODE_HOLD = 3

--- @brief
function mn.SelectionParticleFrame:instantiate()
    if _particle_shader == nil then _particle_shader = rt.Shader("menu/selection_particle_frame_particle.glsl") end
    if _outline_shader == nil then _outline_shader = rt.Shader("menu/selection_particle_frame_outline.glsl") end

    self._particles = {}
    self._canvas = nil -- rt.RenderTexture
    self._is_initialized = false
    self._mode = _MODE_EXPAND

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "space" then
            if self._mode == _MODE_EXPAND then
                self._mode = _MODE_COLLAPSE
            elseif self._mode == _MODE_COLLAPSE then
                self._mode = _MODE_EXPAND
            end
        end
    end)
end

--- @brief
function mn.SelectionParticleFrame:size_allocate(x, y, width, height)
    if self._particle_mesh == nil then
        local data = {
            { 0, 0, 1, 1, 1, 1 }
        }

        local step = (2 * math.pi) / 16
        for angle = 0, 2 * math.pi + step, step  do
            table.insert(data, {
                math.cos(angle),
                math.sin(angle),
                1, 1, 1, 0
            })
        end

        self._particle_mesh = rt.Mesh(
            data,
            rt.MeshDrawMode.TRIANGLE_FAN,
            _particle_mesh_format,
            rt.GraphicsBufferUsage.STATIC
        )
    end

    if self._canvas == nil or self._canvas:get_width() ~= width or self._canvas.get_height() ~= height then
        local x, y = 0, 0 -- sic
        self._top = { x, y, x + width, y }
        self._right = { x + width, y, x + width, y + height }
        self._bottom = { x + width, y + height, x, y + height,  }
        self._left = { x, y + height, x, y }

        -- init particles
        local density = rt.settings.menu.selection_particle_frame.density
        local radius_factor = rt.settings.menu.selection_particle_frame.max_scale_factor
        local max_velocity = rt.settings.menu.selection_particle_frame.max_velocity * rt.get_pixel_scale()

        self._particles = {}
        self._data_mesh_data = {}
        self._n_particles = 0

        local max_particle_r = -math.huge
        local center_x, center_y = x + 0.5 * width, y + 0.5 * height
        self._center_x, self._center_y = center_x, center_y
        self._mode = _MODE_EXPAND -- reset to center

        for edge in range(
            self._top, self._right, self._bottom, self._left
        ) do
            local ax, ay, bx, by = table.unpack(edge)
            local length = math.distance(ax, ay, bx, by)
            local n_particles = math.ceil(density * length)
            local particle_radius = (length / n_particles)
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
                    [_velocity_x] = rt.random.toss_coin() and 1 or -1,
                    [_velocity_y] = rt.random.toss_coin() and 1 or -1,
                    [_velocity_magnitude] = rt.random.number(1, 2)
                }

                if self._mode == _MODE_EXPAND then
                    particle[_x] = center_x
                    particle[_y] = center_y
                else
                    particle[_x] = px
                    particle[_y] = py
                end

                table.insert(self._data_mesh_data, {
                    px, py, radius
                })

                table.insert(self._particles, particle)
                self._n_particles = self._n_particles + 1
                max_particle_r = math.max(max_particle_r, radius)
            end
        end

        local padding = 20 + 2 * max_particle_r
        self._canvas = rt.RenderTexture(width + 2 * padding, height + 2 * padding)
        self._canvas_padding = padding

        self._data_mesh = rt.Mesh(
            self._data_mesh_data,
            rt.MeshDrawMode.POINTS,
            _data_mesh_format,
            rt.GraphicsBufferUsage.DYNAMIC
        )

        self._particle_mesh:attach_attribute(self._data_mesh, _data_mesh_format[1].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
        self._particle_mesh:attach_attribute(self._data_mesh, _data_mesh_format[2].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
    end

    self._x, self._y = x, y
    self:_update_mask()
    self._is_initialized = true
end

function mn.SelectionParticleFrame:_update_mask(width, height)
    local padding = self._canvas_padding
    local r, g, b = 1, 1, 1
    local a1, a0 = 1, 0
    local x, y = padding, padding
    local w, h = self._canvas:get_width() - 2 * padding, self._canvas:get_height() - 2 * padding
    local d = 0.25 * padding

    if self._mask_data == nil then
        self._mask_data = {
            [1] = { x + 0, y + 0, r, g, b, a0},
            [2] = { x + w, y + 0, r, g, b, a0},
            [3] = { x + w, y + h, r, g, b, a0},
            [4] = { x + 0, y + h, r, g, b, a0},
            [5] = { x + 0 + d, y + 0 + d, r, g, b, a1},
            [6] = { x + w - d, y + 0 + d, r, g, b, a1},
            [7] = { x + w - d, y + h - d, r, g, b, a1},
            [8] = { x + 0 + d, y + h - d, r, g, b, a1}
        }

        local tris = {
            1, 2, 5,
            5, 2, 6,
            1, 4, 5,
            4, 8, 5,
            2, 3, 6,
            6, 3, 7,
            4, 3, 8,
            3, 8, 7,
            5, 6, 8,
            8, 6, 7
        }

        self._mask_mesh = rt.Mesh(
            self._mask_data,
            rt.MeshDrawMode.TRIANGLES,
            _mask_mesh_format,
            rt.GraphicsBufferUsage.DYNAMIC
        )
        self._mask_mesh:set_vertex_map(tris)
    else
        self._mask_data[1][1], self._mask_data[1][2] = x + 0, y + 0
        self._mask_data[2][1], self._mask_data[2][2] = x + w, y + 0
        self._mask_data[3][1], self._mask_data[3][2] = x + w, y + h
        self._mask_data[4][1], self._mask_data[4][2] = x + 0, y + h
        self._mask_data[5][1], self._mask_data[5][2] = x + 0 + d, y + 0 + d
        self._mask_data[6][1], self._mask_data[6][2] = x + w - d, y + 0 + d
        self._mask_data[7][1], self._mask_data[7][2] = x + w - d, y + h - d
        self._mask_data[8][1], self._mask_data[8][2] = x + 0 + d, y + h - d
        self._mask_mesh:replace_data(self._mask_data)
    end
end

--- @brief
function mn.SelectionParticleFrame:update(delta)
    if not self._is_initialized then return end

    if self._mode == _MODE_EXPAND then
        -- move towards outer frame
        self._mask = {}
        for i, particle in ipairs(self._particles) do
            local x, y = particle[_x], particle[_y]
            local target_x, target_y = particle[_origin_x], particle[_origin_y]
            local dx, dy = target_x - x, target_y - y
            local magnitude = particle[_velocity_magnitude]
            x = x + dx * delta * magnitude
            y = y + dy * delta * magnitude

            particle[_x], particle[_y] = x, y

            local data = self._data_mesh_data[i]
            data[_x] = x
            data[_y] = y
            data[_radius] = particle[_radius]

            table.insert(self._mask, x)
            table.insert(self._mask, y)
        end
    elseif self._mode == _MODE_COLLAPSE then
        -- move towards center
        self._mask = {}
        for i, particle in ipairs(self._particles) do
            local x, y = particle[_x], particle[_y]
            local target_x, target_y = self._center_x, self._center_y
            local dx, dy = target_x - x, target_y - y
            local magnitude = particle[_velocity_magnitude]
            x = x + dx * delta * magnitude
            y = y + dy * delta * magnitude

            particle[_x], particle[_y] = x, y

            local data = self._data_mesh_data[i]
            data[_x] = x
            data[_y] = y
            data[_radius] = particle[_radius]

            table.insert(self._mask, x)
            table.insert(self._mask, y)
        end
    end

    self._data_mesh:replace_data(self._data_mesh_data)
end

--- @brief
function mn.SelectionParticleFrame:draw()
    if not self._is_initialized then return end

    self._canvas:bind()
    love.graphics.clear(0, 0, 0, 0)

    love.graphics.push()
    love.graphics.translate(self._canvas_padding, self._canvas_padding)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("fill", self._mask)

    _particle_shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    self._particle_mesh:draw_instanced(self._n_particles)
    _particle_shader:unbind()
    love.graphics.pop()

    self._canvas:unbind()

    love.graphics.push()
    _outline_shader:bind()
    love.graphics.translate(self._x - self._canvas_padding, self._y - self._canvas_padding)
    self._canvas:draw()
    _outline_shader:unbind()
    love.graphics.pop()
end