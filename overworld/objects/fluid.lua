rt.settings.overworld.fluid = {
    damping = 0.1,

    particles = {
        radius = 10,
        min_mass = 1,
        max_mass = 2
    },
}

--- @class rt.FluidSimulation
ow.Fluid = meta.class("OverworldFluid")

--- @brief
function ow.Fluid:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

    self:_initialize(object.x, object.y, 400)
end

local _x_offset = 0  -- x position, px
local _y_offset = 1  -- y position, px
local _previous_x_offset = 2 -- last sub steps x position, px
local _previous_y_offset = 3 -- last sub steps y position, px
local _velocity_x_offset = 4 -- x velocity, px / s
local _velocity_y_offset = 5 -- y velocity, px / s
local _radius_offset = 6 -- radius, px
local _mass_offset = 7
local _inverse_mass_offset = 8
local _id_offset = 9
local _cell_x_offset = 10
local _cell_y_offset = 11
local _r_offset = 12
local _g_offset = 13
local _b_offset = 14
local _a_offset = 15

local _particle_stride = _a_offset + 1
local _particle_i_to_data_offset = function(particle_i, stride)
    return (particle_i - 1) * stride + 1
end

local _data_mesh_format = {
    { location = 3, name = "position", format = "floatvec2" },
    { location = 4, name = "radius", format = "float" },
    { location = 5, name = "color", format = "floatvec4" }
}

local _instance_draw_shader = rt.Shader("overworld/objects/fluid_draw_particles.glsl")

--- @brief
function ow.Fluid:_initialize(center_x, center_y, n_particles)
    self._n_particles = n_particles

    do -- instance mesh
        -- 5-vertex quad with side length 1 centered at 0, 0
        local x, y, r = 0, 0, 1
        self._instance_mesh = rt.Mesh({
            { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
            { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
            { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
            { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
            { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
        }, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)

        self._instance_mesh:set_vertex_map(
            1, 2, 3,
            1, 3, 4,
            1, 4, 5,
            1, 5, 2
        )
        self._instance_mesh:set_texture(self._particle_texture)
    end

    do -- instance mesh texture

    end

    do -- data mesh
        local native = love.graphics.newMesh(
            _data_mesh_format,
            self._n_particles,
            rt.MeshDrawMode.POINTS, -- unused
            rt.GraphicsBufferUsage.STREAM
        )

        self._data_mesh = rt.Mesh(native)
        self._data_buffer = rt.GraphicsBuffer(native:getVertexBuffer())
        self._data_buffer_data = self._data_buffer:get_byte_data()

        for entry in values(_data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._data_mesh,
                entry.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end
    end

    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

    do -- particle data
        self._data = {}
        local data = self._data
        local settings = rt.settings.overworld.fluid

        local radius = settings.particles.radius
        local min_mass, max_mass = settings.particles.min_mass, settings.particles.max_mass
        local golden_angle = math.pi * (3 - math.sqrt(5))
        local spread = radius * 2.0

        local max_distance = spread * math.sqrt(n_particles)

        local gaussian_easing = function(t)
            -- e^{-\left(\frac{4\pi}{3}\right)x^{2}}
            return math.exp(-1 * ((4 * math.pi) / 3) * t ^ 2)
        end

        for particle_index = 1, n_particles do
            local i = #data + 1

            local distance = spread * math.sqrt(particle_index)
            local angle = particle_index * golden_angle
            local t = gaussian_easing(distance / max_distance)

            local x = center_x + distance * math.cos(angle)
            local y = center_y + distance * math.sin(angle)

            min_x = math.min(min_x, x)
            min_y = math.min(min_y, y)
            max_x = math.max(max_x, x)
            max_y = math.max(max_y, y)

            data[i + _x_offset] = x
            data[i + _y_offset] = y
            data[i + _previous_x_offset] = x
            data[i + _previous_y_offset] = y

            data[i + _velocity_x_offset] = 0
            data[i + _velocity_y_offset] = 0

            data[i + _radius_offset] = radius

            local mass = math.mix(min_mass, max_mass, t)
            data[i + _mass_offset] = mass
            data[i + _inverse_mass_offset] = 1 / mass

            data[i + _id_offset] = particle_index
            data[i + _cell_x_offset] = 0 -- initialized on first update
            data[i + _cell_y_offset] = 0

            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, t, 1)

            data[i + _r_offset] = r
            data[i + _g_offset] = g
            data[i + _b_offset] = b
            data[i + _a_offset] = a
        end

        for i = 1, #data do
            assert(data[i] ~= nil)
        end
    end

    self._particle_min_x = min_x
    self._particle_min_y = min_y
    self._particle_max_x = max_x
    self._particle_max_y = max_y

    self._canvas_padding = rt.settings.overworld.fluid.particles.radius

    self:_resize_canvas() -- sets self._canvas_needs_update
    self:_update_data_mesh()
end

local use_ffi = ffi ~= nil

--- @brief
function ow.Fluid:_update_data_mesh()
    local particle_data = self._data

    if use_ffi then
        local data = ffi.cast("float*", self._data_buffer_data:get_native():getFFIPointer())

        local to_ffi_offset = 1 / ffi.sizeof("float")
        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1) * to_ffi_offset
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2) * to_ffi_offset
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1) * to_ffi_offset
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1) * to_ffi_offset
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2) * to_ffi_offset
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3) * to_ffi_offset
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4) * to_ffi_offset
        local buffer_stride = self._data_buffer:get_element_stride() * to_ffi_offset

        for particle_i = 1, self._n_particles do
            local particle_data_i = _particle_i_to_data_offset(particle_i, _particle_stride)
            local buffer_i = (particle_i - 1) * buffer_stride

            data[buffer_i + buffer_x_offset] = particle_data[particle_data_i + _x_offset]
            data[buffer_i + buffer_y_offset] = particle_data[particle_data_i + _y_offset]
            data[buffer_i + buffer_radius_offset] = particle_data[particle_data_i + _radius_offset]
            data[buffer_i + buffer_r_offset] = particle_data[particle_data_i + _r_offset]
            data[buffer_i + buffer_g_offset] = particle_data[particle_data_i + _g_offset]
            data[buffer_i + buffer_b_offset] = particle_data[particle_data_i + _b_offset]
            data[buffer_i + buffer_a_offset] = particle_data[particle_data_i + _a_offset]
        end
    else
        local data = self._data_buffer_data:get_native()

        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1)
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2)
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1)
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1)
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2)
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3)
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4)
        local buffer_stride = self._data_buffer:get_element_stride()

        for particle_i = 1, self._n_particles do
            local particle_data_i = _particle_i_to_data_offset(particle_i, _particle_stride)
            local buffer_i = (particle_i - 1) * buffer_stride

            data:setFloat(buffer_i + buffer_x_offset, particle_data[particle_data_i + _x_offset])
            data:setFloat(buffer_i + buffer_y_offset, particle_data[particle_data_i + _y_offset])
            data:setFloat(buffer_i + buffer_radius_offset, particle_data[particle_data_i + _radius_offset])
            data:setFloat(buffer_i + buffer_r_offset, particle_data[particle_data_i + _r_offset])
            data:setFloat(buffer_i + buffer_g_offset, particle_data[particle_data_i + _g_offset])
            data:setFloat(buffer_i + buffer_b_offset, particle_data[particle_data_i + _b_offset])
            data:setFloat(buffer_i + buffer_a_offset, particle_data[particle_data_i + _a_offset])
        end
    end

    self._data_mesh:replace_data(self._data_buffer_data)
