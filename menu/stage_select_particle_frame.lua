require "common.render_texture"
require "common.smoothed_motion_1d"

rt.settings.menu.stage_select_particle_frame = {
    hold_velocity = 5,
    hold_jitter_max_range = 4,
    min_particle_radius = 15,
    max_particle_radius = 15,
    min_particle_velocity = 1, -- factor
    max_particle_velocity = 1,
    mode_transition_distance_threshold = 2, -- px
    coverage = 6, -- factor
    expand_collapse_speed = 15, -- factor of dxy
    should_expand_during_transition = true,
    expand_threshold = 0.2, -- fraction, the smaller, the larger the delay before expansion during transition
}

--- @class mn.StageSelectParticleFrame
mn.StageSelectParticleFrame = meta.class("StageSelectParticleFrame", rt.Widget)

local _particle_shader, _outline_shader, _base_shader

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
local _last_x = 4
local _last_y = 5
local _origin_x = 6
local _origin_y = 7
local _velocity_x = 8
local _velocity_y = 9
local _velocity_magnitude = 10
local _segment = 11

local _MODE_HOLD = 0
local _MODE_EXPAND = 1
local _MODE_COLLAPSE = 2

--- @brief
function mn.StageSelectParticleFrame:instantiate(...)
    if _particle_shader == nil then _particle_shader = rt.Shader("menu/stage_select_particle_frame_particle.glsl") end
    if _outline_shader == nil then _outline_shader = rt.Shader("menu/stage_select_particle_frame_outline.glsl", { MODE = 0 }) end
    if _base_shader == nil then _base_shader = rt.Shader("menu/stage_select_particle_frame_outline.glsl", { MODE = 1 }) end

    self._canvas = nil -- rt.RenderTexture
    self._is_initialized = false

    self._selected_page_i = 1
    self._n_pages = select("#", ...)
    self._widgets = { ... }
    self._hue = 0

    for i = 1, self._n_pages do
        local item = select(i, ...)
        assert(meta.isa(item, rt.Widget), "In mn.StageSelectParticleFrame: selected item is not a widget")
    end

    self._motion = rt.SmoothedMotion1D(0, 1, 10) -- interpolates indices, not px
    self._scroll_offset = 0
    self._last_scroll_offset = 0
    self._canvas_x,self._canvas_y = 0, 0
    self._canvas_needs_update = true
end

--- @brief
function mn.StageSelectParticleFrame:size_allocate(x, y, width, height)
    self._pages = {} --[[
        particles
        n_particles
        data_mesh_data
        data_mesh
        particle_mesh
        static_mask,
        dynamic_mask,
        center_x,
        center_y
        widget
        widget
        height
    ]]--

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
                0, 0, 0, 0
            })
        end
    end

    self._center_x, self._center_y = 0.5 * width, 0.5 * height
    self._page_size = height

    local min_particle_r = rt.settings.menu.stage_select_particle_frame.min_particle_radius * rt.get_pixel_scale()
    local max_particle_r = rt.settings.menu.stage_select_particle_frame.max_particle_radius * rt.get_pixel_scale()
    local coverage = rt.settings.menu.stage_select_particle_frame.coverage

    -- mask is rectangle with gradient edge
    local mask_r, mask_g, mask_b, mask_a0, mask_a1 = 1, 1, 1, 0, 1
    local mask_d = max_particle_r * 0.25
    local mask_tris = {
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

    local transition = rt.settings.menu.stage_select_particle_frame.should_expand_during_transition
    local initial_mode = transition and _MODE_EXPAND or _MODE_HOLD
    self._is_transitioning = transition

    local outer_offset, inner_offset = max_particle_r, math.max(max_particle_r, 4 * rt.settings.margin_unit)

    local max_h = -math.huge
    for widget in values(self._widgets) do
        max_h = math.max(max_h, select(2, widget:measure()))
    end

    local padding = 10 * rt.get_pixel_scale()
    local canvas_w, canvas_h = self._bounds.width + 2 * outer_offset + 2 * padding, love.graphics.getHeight()

    if self._canvas == nil or self._canvas:get_width() ~= canvas_w or self._canvas:get_height() ~= canvas_h then
        self._canvas = rt.RenderTexture(canvas_w, canvas_h, 4)
    end

    self._canvas_x = x + 0.5 * width - 0.5 * canvas_w
    self._canvas_y = 0

    -- offset frame area to account for particle movement
    x = 0 + outer_offset + padding
    y = 0 + outer_offset + padding
    width = canvas_w
    height = max_h + 2 * inner_offset + 2 * outer_offset

    local min_velocity, max_velocity = rt.settings.menu.stage_select_particle_frame.min_particle_velocity, rt.settings.menu.stage_select_particle_frame.max_particle_velocity

    for page_i = 1, self._n_pages do
        local page_offset = self:_get_page_offset(page_i)

        local widget = self._widgets[page_i]
        local page_w, page_h = widget:measure() -- sic, shadowing intentional
        page_w = page_w + 2 * inner_offset
        page_h = page_h + 2 * inner_offset
        local page_x, page_y = x, y -- x: canvas-local
        local center_x, center_y = page_x + 0.5 * page_w, page_y + 0.5 * page_h

        widget:reformat(page_x, page_y + page_offset, page_w, page_h)

        local particles = {}
        local page_n_particles = 0
        local data_mesh_data = {}
        local dynamic_mask = {}

        page_y = page_y + page_offset

        local top = { page_x, page_y, page_x + page_w, page_y }
        local right = { page_x + page_w, page_y, page_x + page_w, page_y + page_h }
        local bottom = { page_x + page_w, page_y + page_h, page_x, page_y + page_h }
        local left = { page_x, page_y + page_h, page_x, page_y }

        for segment in range(top, right, bottom, left) do
            local ax, ay, bx, by = table.unpack(segment)
            local length = math.distance(table.unpack(segment))
            local dx, dy = bx - ax, by - ay
            local n_particles = math.min(coverage * math.ceil(length / min_particle_r), 100) -- intentionally over-cover

            for particle_i = 0, n_particles - 1 do
                local fraction = particle_i / n_particles
                local home_x, home_y = ax + dx * fraction, ay + dy * fraction
                local radius = rt.random.number(min_particle_r, max_particle_r)
                local particle = {
                    [_radius] = radius,
                    [_origin_x] = home_x,
                    [_origin_y] = home_y,
                    [_velocity_x] = math.cos(rt.random.number(0, 2 * math.pi)),
                    [_velocity_y] = math.sin(rt.random.number(0, 2 * math.pi)),
                    [_velocity_magnitude] = rt.random.number(min_velocity, max_velocity),
                    [_segment] = segment
                }

                local particle_x, particle_y
                if initial_mode == _MODE_EXPAND then
                    particle_x = center_x
                    particle_y = center_y
                else
                    particle_x = home_x
                    particle_y = home_y
                end

                particle[_x] = particle_x
                particle[_y] = particle_y
                particle[_last_x] = particle_x
                particle[_last_y] = particle_y

                table.insert(dynamic_mask, particle_x)
                table.insert(dynamic_mask, particle_y)

                table.insert(data_mesh_data, {
                    particle_x, particle_y, radius
                })

                table.insert(particles, particle)
                page_n_particles = page_n_particles + 1
            end
        end

        local mask_x, mask_y = top[1], top[2]
        local mask_w, mask_h = top[3] - top[1], right[4] - right[2]

        local mask_data = {
            [1] = { mask_x + 0, mask_y + 0, mask_r, mask_g, mask_b, mask_a0 },
            [2] = { mask_x + mask_w, mask_y + 0, mask_r, mask_g, mask_b, mask_a0 },
            [3] = { mask_x + mask_w, mask_y + mask_h, mask_r, mask_g, mask_b, mask_a0 },
            [4] = { mask_x + 0, mask_y + mask_h, mask_r, mask_g, mask_b, mask_a0 },
            [5] = { mask_x + 0 + mask_d, mask_y + 0 + mask_d, mask_r, mask_g, mask_b, mask_a1 },
            [6] = { mask_x + mask_w - mask_d, mask_y + 0 + mask_d, mask_r, mask_g, mask_b, mask_a1 },
            [7] = { mask_x + mask_w - mask_d, mask_y + mask_h - mask_d, mask_r, mask_g, mask_b, mask_a1 },
            [8] = { mask_x + 0 + mask_d, mask_y + mask_h - mask_d, mask_r, mask_g, mask_b, mask_a1 }
        }

        local mask_mesh = rt.Mesh(
            mask_data,
            rt.MeshDrawMode.TRIANGLES,
            _mask_mesh_format,
            rt.GraphicsBufferUsage.STATIC
        )
        mask_mesh:set_vertex_map(mask_tris)

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

        particle_mesh:attach_attribute(data_mesh, _data_mesh_format[1].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
        particle_mesh:attach_attribute(data_mesh, _data_mesh_format[2].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)

        self._pages[page_i] = {
            mode = initial_mode,
            particles = particles,
            n_particles = page_n_particles,
            data_mesh_data = data_mesh_data,
            particle_mesh = particle_mesh,
            data_mesh = data_mesh,
            static_mask = mask_mesh,
            dynamic_mask = dynamic_mask,
            x = page_x,
            y = page_y,
            width = page_w,
            height = page_h,
            widget = widget
        }
    end

    self:set_selected_page(self._selected_page_i)
    self._is_initialized = true
    self._canvas_needs_update = true
end

--- @brief
function mn.StageSelectParticleFrame:_get_active_pages()
    local out = {}

    local eps = 0.25

    local current, target = self._motion:get_value(), self._motion:get_target_value()
    if current - target < -eps and self._selected_page_i > 1 then
        table.insert(out, self._selected_page_i - 1)
    end

    table.insert(out, self._selected_page_i)

    if current - target > eps and self._selected_page_i < self._n_pages then
        table.insert(out, self._selected_page_i + 1)
    end

    return out
end

--- @brief
function mn.StageSelectParticleFrame:_get_page_offset(i)
    return (i - 1) * self._canvas:get_height()
end

--- @brief
function mn.StageSelectParticleFrame:update(delta)
    if not self._is_initialized then return end

    if self._is_transitioning ~= true then
        self._motion:update(delta)
    end

    local t = self._motion:get_value() -- index
    self._last_scroll_offset = self._scroll_offset
    self._scroll_offset = t * self._canvas:get_height()

    -- interpolate between hues of current page and next page
    local lower_i = math.floor(t)
    local higher_i = math.ceil(t)
    if higher_i == lower_i then higher_i = lower_i + 1 end -- t is an integer
    self._hue = math.mix(lower_i / self._n_pages, higher_i / self._n_pages, math.fract(t))
    if self._hue < 0 then self._hue = 0 end

    for page_i in values(self:_get_active_pages()) do
        local page = self._pages[page_i]

        if page.mode == _MODE_HOLD then
            local hold_velocity = rt.settings.menu.stage_select_particle_frame.hold_velocity * rt.get_pixel_scale()
            if hold_velocity ~= 0 then
                local max_range = rt.settings.menu.stage_select_particle_frame.hold_jitter_max_range * rt.get_pixel_scale()
                for i = 1, page.n_particles do
                    local particle = page.particles[i]
                    local x, y = particle[_x], particle[_y]
                    local vx, vy = particle[_velocity_x], particle[_velocity_y]
                    local magnitude = particle[_velocity_magnitude]

                    local ax, ay, bx, by = table.unpack(particle[_segment])
                    local dx, dy = bx - ax, by - ay

                    x = x + delta * vx * magnitude * hold_velocity
                    y = y + delta * vy * magnitude * hold_velocity

                    local origin_x, origin_y = particle[_origin_x], particle[_origin_y]
                    if math.distance(x, y, origin_x, origin_y) > max_range then
                        particle[_velocity_x] = math.cos(rt.random.number(0, 2 * math.pi))
                        particle[_velocity_y] = math.sin(rt.random.number(0, 2 * math.pi))
                    end

                    particle[_last_x] = particle[_x]
                    particle[_last_y] = particle[_y]
                    particle[_x] = x
                    particle[_y] = y

                    local data = page.data_mesh_data[i]
                    data[_x] = x
                    data[_y] = y
                end
            end
        elseif page.mode == _MODE_COLLAPSE or (
            page.mode == _MODE_EXPAND and
                not (self._is_transitioning and math.abs((self._motion:get_value() + 1) - self._selected_page_i) > rt.settings.menu.stage_select_particle_frame.expand_threshold)
        ) then
            local mask_i = 1
            local mean_distance = 0
            local velocity_factor = rt.settings.menu.stage_select_particle_frame.expand_collapse_speed
            for i = 1, page.n_particles do
                local particle = page.particles[i]
                local x, y = particle[_x], particle[_y]
                local target_x, target_y

                if page.mode == _MODE_EXPAND then
                    target_x, target_y = particle[_origin_x], particle[_origin_y]
                elseif page.mode == _MODE_COLLAPSE then
                    target_x, target_y = page.x + 0.5 * page.width, page.y + 0.5 * page.height
                end

                local dx, dy = target_x - x, target_y - y
                local magnitude = particle[_velocity_magnitude]
                x = x + dx * delta * magnitude * velocity_factor
                y = y + dy * delta * magnitude * velocity_factor

                particle[_last_x] = particle[_x]
                particle[_last_y] = particle[_y]
                particle[_x], particle[_y] = x, y

                local data = page.data_mesh_data[i]
                data[_x] = x
                data[_y] = y

                page.dynamic_mask[mask_i+0] = x
                page.dynamic_mask[mask_i+1] = y
                mask_i = mask_i + 2

                mean_distance = mean_distance + math.magnitude(dx, dy)
            end

            if mean_distance / page.n_particles <= rt.settings.menu.stage_select_particle_frame.mode_transition_distance_threshold * rt.get_pixel_scale() then
                if page.mode == _MODE_EXPAND then
                    page.mode = _MODE_HOLD
                elseif page.mode == _MODE_COLLAPSE and page_i == self._transitioning_page_i then
                    self._is_transitioning = false
                    self._transitioning_page_i = nil
                end
            end
        end

        page.data_mesh:replace_data(page.data_mesh_data)
    end

    self._canvas_needs_update = true
end

--- @brief
function mn.StageSelectParticleFrame:draw()
    if not self._is_initialized then return end

    local offset = math.mix(self._last_scroll_offset, self._scroll_offset, rt.SceneManager:get_frame_interpolation())

    if self._canvas_needs_update then
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        love.graphics.origin()
        love.graphics.translate(0, -1 * offset)

        local interpolation = rt.SceneManager:get_frame_interpolation()

        for page_i in values(self:_get_active_pages()) do
            local page = self._pages[page_i]

            if page.mode == _MODE_HOLD then
                page.static_mask:draw()
            else
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.polygon("fill", page.dynamic_mask)
            end

            _particle_shader:bind()
            love.graphics.setColor(1, 1, 1, 1)
            page.particle_mesh:draw_instanced(page.n_particles)
            _particle_shader:unbind()
        end

        love.graphics.pop()
        self._canvas:unbind()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.translate(
        self._canvas_x,
        self._canvas_y
    )

    local canvas = self._canvas:get_native()
    _base_shader:bind()
    rt.Palette.TRUE_BLACK:bind()
    love.graphics.draw(canvas)
    _base_shader:unbind()

    _outline_shader:bind()
    _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _outline_shader:send("hue", self._hue)
    love.graphics.draw(canvas)
    _outline_shader:unbind()

    love.graphics.pop()

    local stencil = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.DRAW)

    love.graphics.setColor(1, 1, 1, 1)
    self._canvas:draw(self._canvas_x, self._canvas_y)
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    love.graphics.push()
    love.graphics.translate(self._canvas_x, self._canvas_y - offset)
    for page_i in values(self:_get_active_pages()) do
        self._pages[page_i].widget:draw()
    end
    love.graphics.pop()

    rt.graphics.set_stencil_mode(nil)
end

--- @brief
function mn.StageSelectParticleFrame:draw_mask()
    love.graphics.push()
    love.graphics.translate(
        self._canvas_x, 0
    )

    _base_shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native())
    _base_shader:unbind()
    love.graphics.pop()