end

--- @brief
function ow.Fluid:_resize_canvas()
    local width = self._particle_max_x - self._particle_min_x
    local height = self._particle_max_y - self._particle_min_y
    width = width + 2 * self._canvas_padding
    height = height + 2 * self._canvas_padding

    require "common.msaa_quality"
    require "common.texture_format"

    if self._canvas == nil
        or self._canvas:get_width() ~= width
        or self._canvas:get_height() ~= height
    then
        self._canvas = rt.RenderTexture(
            width, height,
            rt.graphics.msaa_quality_to_native(rt.MSAAQuality.BETTER),
            rt.TextureFormat.RGBA16F
        )

        self._canvas_needs_update = true
    end
end

--- @brief
function ow.Fluid:_debug_draw()
    if use_ffi then
        local data = ffi.cast("float*", self._data_buffer_data:get_native():getFFIPointer())

        local to_ffi_offset = 1 / ffi.sizeof("float")
        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1) * to_ffi_offset
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2) * to_ffi_offset
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1) * to_ffi_offset
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1) * to_ffi_offset
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2) * to_ffi_offset
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3) * to_ffi_offset
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4) * to_ffi_offset
        local buffer_stride = self._data_buffer:get_element_stride() * to_ffi_offset

        local particle_data = self._data
        for particle_i = 1, self._n_particles do
            local buffer_i = (particle_i - 1) * buffer_stride

            love.graphics.setColor(
                data[buffer_i + buffer_r_offset],
                data[buffer_i + buffer_g_offset],
                data[buffer_i + buffer_b_offset],
                data[buffer_i + buffer_a_offset]
            )

            love.graphics.circle("fill",
                data[buffer_i + buffer_x_offset],
                data[buffer_i + buffer_y_offset],
                data[buffer_i + buffer_radius_offset]
            )
        end
    else
        local data = self._data_buffer_data:get_native()
        local particle_data = self._data
        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1)
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2)
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1)
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1)
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2)
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3)
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4)
        local buffer_stride = self._data_buffer:get_element_stride()

        for particle_i = 1, self._n_particles do
            local particle_data_i = _particle_i_to_data_offset(particle_i, _particle_stride)
            local buffer_i = (particle_i - 1) * buffer_stride

            love.graphics.setColor(
                data:getFloat(buffer_i + buffer_r_offset),
                data:getFloat(buffer_i + buffer_g_offset),
                data:getFloat(buffer_i + buffer_b_offset),
                data:getFloat(buffer_i + buffer_a_offset)
            )

            love.graphics.circle("fill",
                data:getFloat(buffer_i + buffer_x_offset),
                data:getFloat(buffer_i + buffer_y_offset),
                data:getFloat(buffer_i + buffer_radius_offset)
            )
        end
    end
end

--- @brief
function ow.Fluid:draw()
    love.graphics.setColor(1, 1, 1, 1)

    if self._canvas_needs_update then
        love.graphics.push("all")
        love.graphics.reset()
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.translate(-self._particle_min_x + self._canvas_padding, -self._particle_min_y + self._canvas_padding)
        _instance_draw_shader:bind()
        self._instance_mesh:draw_instanced(self._n_particles)
        _instance_draw_shader:unbind()
        self._canvas:unbind()
        love.graphics.pop()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.translate(self._particle_min_x - self._canvas_padding, self._particle_min_y - self._canvas_padding)
    self._canvas:draw()
    love.graphics.pop()
end