end

--- @brief
function mn.StageSelectParticleFrame:draw_bloom()
    love.graphics.push()
    love.graphics.translate(
        self._canvas_x,
        self._canvas_y
    )

    _outline_shader:bind()
    _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _outline_shader:send("hue", self._hue)
    love.graphics.draw(self._canvas:get_native())
    _outline_shader:unbind()

    love.graphics.pop()
end

--- @brief
function mn.StageSelectParticleFrame:set_selected_page(i)
    if not (i > 0 and i <= self._n_pages) then
        rt.error("In mn.StageSelectPageIndicator: page `" .. i .. "` is out of range")
    end

    if self._selected_page_i ~= i then
        local current_i = self._selected_page_i
        self._motion:set_target_value(i - 1)
        self._selected_page_i = i

        -- reset pages to start animation
        if rt.settings.menu.stage_select_particle_frame.should_expand_during_transition then
            for page_i, page in ipairs(self._pages) do
                if page_i ~= current_i then
                    page.mode = _MODE_EXPAND
                    for particle in values(page.particles) do
                        particle[_x] = page.x + 0.5 * page.width
                        particle[_y] = page.y + 0.5 * page.height
                    end
                else
                    page.mode = _MODE_COLLAPSE
                end
            end

            self._is_transitioning = true
            self._transitioning_page_i = current_i
        end
    end
end

--- @brief
function mn.StageSelectParticleFrame:get_selected_page()
    return self._selected_page_i
end

--- @brief
function mn.StageSelectParticleFrame:get_hue()
    return self._hue
end