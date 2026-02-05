rt.settings.fluid_simulation = {
    n_lloyd_iterations = 4
}

--- @class rt.FluidSimulation
rt.FluidSimulation = meta.class("FluidSimulation")

--- @brief create a new simulation handler instance. Usually this function is not called directly, use `instance = rt.FluidSimulation()` instead
--- @return rt.FluidSimulation
function rt.FluidSimulation:instantiate()
    -- default
    local outline_thickness = 1
    local particle_radius = 2
    local base_damping = 0.1
    local texture_scale = 12
    local base_mass = 1

    -- see README.md for a description of the parameters below

    self._default_config = {
        -- dynamic
        damping = base_damping,

        follow_strength = 1 - 0.004,

        cohesion_strength = 1 - 0.9,
        cohesion_interaction_distance_factor = 2,

        collision_strength = 1 - 0.0025,
        collision_overlap_factor = 2,

        color = rt.Palette.YELLOW_5,
        outline_color = rt.Palette.ORANGE_5,
        outline_thickness = outline_thickness,

        highlight_strength = 0,
        shadow_strength = 1,

        -- static
        min_mass = base_mass,
        max_mass = base_mass * 2,

        min_radius = particle_radius,
        max_radius = particle_radius,

        texture_scale = texture_scale,
        motion_blur = 0.0001,

        batch_radius = 0
    }

    -- immutable properties
    self._particle_texture_shader_path = "common/fluid_simulation_particle_texture.glsl"
    self._outline_shader_path = "common/fluid_simulation_outline.glsl"
    self._instanced_draw_shader_path = "common/fluid_simulation_instanced_draw.glsl"
    self._lighting_shader_path = "common/fluid_simulation_lighting.glsl"

    self._thresholding_threshold = 0.3 -- in [0, 1]
    self._thresholding_smoothness = 0.01 -- in [0, threshold_shader_threshold)

    self._mass_distribution_variance = 4 -- unitless, (2 * n) with n >= 1
    self._max_collision_fraction = 0.05 -- fraction
    self._use_lighting = true -- whether specular highlight and shadows should be drawn

    -- render texture config
    self._canvas_msaa = 4 -- msaa for render textures
    self._particle_texture_radius = 40 * rt.get_pixel_scale()
    self._particle_texture_padding = 3 -- px
    self._particle_texture_resolution_factor = 4 -- fraction

    self:_reinitialize()
    return self
end


-- particle properties are stored inline, these are the offset
local _x_offset = 0  -- x position, px
local _y_offset = 1  -- y position, px
local _z_offset = 2  -- render priority
local _velocity_x_offset = 3 -- x velocity, px / s
local _velocity_y_offset = 4 -- y velocity, px / s
local _previous_x_offset = 5 -- last sub steps x position, px
local _previous_y_offset = 6 -- last sub steps y position, px
local _radius_t_offset = 7
local _radius_offset = 8 -- radius, px
local _mass_t_offset = 9
local _mass_offset = 10 -- mass, fraction
local _inverse_mass_offset = 11 -- 1 / mass, precomputed for performance
local _follow_x_offset = 12
local _follow_y_offset = 13
local _cell_x_offset = 14 -- spatial hash x coordinate, set in _step
local _cell_y_offset = 15 -- spatial hash y coordinate
local _batch_id_offset = 16 -- batch id
local _batch_radius_offset = 17
local _r_offset = 18 -- rgba red
local _g_offset = 19 -- rgba green
local _b_offset = 20 -- rgba blue
local _a_offset = 21 -- rgba opacity
local _last_update_x_offset = 22 -- last whole step x position, px
local _last_update_y_offset = 23 -- last whole step x position, px

local _stride = _last_update_y_offset + 1

--- convert particle index to index in shared particle property array
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end


--- @brief add a new batch to the simulation
--- @param x number x position, px
--- @param y number y position, px
--- @param radius number? radius of the egg white, px
--- @param color rt.RGBA? color in rgba format, components in [0, 1]
--- @param config table?
--- @return number integer id of the new batch
function rt.FluidSimulation:add(x, y, radius, color, config)
    config = config or table.deepcopy(self._default_config)
    color = color or config.color

    meta.assert(
        x, "Number",
        y, "Number",
        radius, "Number",
        color, rt.RGBA,
        config, "Table"
    )

    config.batch_radius = radius

    local particle_radius = math.mix(
        config.min_radius,
        config.max_radius,
        0.5
    ) -- expected value. symmetrically normal distributed around mean

    local n_particles = math.ceil(
        (math.pi * radius^2) / (math.pi * particle_radius^2)
    ) -- (area of white) / (area of particle), where circular area = pi r^2

    if radius <= 0 then
        rt.error( "In rt.FluidSimulation.add: white radius cannot be 0 or negative")
    end

    if n_particles <= 1 then
        rt.error( "In rt.FluidSimulation.add: white particle count cannot be 1 or negative")
    end

    local warn = function(which, egg_radius, particle_radius, n_particles)
        rt.warning("In rt.FluidSimulation.add: trying to add ", which, " of radius `", egg_radius, "`, but the ", which, " particle radius is `~", particle_radius, "`, so only `", n_particles, "` particles will be created. Consider increasing the ", which, " radius or decreasing the ", which, " particle size")
    end

    if n_particles < 10 then
        warn("white", radius, particle_radius, n_particles)
    end

    self._total_n_particles = self._total_n_particles + n_particles

    local batch_id, batch = self:_new_batch(
        x, y,
        n_particles,
        config
    )

    self._batch_id_to_batch[batch_id] = batch
    self._n_batches = self._n_batches + 1

    return batch_id
end

--- @brief removes a batch from the simulation
--- @param batch_id number id of the batch to remove, acquired from rt.FluidSimulation.add
--- @return nil
function rt.FluidSimulation:remove(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.warning("In rt.FluidSimulation.remove: no batch with id `", batch_id, "`")
        return
    end

    self._batch_id_to_batch[batch_id] = nil
    self._n_batches = self._n_batches - 1
    self._total_n_particles = self._total_n_particles - batch.n_particles

    self:_remove(batch.particle_indices)
end

--- @brief draw all batches
--- @return nil
function rt.FluidSimulation:draw()
    self:_update_canvases()
    self:_draw_canvases()
end

--- @brief update all batches
--- @param step_delta number fixed timestep, seconds
--- @param n_substeps number number of solver iterations per step, integer
--- @param n_collision_steps number number of collision sub steps per iteration step, integer
function rt.FluidSimulation:update(delta, step_delta, n_substeps, n_collision_steps)
    if step_delta == nil then step_delta = 1 / 60 end
    if n_substeps == nil then n_substeps = 2 end
    if n_collision_steps == nil then n_collision_steps = 3 end

    meta.assert(
        delta, "Number",
        step_delta, "Number",
        n_substeps, "Number",
        n_collision_steps, "Number"
    )

    -- catch floats instead of ints
    n_substeps = math.ceil(n_substeps)
    n_collision_steps = math.ceil(n_collision_steps)

    if step_delta < 0 or math.is_nan(step_delta) then
        rt.error("In rt.FluidSimulation.update: `step_delta` is not a number > 0")
        return
    end

    if n_substeps < 1 or math.is_nan(n_substeps) then
        rt.error("In rt.FluidSimulation.update: `n_substeps` is not a number > 0")
        return
    end

    if n_collision_steps < 1 or math.is_nan(n_collision_steps) then
        rt.error("In rt.FluidSimulation.update: `n_collision_steps` is not a number > 0")
        return
    end

    -- accumulate delta time, run sim at fixed framerate for better stability
    self._elapsed = self._elapsed + delta
    local step = step_delta
    local n_steps = 0
    local max_n_steps = math.max(4, 4 * math.ceil((1 / 60) / step_delta))
    while self._elapsed >= step do
        self:_step(step, n_substeps, n_collision_steps)
        self._elapsed = self._elapsed - step

        -- safety check to prevent death spiral
        n_steps = n_steps + 1
        if n_steps > max_n_steps then
            self._elapsed = 0
            break
        end
    end

    self._interpolation_alpha = math.clamp(self._elapsed / step, 0, 1)

    self:_update_data_mesh()
    -- no need to update color mesh
end

--- @brief update the mutable simulation parameters for the white
--- @param config table table of properties, see the readme for a list of valid properties
function rt.FluidSimulation:set_config(batch_id, config)
    if config == nil then config = self._default_config end
    meta.assert(batch_id, "Number", config, "Table")
    self:_load_config(batch_id, config)
end

--- @brief
function rt.FluidSimulation:get_config(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.error( "In rt.FluidSimulation.get_target_position: no batch with id `", batch_id, "`")
        return nil
    else
        return batch.config
    end
end

--- @brief set the target position a batch should move to
--- @param batch_id number batch id returned by rt.FluidSimulation.add
--- @param x number x coordinate, in px
--- @param y number y coordinate, in px
function rt.FluidSimulation:set_target_position(batch_id, x, y)
    meta.assert(batch_id, "Number", x, "Number", y, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.warning( "In rt.FluidSimulation.set_target_position: no batch with id `", batch_id, "`")
    else
        batch.follow_x = x
        batch.follow_y = y
        self._follow_changed = true
    end
end

--- @brief get the target position a batch should move to
--- @return number, number
function rt.FluidSimulation:get_target_position(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.error( "In rt.FluidSimulation.get_target_position: no batch with id `", batch_id, "`")
        return nil, nil
    else
        return batch.follow_x, batch.follow_y
    end
end

--- @brief get average of all particle positions of a batch
function rt.FluidSimulation:get_position(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.error( "In rt.FluidSimulation.get_target_position: no batch with id `", batch_id, "`")
        return nil, nil
    else
        if batch.centroid_needs_update then
            self:_update_batch_centroid(batch)
        end

        return batch.centroid_x, batch.centroid_y
    end
end

--- @brief
function rt.FluidSimulation:set_target_shape(batch_id, tris)
    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then rt.error("In rt.FluidSimulation.set_target_shape: no batch with id `", batch_id, "`") end

    local circle_i_to_radius = table.new(batch.n_particles, 0)
    local min_radius, max_radius = batch.config.min_radius, batch.config.max_radius
    for particle_i = 1, batch.n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        circle_i_to_radius[particle_i] = math.mix(
            min_radius,
            max_radius,
            self._data[i + _radius_t_offset]
        ) -- interpolate in case _step has not yet updated particle radius
    end

    local new_positions = self:_distribute_particles(tris, circle_i_to_radius)

    local particle_i = 1
    for position_i = 1, #new_positions, 2 do
        local i = _particle_i_to_data_offset(particle_i)
        self._data[i + _follow_x_offset] = new_positions[position_i + 0]
        self._data[i + _follow_y_offset] = new_positions[position_i + 1]
        particle_i = particle_i + 1
    end

    self._follow_changed = false -- do not update
end

--- @brief list the ids of all batches
--- @return number[] array of batch ids
function rt.FluidSimulation:list_ids()
    local ids = {}
    for id, _ in pairs(self._batch_id_to_batch) do
        table.insert(ids, id)
    end
    return ids
end

--- @brief get total number of particles
--- @return number
function rt.FluidSimulation:get_n_particles(batch_or_nil)
    if batch_or_nil == nil then
        return self._total_n_particles
    else
        local batch = self._batch_id_to_batch[batch_or_nil]
        if batch == nil then
            rt.error("In rt.FluidSimulation:get_n_particles: no batch with id `", batch_or_nil, "`")
        end
        return batch.n_particles
    end
end

-- ### internals, never call any of the functions below ### --

--- @brief [internal] clear the simulation, useful for debugging
--- @private
function rt.FluidSimulation:_reinitialize()
    -- internal properties
    self._batch_id_to_batch = {} -- Table<Number, Batch>
    self._current_batch_id = 1
    self._n_batches = 0

    self._config_changed = true
    self._follow_changed = true

    -- particle properties are stored inline
    self._data = {}
    self._total_n_particles = 0

    self._data_mesh_data = {}
    self._color_data_mesh_data = {}

    self._max_radius = 1
    self._canvases_need_update = false

    self._elapsed = 0
    self._interpolation_alpha = 0

    self:_initialize_shaders()
    self:_initialize_particle_texture()

    local position_name = "particle_position"
    local velocity_name = "particle_velocity"
    local radius_name = "particle_radius"
    local color_name = "particle_color"

    assert(love.getVersion() >= 12, "Love v12.0 or later required, mesh data format is incompatible with earlier versions")

    do
        -- default love mesh format
        -- location = 0: VertexPosition
        -- location = 1: VertexTexCoord
        -- location = 2: VertexColor

        local i = 2
        self._data_mesh_format = {
            { location = i+1, name = position_name, format = "floatvec4" }, -- xy: position, zw: previous position
            { location = i+2, name = velocity_name, format = "floatvec2" },
            { location = i+3, name = radius_name, format = "float" },
        }

        -- data and color mesh are separate, as only the data mesh changes every
        -- frame, uploading the same color every frame to vram is suboptimal
        self._color_mesh_format = {
            { location = i+4, name = color_name, format = "floatvec4" }
        }
    end

    self:_initialize_instance_mesh()
    self:_update_data_mesh()
    self:_update_color_mesh()

    self._canvas = nil -- rt.RenderTexture

    self._last_env = nil -- cf. _step
    self._render_texture_format = "rgba8"

    -- step once to init environments
    self:_step(0, 1, 1)
end

--- @brief [internal] load and compile necessary shaders
--- @private
function rt.FluidSimulation:_initialize_shaders()
    self._particle_texture_shader = rt.Shader(self._particle_texture_shader_path)
    self._outline_shader = rt.Shader(self._outline_shader_path)
    self._lighting_shader = rt.Shader(self._lighting_shader_path)
    self._instanced_draw_shader = rt.Shader(self._instanced_draw_shader_path)

    -- on vulkan, first use of a shader would cause stutter, so force use here, equivalent to precompiling the shader
    if love.getVersion() >= 12 and love.graphics.getRendererInfo() == "Vulkan" then
        love.graphics.push("all")
        local texture = rt.RenderTexture(1, 1)
        texture:bind()

        for _, shader in ipairs({
            self._particle_texture_shader,
            self._lighting_shader,
            self._outline_shader
        }) do
            shader:bind()
            love.graphics.rectangle("fill", 0, 0, 1, 1)
            shader:unbind()
        end

        texture:unbind()
        love.graphics.pop("all")
    end
end

--- @brief [internal] initialize mass distribution texture used for particle density estimation
--- @private
function rt.FluidSimulation:_initialize_particle_texture()
    -- create particle texture, this will hold density information
    -- we use the same texture for all particles regardless of size,
    -- instead love.graphics.scale'ing based on particle size,
    -- this way all draws are batched

    local radius = self._particle_texture_radius * self._particle_texture_resolution_factor

    local padding = self._particle_texture_padding -- px

    -- create canvas, transparent outer padding so derivative on borders is 0
    local canvas_width = (radius + padding) * 2
    local canvas_height = canvas_width

    self._particle_texture = rt.RenderTexture(
        canvas_width, canvas_height,
        0,
        self._render_texture_format
    )

    self._particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    self._particle_texture:set_wrap_mode(rt.TextureWrapMode.ZERO)

    local x, y, width, height = 0, 0, 2 * radius, 2 * radius

    -- fill particle with density data using shader
    love.graphics.push("all")
    love.graphics.reset()
    self._particle_texture:bind()
    self._particle_texture_shader:bind()

    love.graphics.translate(
        (canvas_width - width) / 2,
        (canvas_height - height) / 2
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, width, height)

    self._particle_texture_shader:unbind()
    self._particle_texture:unbind()
    love.graphics.pop()
end

--- @brief [internal] initialize data related to instanced drawing
--- @private
function rt.FluidSimulation:_initialize_instance_mesh()
    -- 5-vertex quad with side length 1 centered at 0, 0
    local x, y, r = 0, 0, 1
    local mesh = rt.Mesh({
        { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
        { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
        { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
        { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
        { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
    }, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)

    mesh:set_vertex_map(
        1, 2, 3,
        1, 3, 4,
        1, 4, 5,
        1, 5, 2
    )
    mesh:set_texture(self._particle_texture)
    self._instance_mesh = mesh
end

--- @brief [internal] upload vertex data mesh
--- @private
function rt.FluidSimulation:_update_data_mesh()
    local function update_data_mesh(particles, n_particles, instance_mesh, mesh_data, mesh)
        if n_particles == 0 then return nil end
        local before = #mesh_data

        -- update mesh data
        for particle_i = 1, n_particles do
            local current = mesh_data[particle_i]
            if current == nil then
                current = {}
                mesh_data[particle_i] = current
            end

            local i = _particle_i_to_data_offset(particle_i)
            current[1] = particles[i + _x_offset]
            current[2] = particles[i + _y_offset]
            current[3] = particles[i + _last_update_x_offset]
            current[4] = particles[i + _last_update_y_offset]

            current[5] = particles[i + _velocity_x_offset]
            current[6] = particles[i + _velocity_y_offset]

            current[7] = particles[i + _radius_offset]
        end

        while #mesh_data > n_particles do
            table.remove(mesh_data, #mesh_data)
        end

        local after = #mesh_data

        if mesh == nil or before ~= after then
            -- if resized, reallocate mesh
            local data_mesh = rt.Mesh(
                mesh_data,
                rt.MeshDrawMode.TRIANGLES, -- unused, this mesh will never be drawn
                self._data_mesh_format,
                rt.GraphicsBufferUsage.STREAM
            )

            -- attach for rendering
            for _, entry in ipairs(self._data_mesh_format) do
                instance_mesh:attach_attribute(data_mesh, entry.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
            end

            return data_mesh
        else
            -- else upload vertex data
            mesh:replace_data(mesh_data)
            mesh:flush()
            return mesh
        end
    end

    self._data_mesh = update_data_mesh(
        self._data,
        self._total_n_particles,
        self._instance_mesh,
        self._data_mesh_data,
        self._data_mesh
    )
end

--- @brief [internal] upload color mesh data for instanced drawing
--- @private
function rt.FluidSimulation:_update_color_mesh()
    local function update_color_mesh(particles, n_particles, instance_mesh, mesh_data, mesh)
        if n_particles == 0 then return nil end
        local before = #mesh_data

        for particle_i = 1, n_particles do
            local current = mesh_data[particle_i]
            if current == nil then
                current = {}
                mesh_data[particle_i] = current
            end

            local i = _particle_i_to_data_offset(particle_i)
            current[1] = particles[i + _r_offset]
            current[2] = particles[i + _g_offset]
            current[3] = particles[i + _b_offset]
            current[4] = particles[i + _a_offset]
        end

        while #mesh_data > n_particles do
            mesh_data[#mesh_data] = nil
        end

        local after = #mesh_data

        if mesh == nil or before ~= after then
            local color_data_mesh = rt.Mesh(
                mesh_data,
                rt.MeshDrawMode.TRIANGLES, -- unused
                self._color_mesh_format,
                rt.GraphicsBufferUsage.STREAM
            )

            for _, entry in ipairs(self._color_mesh_format) do
                instance_mesh:attach_attribute(color_data_mesh, entry.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
            end

            return color_data_mesh
        else
            mesh:replace_data(mesh_data)
            mesh:flush()
            return mesh
        end
    end

    self._color_data_mesh = update_color_mesh(
        self._data,
        self._total_n_particles,
        self._instance_mesh,
        self._color_data_mesh_data,
        self._color_data_mesh
    )
end

--- @brief [internal] create a new particle batch
--- @private
function rt.FluidSimulation:_new_batch(
    center_x, center_y, n_particles, config
)
    local batch = {
        particle_indices = {},
        color = config.color,
        config = config,
        config_was_updated = true,

        target_x = center_x,
        target_y = center_y,

        centroid_x = center_x,
        centroid_y = center_y,
        centroid_needs_update = true
    }

    -- generate uniformly distributed value in interval
    local random_uniform = function(min, max)
        local t = love.math.random(0, 1)
        return math.mix(min, max, t)
    end

    -- uniformly distribute points across the disk using fibonacci spiral
    local fibonacci_spiral = function(i, n, x_radius, y_radius)
        local golden_ratio = (1 + math.sqrt(5)) / 2
        local golden_angle = 2 * math.pi / (golden_ratio * golden_ratio)

        local r = math.sqrt((i - 1) / n)
        local theta = i * golden_angle

        local x = r * x_radius * math.cos(theta)
        local y = r * y_radius * math.sin(theta)

        return x, y
    end

    -- instead of pure random mass, mass should always be exactly distributed in gaussian-like curve
    local get_mass = function(i, n)
        local variance = self._mass_distribution_variance
        local function butterworth(t)
            return 1 / (1 + (variance * (t - 0.5))^4)
        end

        -- 2-point gauss-legendre integration, reduces aliasing at low particle counts
        local left = (i - 0.5) / n  -- Changed from (i - 1) / n
        local right = (i + 0.5) / n  -- Changed from i / n

        local center = 0.5 * (left + right)
        local half_width = 0.5 * (right - left)

        local t1 = center - half_width / math.sqrt(3)
        local t2 = center + half_width / math.sqrt(3)

        return 0.5 * (butterworth(t1) + butterworth(t2))
    end

    -- add particle data to the batch particle property buffer
    local add_particle = function(
        array, config,
        particle_i, n_particles,
        batch_id
    )
        -- generate position
        local dx, dy = fibonacci_spiral(
            particle_i, n_particles,
            config.batch_radius, config.batch_radius
        )

        local x = center_x + dx
        local y = center_y + dy

        -- mass and radius use the same interpolation factor, since volume and mass are correlated
        -- we could compute mass as a function of radius, but being able to choose the mass distribution
        -- manually gives more freedom when fine-tuning the simulation
        local t = get_mass(particle_i, n_particles)
        local mass = math.mix(
            config.min_mass,
            config.max_mass,
            t
        )

        local radius = math.mix(config.min_radius, config.max_radius, t)

        local i = #array + 1
        array[i + _x_offset] = x
        array[i + _y_offset] = y
        array[i + _z_offset] = 0
        array[i + _velocity_x_offset] = 0
        array[i + _velocity_y_offset] = 0
        array[i + _previous_x_offset] = x
        array[i + _previous_y_offset] = y
        array[i + _radius_t_offset] = t
        array[i + _radius_offset] = radius
        array[i + _mass_t_offset] = t
        array[i + _mass_offset] = mass
        array[i + _inverse_mass_offset] = 1 / mass
        array[i + _follow_x_offset] = x
        array[i + _follow_y_offset] = y
        array[i + _cell_x_offset] = -math.huge
        array[i + _cell_y_offset] = -math.huge
        array[i + _batch_id_offset] = batch_id
        array[i + _batch_radius_offset] = config.batch_radius
        array[i + _r_offset] = config.color.r
        array[i + _g_offset] = config.color.g
        array[i + _b_offset] = config.color.b
        array[i + _a_offset] = config.color.a

        array[i + _last_update_x_offset] = x
        array[i + _last_update_y_offset] = y

        assert(#array - i == _stride - 1)

        self._max_radius = math.max(self._max_radius, radius)
        return i
    end

    local batch_id = self._current_batch_id
    self._current_batch_id = self._current_batch_id + 1

    for i = 1, n_particles do
        table.insert(batch.particle_indices, add_particle(
            self._data,
            batch.config,
            i, n_particles,
            batch_id
        ))
    end

    batch.n_particles = n_particles

    self:_update_data_mesh()
    self:_update_color_mesh()

    return batch_id, batch
end

--- @brief [internal] remove particle data from shared array
--- @private
function rt.FluidSimulation:_remove(indices)
    local function remove_particles(indices, data, list_name)
        if not indices or #indices == 0 then return end

        local stride = _stride
        local total_particles = #data / stride

        -- mark particles to remove
        local remove = {}
        for _, base in ipairs(indices) do
            local p = math.floor((base - 1) / stride) + 1
            remove[p] = true
        end

        -- compute new index for each particle (prefix sum)
        local new_index = {}
        local write = 0
        for read = 1, total_particles do
            if not remove[read] then
                write = write + 1
                new_index[read] = write
            end
        end

        -- compact particle data
        for read = 1, total_particles do
            local write_i = new_index[read]
            if write_i and write_i ~= read then
                local src = (read  - 1) * stride + 1
                local dst = (write_i - 1) * stride + 1
                for o = 0, stride - 1 do
                    data[dst + o] = data[src + o]
                end
            end
        end

        -- truncate array (only table.remove usage)
        for i = write * stride + 1, #data do
            data[i] = nil
        end

        -- update only affected batches
        for _, batch in pairs(self._batch_id_to_batch) do
            local list = batch[list_name]
            if list ~= nil then
                local old_count = #list
                local write_pos = 1
                for read_pos = 1, old_count do
                    local old_base_index = list[read_pos]
                    local old_particle_id = math.floor((old_base_index - 1) / stride) + 1
                    local new_particle_id = new_index[old_particle_id]
                    if new_particle_id then
                        list[write_pos] = (new_particle_id - 1) * stride + 1
                        write_pos = write_pos + 1
                    end
                end

                for i = write_pos, old_count do list[i] = nil end
            end
        end
    end

    remove_particles(indices, self._data, "particle_indices")

    self:_update_data_mesh()
    self:_update_color_mesh()
end

--- @brief [internal] write new color for all particles
--- @private
function rt.FluidSimulation:_update_particle_color(batch)
    local particles = self._data
    local r, g, b, a = batch.config.color:unpack()
    for _, particle_i in ipairs(batch.particle_indices) do
        local i = _particle_i_to_data_offset(particle_i)
        particles[i + _r_offset] = r
        particles[i + _g_offset] = g
        particles[i + _b_offset] = b
        particles[i + _a_offset] = a
    end
end

--- @brief [internal] recompute batch centroid
--- @private
function rt.FluidSimulation:_update_batch_centroid(batch)
    local x, y = 0, 0
    for _, i in ipairs(batch.particle_indices) do
        x = x + self._data[i + _x_offset]
        y = y + self._data[i + _y_offset]
    end

    batch.centroid_x = x / batch.n_particles
    batch.centroid_y = y / batch.n_particles
end

do
    -- parameter to type and bounds for error handling
    local _valid_config_keys = {
        damping = {
            type = "Number",
            min = 0,
            max = 1
        },

        color = {
            type = "color",
        },

        outline_color = {
            type = "color",
        },

        outline_thickness = {
            type = "Number",
            min = 0
        },

        collision_strength = {
            type = "Number",
            min = 0,
            max = 1
        },

        collision_overlap_factor = {
            type = "Number",
            min = 0,
            max = nil
        },

        cohesion_strength = {
            type = "Number",
            min = 0,
            max = 1
        },

        cohesion_interaction_distance_factor = {
            type = "Number",
            min = 0,
            max = nil
        },

        follow_strength = {
            type = "Number",
            min = 0,
            max = 1
        },

        min_radius = {
            type = "Number",
            min = 0,
            max = nil
        },

        max_radius = {
            type = "Number",
            min = 0,
            max = nil
        },

        min_mass = {
            type = "Number",
            min = 0,
            max = nil
        },

        max_mass = {
            type = "Number",
            min = 0,
            max = nil
        },

        batch_radius = {
            type = "Number",
            min = 0,
            max = nil
        },

        motion_blur = {
            type = "Number",
            min = 0,
            max = 1
        },

        texture_scale = {
            type = "Number",
            min = 1,
            max = nil
        },

        highlight_strength = {
            type = "Number",
            min = 0,
            max = nil
        },

        shadow_strength = {
            type = "Number",
            min = 0,
            max = nil
        }
    }

    --- @brief [internal] override config setting
    --- @private
    function rt.FluidSimulation:_load_config(batch_id, config)
        local error = function(...)
            rt.error("In rt.FluidSimulation.set_config: ", ...)
        end

        local warning = function(...)
            rt.warning("In rt.FluidSimulation.set_config: ", ...)
        end

        local batch = self._batch_id_to_batch[batch_id]
        if batch == nil then
            rt.error("In rt.FluidSimulation._load_config: no batch with id `", batch_id, "`")
            return
        end

        for key, value in pairs(config) do
            local entry = _valid_config_keys[key]
            if entry == nil then
                warning("unrecognized config key `", key, "`, it will be ignored")
                goto ignore
            end

            if entry.type == "color" then
                -- assert value is rgba table
                if not meta.isa(value, rt.RGBA) then
                    error("expected `rt.RGBA`, got `", meta.typeof(value), "`")
                end
            else
                -- assert type and bounds
                if entry.type ~= nil and meta.typeof(value) ~= entry.type then
                    error("wrong type for config key `", key, "`, expected `", entry.type, "`, got `", meta.typeof(value), "`")
                    return
                elseif entry.type ~= nil and entry.type == "Number" and math.is_nan(value) then
                    warning("config key `", key, "` is NaN, it will be ignored")
                    goto ignore
                elseif entry.min ~= nil and value < entry.min then
                    warning("config key `", key, "`'s value is `", value, "`, expected a value larger than `", entry.min, "`")
                    value = math.max(value, entry.min)
                elseif entry.max ~= nil and value > entry.max then
                    warning("config key `", key, "`'s value is `", value, "`, expected a value smaller than `", entry.max, "`")
                    value = math.min(value, entry.max)
                end
            end

            batch.config[key] = value

            self._mass_changed = string.contains(key, "mass")
            self._particle_radius_changed = string.contains(key, "radius")
            self._batch_radius_changed = string.contains(key, "batch_radius")

            ::ignore::
        end
        self._mass_changed = true --string.contains(key, "mass")
        self._particle_radius_changed = true--string.contains(key, "radius")
        self._batch_radius_changed = true --string.contains(key, "batch_radius")

    end
end

-- ### STEP HELPERS ### --
do
    -- table.clear, fallback implementations for non-luajit
    pcall(require, "table.clear")
    if not table.clear then
        function table.clear(t)
            for key in pairs(t) do
                t[key] = nil
            end
            return t
        end
    end

    --- convert config strength to XPBD compliance parameters
    local function _strength_to_compliance(strength, sub_step_delta)
        local alpha = 1 - math.clamp(strength, 0, 1)
        local alpha_per_substep = alpha / (sub_step_delta^2)
        return alpha_per_substep
    end

    --- setup environment
    local _create_environment = function(current_env)
        if current_env == nil then
            -- create new environment
            return {
                particles = {}, -- Table<Number>, particle properties stored inline
                collided = {}, -- Set<Number> particle pair hash

                spatial_hash = {}, -- Table<Number, Table<Number>> particle cell hash to list of particles

                damping = 1, -- overridden in _step

                min_x = math.huge, -- particle position bounds, px
                min_y = math.huge,
                max_x = -math.huge,
                max_y = -math.huge,

                n_particles = 0,

                center_of_mass_x = 0, -- set in post-solve, px
                center_of_mass_y = 0,
                centroid_x = 0,
                centroid_y = 0,

                should_update_follow = true,
                should_update_batch_radius = true,
                should_update_mass = true,
                should_update_particle_radius = true
            }
        else
            -- if old env present, keep allocated to keep gc / allocation pressure low
            local env = current_env

            -- reset tables
            table.clear(env.spatial_hash)
            table.clear(env.collided)

            -- reset variables
            env.min_x = math.huge
            env.min_y = math.huge
            env.max_x = -math.huge
            env.max_y = -math.huge
            env.centroid_x = 0
            env.centroid_y = 0

            return env
        end
    end

    --- pre solve: integrate velocity and update last position
    local _pre_solve = function(
        particles, n_particles,
        damping, delta,
        should_update_follow,
        should_update_radius,
        should_update_mass,
        should_update_batch_radius,
        batch_id_to_batch
    )
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset

            local x, y = particles[x_i], particles[y_i]

            particles[i + _previous_x_offset] = x
            particles[i + _previous_y_offset] = y

            local velocity_x = particles[velocity_x_i] * damping
            local velocity_y = particles[velocity_y_i] * damping

            particles[velocity_x_i] = velocity_x
            particles[velocity_y_i] = velocity_y

            particles[x_i] = x + delta * velocity_x
            particles[y_i] = y + delta * velocity_y

            local batch_id = particles[i + _batch_id_offset]
            local batch = batch_id_to_batch[batch_id]

            if should_update_follow then
                particles[i + _follow_x_offset] = batch.follow_x
                particles[i + _follow_y_offset] = batch.follow_y
            end

            if should_update_mass then
                local mass = math.mix(
                    batch.config.min_mass, batch.config.max_mass,
                    particles[i + _mass_t_offset]
                )
                particles[i + _mass_offset] = mass
                particles[i + _inverse_mass_offset] = 1 / mass
            end

            if should_update_radius then
                particles[i + _radius_offset] = math.mix(
                    batch.config.min_radius, batch.config.max_radius,
                    particles[i + _radius_t_offset]
                )
            end

            if should_update_batch_radius then
                particles[i + _batch_radius_offset] = batch.config.batch_radius
            end
        end
    end

    --- make particles move towards target
    local _solve_follow_constraint = function(
        particles, n_particles, batch_id_to_radius,
        compliance
    )
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local inverse_mass_i = i + _inverse_mass_offset
            local batch_id_i = i + _batch_id_offset
            local radius_i = i + _radius_offset

            local batch_id = particles[batch_id_i]
            local follow_x = particles[i + _follow_x_offset]
            local follow_y = particles[i + _follow_y_offset]

            local x, y = particles[x_i], particles[y_i]
            local current_distance = math.distance(x, y, follow_x, follow_y)
            local target_distance = particles[i + _batch_radius_offset]

            -- XPBD: enforce distance constraint with compliance
            local inverse_mass = particles[inverse_mass_i]
            if inverse_mass < math.eps then return end

            local dx, dy = math.normalize(follow_x - x, follow_y - y)

            local constraint_violation = current_distance - target_distance
            local delta_lambda = constraint_violation / (inverse_mass + compliance)

            local x_correction = dx * delta_lambda * inverse_mass
            local y_correction = dy * delta_lambda * inverse_mass

            particles[x_i] = particles[x_i] + x_correction
            particles[y_i] = particles[y_i] + y_correction
        end
    end

    --- szudzik's pairing function, converts x, y integer index to hash
    local _xy_to_hash = function(x, y)
        local a = x >= 0 and (x * 2) or (-x * 2 - 1)
        local b = y >= 0 and (y * 2) or (-y * 2 - 1)

        if a >= b then
            return a * a + a + b
        else
            return b * b + a
        end
    end

    --- repopulate spatial hash for later positional queries
    local _rebuild_spatial_hash = function(particles, n_particles, spatial_hash, spatial_hash_cell_radius)
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x = i + _x_offset
            local y = i + _y_offset
            local hash_cell_x = i + _cell_x_offset
            local hash_cell_y = i + _cell_y_offset

            local cell_x = math.floor(particles[x] / spatial_hash_cell_radius)
            local cell_y = math.floor(particles[y] / spatial_hash_cell_radius)

            -- store in particle data for later access
            particles[hash_cell_x] = cell_x
            particles[hash_cell_y] = cell_y

            -- convert to hash, then store in that cell
            local hash = _xy_to_hash(cell_x, cell_y)
            local entry = spatial_hash[hash]
            if entry == nil then
                entry = {}
                spatial_hash[hash] = entry
            end

            table.insert(entry, particle_i)
        end
    end

    -- XPBD: enforce distance between two particles to be a specific value
    local function _enforce_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        compliance
    )
        local dx = bx - ax
        local dy = by - ay

        local current_distance = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)

        local constraint_violation = current_distance - target_distance

        local mass_sum = inverse_mass_a + inverse_mass_b

        local divisor = (mass_sum + compliance)
        if divisor < math.eps then return 0, 0, 0, 0 end

        local correction = -constraint_violation / divisor

        local max_correction = math.abs(constraint_violation)
        correction = math.clamp(correction, -max_correction, max_correction)

        local a_correction_x = -dx * correction * inverse_mass_a
        local a_correction_y = -dy * correction * inverse_mass_a

        local b_correction_x =  dx * correction * inverse_mass_b
        local b_correction_y =  dy * correction * inverse_mass_b

        return a_correction_x, a_correction_y, b_correction_x, b_correction_y
    end

    --- enforce collision and cohesion
    local function _solve_collision(
        particles, n_particles,
        spatial_hash, collided,
        collision_overlap_factor, collision_compliance,
        cohesion_interaction_distance_factor, cohesion_compliance,
        max_n_collisions
    )
        local n_collided = 0
        for self_particle_i = 1, n_particles do
            local self_i = _particle_i_to_data_offset(self_particle_i)
            local self_x_i = self_i + _x_offset
            local self_y_i = self_i + _y_offset

            local self_inverse_mass = particles[self_i + _inverse_mass_offset]
            local self_radius = particles[self_i + _radius_offset]
            local self_batch_id = particles[self_i + _batch_id_offset]

            local cell_x = particles[self_i + _cell_x_offset]
            local cell_y = particles[self_i + _cell_y_offset]

            for x_offset = -1, 1 do
                for y_offset = -1, 1 do
                    local spatial_hash_hash = _xy_to_hash(
                        cell_x + x_offset,
                        cell_y + y_offset
                    )

                    local entry = spatial_hash[spatial_hash_hash]
                    if entry == nil then goto next_index end

                    for _, other_particle_i in ipairs(entry) do

                        -- avoid collision with self
                        if self_particle_i == other_particle_i then goto next_pair end

                        -- only collide each unique pair once
                        local pair_hash = _xy_to_hash(
                            math.min(self_particle_i, other_particle_i),
                            math.max(self_particle_i, other_particle_i)
                        )

                        if collided[pair_hash] == true then goto next_pair end
                        collided[pair_hash] = true

                        local other_i = _particle_i_to_data_offset(other_particle_i)
                        local other_x_i = other_i + _x_offset
                        local other_y_i = other_i + _y_offset

                        local other_inverse_mass = particles[other_i + _inverse_mass_offset]
                        local other_radius = particles[other_i + _radius_offset]
                        local other_batch_id = particles[other_i + _batch_id_offset]

                        -- degenerate particle data
                        if self_inverse_mass + other_inverse_mass < math.eps then goto next_pair end

                        do -- cohesion: move particles in the same batch towards each other
                            local self_x, self_y, other_x, other_y =
                            particles[self_x_i],  particles[self_y_i],
                            particles[other_x_i],  particles[other_y_i]

                            local interaction_distance
                            if self_batch_id == other_batch_id then
                                interaction_distance = 0
                            else
                                interaction_distance = cohesion_interaction_distance_factor * (self_radius + other_radius)
                            end

                            if self_batch_id == other_batch_id and
                                math.squared_distance(self_x, self_y, other_x, other_y) <= interaction_distance^2
                            then
                                local self_correction_x, self_correction_y,
                                other_correction_x, other_correction_y = _enforce_distance(
                                    self_x, self_y, other_x, other_y,
                                    self_inverse_mass, other_inverse_mass,
                                    interaction_distance, cohesion_compliance
                                )

                                particles[self_x_i] = self_x + self_correction_x
                                particles[self_y_i] = self_y + self_correction_y
                                particles[other_x_i] = other_x + other_correction_x
                                particles[other_y_i] = other_y + other_correction_y
                            end
                        end

                        do -- collision: enforce distance between particles to be larger than minimum
                            local min_distance = collision_overlap_factor * (self_radius + other_radius)

                            local self_x, self_y, other_x, other_y =
                            particles[self_x_i],  particles[self_y_i],
                            particles[other_x_i],  particles[other_y_i]

                            local distance = math.squared_distance(self_x, self_y, other_x, other_y)

                            if distance <= min_distance^2 then
                                local self_correction_x, self_correction_y,
                                other_correction_x, other_correction_y = _enforce_distance(
                                    self_x, self_y, other_x, other_y,
                                    self_inverse_mass, other_inverse_mass,
                                    min_distance, collision_compliance
                                )

                                particles[self_x_i] = self_x + self_correction_x
                                particles[self_y_i] = self_y + self_correction_y
                                particles[other_x_i] = other_x + other_correction_x
                                particles[other_y_i] = other_y + other_correction_y
                            end
                        end

                        -- emergency safety check, if too many particles cluster together this avoids slowdown
                        n_collided = n_collided + 1
                        if n_collided >= max_n_collisions then return end

                        ::next_pair::
                    end
                    ::next_index::
                end
            end
        end
    end

    --- update true velocity, get aabb and centroid
    local function _post_solve(particles, n_particles, delta)
        local min_x, min_y = math.huge, math.huge
        local max_x, max_y = -math.huge, -math.huge
        local centroid_x, centroid_y = 0, 0

        local max_velocity = 0
        local max_radius = 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local previous_x_i = i + _previous_x_offset
            local previous_y_i = i + _previous_y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset
            local radius_i = i + _radius_offset

            local x = particles[x_i]
            local y = particles[y_i]

            local velocity_x = (x - particles[previous_x_i]) / delta
            local velocity_y = (y - particles[previous_y_i]) / delta
            particles[velocity_x_i] = velocity_x
            particles[velocity_y_i] = velocity_y

            local velocity_magnitude = math.magnitude(velocity_x, velocity_y)
            if velocity_magnitude > max_velocity then
                max_velocity = velocity_magnitude
            end

            centroid_x = centroid_x + x
            centroid_y = centroid_y + y

            -- log AABB including particle radius
            local r = particles[radius_i]
            if r > max_radius then max_radius = r end
            min_x = math.min(min_x, x - r)
            min_y = math.min(min_y, y - r)
            max_x = math.max(max_x, x + r)
            max_y = math.max(max_y, y + r)
        end

        if n_particles > 0 then
            centroid_x = centroid_x / n_particles
            centroid_y = centroid_y / n_particles
        end

        return min_x, min_y, max_x, max_y, centroid_x, centroid_y, max_radius, max_velocity
    end

    --- @brief [internal] step the simulation
    --- @private
    function rt.FluidSimulation:_step(delta, n_sub_steps, n_collision_steps)
        local sub_delta = math.max(delta / n_sub_steps, math.eps)

        local function update_environment(old_env, config, particles, n_particles)
            local env = _create_environment(old_env)
            env.particles = particles
            env.n_particles = n_particles

            if old_env ~= nil then
                env.should_update_mass = self._mass_changed
                env.should_update_particle_radius = self._particle_radius_changed
                env.should_update_batch_radius = self._batch_radius_changed
                env.should_update_follow = self._follow_changed

                self._mass_changed = false
                self._particle_radius_changed = false
                self._batch_radius_changed = false
                self._follow_changed = false
            else
                env.should_update_follow = true
                env.should_update_mass = true
                env.should_update_particle_radius = true
                env.should_update_batch_radius = true
            end

            env.min_mass = config.min_mass
            env.max_mass = config.max_mass
            env.min_radius = config.min_radius
            env.max_radius = config.max_radius

            env.texture_scale = config.texture_scale
            env.motion_blur = config.motion_blur

            -- collision budget, limit maximum number of collisions processed per step
            -- this is to guard against all particles being so close together that the
            -- number of collision explodes
            local fraction = self._max_collision_fraction
            env.max_n_collisions = fraction * env.n_particles^2

            -- compute spatial hash cell radius to cover both collision and cohesion radii
            local max_factor = math.max(
                config.collision_overlap_factor,
                config.cohesion_interaction_distance_factor
            )
            env.spatial_hash_cell_radius = math.max(1, config.max_radius * max_factor)

            env.damping = 1 - math.clamp(config.damping, 0, 1)

            env.follow_compliance = _strength_to_compliance(config.follow_strength, sub_delta)
            env.collision_compliance = _strength_to_compliance(config.collision_strength, sub_delta)
            env.cohesion_compliance = _strength_to_compliance(config.cohesion_strength, sub_delta)
            return env
        end

        local env = update_environment(
            self._last_env, self._default_config,
            self._data, self._total_n_particles
        )

        -- update pre-step positions for frame interpolation
        local update_last_positions = function(env)
            local particles = env.particles
            local sum_x, sum_y = 0, 0
            for particle_i = 1, env.n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local x = particles[i + _x_offset]
                local y = particles[i + _y_offset]
                particles[i + _last_update_x_offset] = x
                particles[i + _last_update_y_offset] = y
                sum_x = sum_x + x
                sum_y = sum_y + y
            end

            if env.n_particles > 0 then
                env.last_centroid_x = sum_x / env.n_particles
                env.last_centroid_y = sum_y / env.n_particles
            else
                env.last_centroid_x = 0
                env.last_centroid_y = 0
            end
        end

        update_last_positions(env)

        -- step the simulation
        for sub_step_i = 1, n_sub_steps do
            _pre_solve(
                env.particles,
                env.n_particles,
                env.damping,
                sub_delta,
                env.should_update_follow,
                env.should_update_particle_radius,
                env.should_update_mass,
                env.should_update_batch_radius,
                self._batch_id_to_batch
            )

            _solve_follow_constraint(
                env.particles,
                env.n_particles,
                env.batch_id_to_radius,
                env.follow_compliance
            )

            for collision_i = 1, n_collision_steps do
                _rebuild_spatial_hash(
                    env.particles,
                    env.n_particles,
                    env.spatial_hash,
                    env.spatial_hash_cell_radius
                )

                _solve_collision(
                    env.particles,
                    env.n_particles,
                    env.spatial_hash,
                    env.collided,
                    self._default_config.collision_overlap_factor,
                    env.collision_compliance,
                    self._default_config.cohesion_interaction_distance_factor,
                    env.cohesion_compliance,
                    env.max_n_collisions
                )

                if collision_i < n_collision_steps then
                    -- clear after each pass to avoid double counting
                    -- do not clear on last, already done in _update_environment
                    table.clear(env.spatial_hash)
                    table.clear(env.collided)
                end
            end

            env.min_x, env.min_y,
            env.max_x, env.max_y,
            env.centroid_x, env.centroid_y,
            env.max_radius, env.max_velocity = _post_solve(
                env.particles,
                env.n_particles,
                sub_delta
            )
        end -- sub-steps

        -- after solver, resize render textures if necessary
        local function resize_canvas_maybe(canvas, env)
            if env.n_particles == 0 then
                return canvas
            end

            local current_w, current_h = 0, 0
            if canvas ~= nil then
                current_w, current_h = canvas:get_size()
            end

            -- compute canvas padding
            local padding = env.max_radius * env.texture_scale
                * (1 +  math.max(1, env.max_velocity) * env.motion_blur)

            local new_w = math.ceil((env.max_x - env.min_x) + 2 * padding)
            local new_h = math.ceil((env.max_y - env.min_y) + 2 * padding)

            -- safety check, so canvases isn't unbounded on instable behavior
            new_w = math.min(new_w, 2560)
            new_h = math.min(new_h, 2560)

            -- reallocate if canvases needs to grow
            if new_w > current_w or new_h > current_h then
                local new_canvas = rt.RenderTexture(
                    math.max(new_w, current_w),
                    math.max(new_h, current_h),
                    self._canvas_msaa,
                    self._render_texture_format
                )
                new_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

                if canvas ~= nil then
                    canvas:free() -- free old as early as possible, uses a lot of vram
                end
                return new_canvas
            else
                return canvas
            end
        end

        self._canvas = resize_canvas_maybe(self._canvas, env)

        -- keep env of last step
        self._last_env = env

        self._canvases_need_update = true

        for _, batch in pairs(self._batch_id_to_batch) do
            batch.centroid_needs_update = true
        end
    end
end -- step helpers

do
    --- @brief [internal] update canvases with particle data
    --- @private
    function rt.FluidSimulation:_update_canvases()
        if self._canvases_need_update == false
            or self._canvas == nil
        then return end

        local t = self._interpolation_alpha
        local draw_particles = function(env, instance_mesh)
            -- frame interpolation for the centroid
            local predicted_centroid_x = math.mix(env.last_centroid_x or env.centroid_x, env.centroid_x, t)
            local predicted_centroid_y = math.mix(env.last_centroid_y or env.centroid_y, env.centroid_y, t)

            love.graphics.push()
            love.graphics.translate(-predicted_centroid_x, -predicted_centroid_y)
            love.graphics.setColor(1, 1, 1, 1)
            instance_mesh:draw_instanced(env.n_particles)
            love.graphics.pop()
        end

        love.graphics.push("all")
        love.graphics.reset()

        -- alpha is accumulated by additive blending, then normalized to 0, 1 automatically
        love.graphics.setBlendMode("screen", "premultiplied")

        self._instanced_draw_shader:bind()
        self._instanced_draw_shader:send("interpolation_alpha", t)

        local canvas = self._canvas
        local canvas_width, canvas_height = canvas:get_size()
        local env = self._last_env
        self._instanced_draw_shader:send("motion_blur", env.motion_blur)
        self._instanced_draw_shader:send("texture_scale", env.texture_scale)
        canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        love.graphics.translate(canvas_width / 2, canvas_height / 2)
        draw_particles(self._last_env, self._instance_mesh)
        love.graphics.pop()

        canvas:unbind()

        self._instanced_draw_shader:unbind()

        love.graphics.pop() -- all
        self._canvases_need_update = false
    end

    --- @brief [internal] composite canvases to final image
    --- @private
    function rt.FluidSimulation:_draw_canvases()
        if self._canvas == nil then return end

        love.graphics.push("all")
        love.graphics.setBlendMode("alpha", "alphamultiply")

        -- reuse threshold parameters
        self._outline_shader:send("threshold", self._thresholding_threshold)

        self._lighting_shader:send("threshold", self._thresholding_threshold)
        self._lighting_shader:send("smoothness", self._thresholding_smoothness)
        self._lighting_shader:send("use_particle_color", true)

        local draw_canvas = function(canvas, env, config)
            local canvas_width, canvas_height = canvas:get_size()
            local canvas_x = env.centroid_x - 0.5 * canvas_width
            local canvas_y = env.centroid_y - 0.5 * canvas_height

            local color = config.color
            local outline_color = config.outline_color
            local outline_thickness = config.outline_thickness

            if outline_thickness > 0 then
                self._outline_shader:bind()
                self._outline_shader:send("outline_thickness", outline_thickness)
                love.graphics.setColor(outline_color:unpack())
                canvas:draw(canvas_x, canvas_y)
                self._outline_shader:unbind()
            end

            love.graphics.setColor(color:unpack())
            self._lighting_shader:bind()

            self._lighting_shader:send("highlight_strength", config.highlight_strength)
            self._lighting_shader:send("use_highlight",
                config.highlight_strength > 0 and self._use_lighting
            )

            self._lighting_shader:send("shadow_strength", config.shadow_strength)
            self._lighting_shader:send("use_shadow",
                config.shadow_strength > 0 and self._use_lighting
            )

            canvas:draw(canvas_x, canvas_y)

            self._lighting_shader:unbind()
        end

        draw_canvas(self._canvas,
            self._last_env,
            self._default_config
        )

        love.graphics.pop()
    end
end

--- @brief [internal]
function rt.FluidSimulation:_distribute_particles(polygon_tris, circle_i_to_radius)
    local N = #circle_i_to_radius
    if N == 0 then return {} end
    if polygon_tris == nil or #polygon_tris == 0 then return {} end

    -- Local aliases for performance and fallback RNG
    local sqrt, abs, max, min, floor = math.sqrt, math.abs, math.max, math.min, math.floor
    local random = (love and love.math and love.math.random) or math.random
    local distance, cross, mix = math.distance, math.cross, math.mix
    local EPS = math.eps or 1e-9
    local SQRT3 = sqrt(3.0)

    -- Precompute triangle stats and global bbox
    local tri_count = #polygon_tris
    local tri_areas = {}
    local total_area = 0.0
    local minx, miny = 1/0, 1/0
    local maxx, maxy = -1/0, -1/0

    -- For faster barycentric sampling: store triangle bases: a, ab, ac per tri
    -- Layout: [ax,ay, abx,aby, acx,acy] per triangle
    local tri_basis = {}
    tri_basis[6 * tri_count] = nil

    for i = 1, tri_count do
        local t = polygon_tris[i]
        local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
        local abx, aby = bx - ax, by - ay
        local acx, acy = cx - ax, cy - ay
        local area = 0.5 * abs(cross(abx, aby, acx, acy))
        tri_areas[i] = area
        total_area = total_area + area

        local base = (i - 1) * 6
        tri_basis[base + 1] = ax
        tri_basis[base + 2] = ay
        tri_basis[base + 3] = abx
        tri_basis[base + 4] = aby
        tri_basis[base + 5] = acx
        tri_basis[base + 6] = acy

        -- bbox accumulation
        local tminx = min(ax, min(bx, cx))
        local tmaxx = max(ax, max(bx, cx))
        local tminy = min(ay, min(by, cy))
        local tmaxy = max(ay, max(by, cy))
        if tminx < minx then minx = tminx end
        if tmaxx > maxx then maxx = tmaxx end
        if tminy < miny then miny = tminy end
        if tmaxy > maxy then maxy = tmaxy end
    end
    if total_area <= EPS then
        return {}
    end

    -- Build Walker alias table for O(1) triangle sampling
    -- prob[i] in [0,1], alias[i] in [1..tri_count]
    local prob = {}
    local alias = {}
    prob[tri_count] = nil
    alias[tri_count] = nil

    do
        -- Normalize areas
        local scaled = {}
        scaled[tri_count] = nil
        local inv_total = 1.0 / total_area
        for i = 1, tri_count do
            scaled[i] = tri_areas[i] * inv_total * tri_count
        end
        -- Worklists
        local small, large = {}, {}
        for i = 1, tri_count do
            if scaled[i] < 1.0 then
                small[#small+1] = i
            else
                large[#large+1] = i
            end
        end
        while #small > 0 and #large > 0 do
            local l = small[#small]; small[#small] = nil
            local g = large[#large]; large[#large] = nil
            prob[l] = scaled[l]
            alias[l] = g
            scaled[g] = (scaled[g] + scaled[l]) - 1.0
            if scaled[g] < 1.0 then
                small[#small+1] = g
            else
                large[#large+1] = g
            end
        end
        while #large > 0 do
            local g = large[#large]; large[#large] = nil
            prob[g] = 1.0
            alias[g] = g
        end
        while #small > 0 do
            local l = small[#small]; small[#small] = nil
            prob[l] = 1.0
            alias[l] = l
        end
    end

    -- O(1) sample of a triangle index
    local function sample_triangle_index()
        -- random() in [0,1), scale by tri_count
        local r = random() * tri_count
        local k = floor(r) + 1
        local frac = r - floor(r)
        if frac < prob[k] then
            return k
        else
            return alias[k]
        end
    end

    -- Uniform sample inside polygon by:
    -- 1) Choose triangle with alias sampler
    -- 2) Barycentric sample inside chosen triangle using bases
    local function sample_point_in_polygon()
        local tri_index = sample_triangle_index()
        -- Barycentric fold
        local u = random()
        local v = random()
        if (u + v) > 1.0 then
            u = 1.0 - u
            v = 1.0 - v
        end
        local base = (tri_index - 1) * 6
        local ax = tri_basis[base + 1]
        local ay = tri_basis[base + 2]
        local abx = tri_basis[base + 3]
        local aby = tri_basis[base + 4]
        local acx = tri_basis[base + 5]
        local acy = tri_basis[base + 6]
        local px = ax + u * abx + v * acx
        local py = ay + u * aby + v * acy
        return px, py
    end

    -- Initial centers: triangular lattice inside polygon.
    -- Lattice spacing 'a' estimated from polygon area and number of circles.
    local a = sqrt((2.0 * total_area) / (SQRT3 * N))
    a = a * 0.95
    local h = a * (SQRT3 * 0.5)

    -- Point-in-triangle for lattice filtering (triangles tessellate the polygon)
    local function point_in_triangle(px, py, ax, ay, bx, by, cx, cy)
        local c1 = cross(bx - ax, by - ay, px - ax, py - ay)
        local c2 = cross(cx - bx, cy - by, px - bx, py - by)
        local c3 = cross(ax - cx, ay - cy, px - cx, py - cy)
        local has_neg = (c1 < -EPS) or (c2 < -EPS) or (c3 < -EPS)
        local has_pos = (c1 > EPS) or (c2 > EPS) or (c3 > EPS)
        return not (has_neg and has_pos)
    end

    -- For lattice inclusion, accelerate "point in polygon (triangulation)" by
    -- checking each triangle's bbox and doing the triangle test.
    -- This is kept simple since this step runs once, while Lloyd runs multiple times.
    local tri_bbox = {}
    tri_bbox[4 * tri_count] = nil
    do
        for i = 1, tri_count do
            local t = polygon_tris[i]
            local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
            local tminx = min(ax, min(bx, cx))
            local tmaxx = max(ax, max(bx, cx))
            local tminy = min(ay, min(by, cy))
            local tmaxy = max(ay, max(by, cy))
            local base = (i - 1) * 4
            tri_bbox[base + 1] = tminx
            tri_bbox[base + 2] = tmaxx
            tri_bbox[base + 3] = tminy
            tri_bbox[base + 4] = tmaxy
        end
    end

    local function point_in_polygon(px, py)
        for i = 1, tri_count do
            local bb = (i - 1) * 4
            local tminx = tri_bbox[bb + 1]
            local tmaxx = tri_bbox[bb + 2]
            local tminy = tri_bbox[bb + 3]
            local tmaxy = tri_bbox[bb + 4]
            if px >= tminx and px <= tmaxx and py >= tminy and py <= tmaxy then
                local t = polygon_tris[i]
                if point_in_triangle(px, py, t[1], t[2], t[3], t[4], t[5], t[6]) then
                    return true
                end
            end
        end
        return false
    end

    -- Build lattice points within expanded bbox, filter by polygon inclusion
    local candidates = {}
    local row = 0
    local y = miny - h
    local y_end = maxy + h
    while y <= y_end do
        local x_offset = ((row % 2) ~= 0) and (a * 0.5) or 0.0
        local x = (minx - a) + x_offset
        local x_end = maxx + a
        while x <= x_end do
            if point_in_polygon(x, y) then
                candidates[#candidates+1] = x
                candidates[#candidates+1] = y
            end
            x = x + a
        end
        row = row + 1
        y = y + h
    end

    -- Top up if not enough lattice points (use uniform sampling inside polygon)
    local need = N - floor(#candidates / 2)
    if need > 0 then
        for _ = 1, need do
            local sx, sy = sample_point_in_polygon()
            candidates[#candidates+1] = sx
            candidates[#candidates+1] = sy
        end
    end

    -- Shuffle candidates (Fisher-Yates on pairs)
    local cand_pairs = floor(#candidates / 2)
    for i = cand_pairs, 2, -1 do
        local j = 1 + floor(random() * i)
        local ia = (i - 1) * 2 + 1
        local ja = (j - 1) * 2 + 1
        candidates[ia], candidates[ja] = candidates[ja], candidates[ia]
        candidates[ia+1], candidates[ja+1] = candidates[ja+1], candidates[ia+1]
    end

    local centers = {}
    centers[2 * N] = nil
    for i = 1, N do
        local ci = (i - 1) * 2 + 1
        local si = (i - 1) * 2 + 1
        centers[ci] = candidates[si]
        centers[ci+1] = candidates[si+1]
    end

    -- Lloyd parameters (iterations kept modest; acceleration is structural)
    local n_lloyd_iterations = rt.settings.fluid_simulation.n_lloyd_iterations
    local alpha = 0.5
    local radii = circle_i_to_radius
    local tiny = EPS

    -- Preallocate working buffers for reuse
    local sums = {}
    local counts = {}
    sums[2 * N] = nil
    counts[N] = nil

    -- Spatial grid to accelerate nearest-center queries
    -- Use lattice spacing 'a' as grid cell size
    local cell = a
    if cell < EPS then cell = 1.0 end
    local inv_cell = 1.0 / cell
    local grid_w = max(1, floor((maxx - minx) * inv_cell) + 1)
    local grid_h = max(1, floor((maxy - miny) * inv_cell) + 1)
    local grid_size = grid_w * grid_h
    local grid = {}          -- grid[cell_idx] = array of center indices
    local center_cell_ix = {} -- per-center cached cell index (for rebuilding)

    local function cell_index(ix, iy)
        return iy * grid_w + ix + 1
    end

    local function clampi(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function rebuild_grid()
        for i = 1, grid_size do grid[i] = nil end
        -- Populate grid
        for i = 1, N do
            local ci = (i - 1) * 2 + 1
            local x = centers[ci]
            local y = centers[ci+1]
            local ix = clampi(floor((x - minx) * inv_cell), 0, grid_w - 1)
            local iy = clampi(floor((y - miny) * inv_cell), 0, grid_h - 1)
            local gi = cell_index(ix, iy)
            local bucket = grid[gi]
            if bucket == nil then
                bucket = {}
                grid[gi] = bucket
            end
            bucket[#bucket+1] = i
            center_cell_ix[i] = gi
        end
    end

    local function nearest_center_scaled(sx, sy)
        -- Query around sample's cell, expanding rings until at least one candidate is found.
        local ix = clampi(floor((sx - minx) * inv_cell), 0, grid_w - 1)
        local iy = clampi(floor((sy - miny) * inv_cell), 0, grid_h - 1)

        local best_i = nil
        local best_d = 1/0

        local r = 0
        local maxR = max(grid_w, grid_h)
        while r <= maxR do
            local found_any = false
            local xmin = clampi(ix - r, 0, grid_w - 1)
            local xmax = clampi(ix + r, 0, grid_w - 1)
            local ymin = clampi(iy - r, 0, grid_h - 1)
            local ymax = clampi(iy + r, 0, grid_h - 1)

            for yy = ymin, ymax do
                for xx = xmin, xmax do
                    local gi = cell_index(xx, yy)
                    local bucket = grid[gi]
                    if bucket ~= nil then
                        found_any = true
                        for k = 1, #bucket do
                            local idx = bucket[k]
                            local ci = (idx - 1) * 2 + 1
                            local cx = centers[ci]
                            local cy = centers[ci+1]
                            local denom = max(radii[idx], tiny)
                            local d = distance(sx, sy, cx, cy) / denom
                            if d < best_d then
                                best_d = d
                                best_i = idx
                            end
                        end
                    end
                end
            end

            if found_any and best_i ~= nil then
                break
            end
            r = r + 1
        end

        -- Fallback (should be rare): if no buckets found (empty grid), do a linear scan
        if best_i == nil then
            best_i = 1
            local ci = 1
            local denom = max(radii[1], tiny)
            best_d = distance(sx, sy, centers[ci], centers[ci+1]) / denom
            for i = 2, N do
                ci = (i - 1) * 2 + 1
                local d = distance(sx, sy, centers[ci], centers[ci+1]) / max(radii[i], tiny)
                if d < best_d then
                    best_d = d
                    best_i = i
                end
            end
        end

        return best_i
    end

    local function lloyd_iteration()
        -- Zero buffers
        for i = 1, 2 * N do sums[i] = 0.0 end
        for i = 1, N do counts[i] = 0 end

        rebuild_grid()

        -- Monte Carlo samples proportional to N
        local M = min(max(12 * N, 400), 12000)

        for _ = 1, M do
            local sx, sy = sample_point_in_polygon()
            local best_i = nearest_center_scaled(sx, sy)

            local bi = (best_i - 1) * 2 + 1
            sums[bi] = sums[bi] + sx
            sums[bi + 1] = sums[bi + 1] + sy
            counts[best_i] = counts[best_i] + 1
        end

        -- Update centers to centroids (with mixing)
        for i = 1, N do
            local c = counts[i]
            local ci = (i - 1) * 2 + 1
            if c > 0 then
                local meanx = sums[ci] / c
                local meany = sums[ci + 1] / c
                local ox = centers[ci]
                local oy = centers[ci + 1]
                centers[ci] = mix(ox, meanx, alpha)
                centers[ci + 1] = mix(oy, meany, alpha)
            else
                -- Rare: re-seed to a random valid point
                local rx, ry = sample_point_in_polygon()
                centers[ci] = rx
                centers[ci + 1] = ry
            end
        end
    end

    for _ = 1, n_lloyd_iterations do
        lloyd_iteration()
    end

    return centers
end

--[[
rt.settings.fluid_simulation = {
    n_lloyd_iterations = 4
}

--- @class rt.FluidSimulation
rt.FluidSimulation = meta.class("FluidSimulation")

--- @brief create a new simulation handler instance. Usually this function is not called directly, use `instance = rt.FluidSimulation()` instead
--- @return rt.FluidSimulation
function rt.FluidSimulation:instantiate()
    -- default
    local outline_thickness = 1
    local particle_radius = 2
    local base_damping = 0.1
    local texture_scale = 12
    local base_mass = 1

    -- see README.md for a description of the parameters below

    self._default_config = {
        -- dynamic
        damping = base_damping,

        follow_strength = 1 - 0.004,

        cohesion_strength = 1 - 0.9,
        cohesion_interaction_distance_factor = 2,

        collision_strength = 1 - 0.0025,
        collision_overlap_factor = 2,

        color = rt.Palette.YELLOW_5,
        outline_color = rt.Palette.ORANGE_5,
        outline_thickness = outline_thickness,

        highlight_strength = 0,
        shadow_strength = 1,

        -- static
        min_mass = base_mass,
        max_mass = base_mass * 2,

        min_radius = particle_radius,
        max_radius = particle_radius,

        texture_scale = texture_scale,
        motion_blur = 0.0001,

        batch_radius = 0
    }

    -- immutable properties
    self._particle_texture_shader_path = "common/fluid_simulation_particle_texture.glsl"
    self._outline_shader_path = "common/fluid_simulation_outline.glsl"
    self._instanced_draw_shader_path = "common/fluid_simulation_instanced_draw.glsl"
    self._lighting_shader_path = "common/fluid_simulation_lighting.glsl"

    self._thresholding_threshold = 0.3 -- in [0, 1]
    self._thresholding_smoothness = 0.01 -- in [0, threshold_shader_threshold)

    self._mass_distribution_variance = 4 -- unitless, (2 * n) with n >= 1
    self._max_collision_fraction = 0.05 -- fraction
    self._use_lighting = true -- whether specular highlight and shadows should be drawn

    -- render texture config
    self._canvas_msaa = 4 -- msaa for render textures
    self._particle_texture_radius = 40 * rt.get_pixel_scale()
    self._particle_texture_padding = 3 -- px
    self._particle_texture_resolution_factor = 4 -- fraction

    self:_reinitialize()
    return self
end


-- particle properties are stored inline, these are the offset
local _x_offset = 0  -- x position, px
local _y_offset = 1  -- y position, px
local _z_offset = 2  -- render priority
local _velocity_x_offset = 3 -- x velocity, px / s
local _velocity_y_offset = 4 -- y velocity, px / s
local _previous_x_offset = 5 -- last sub steps x position, px
local _previous_y_offset = 6 -- last sub steps y position, px
local _radius_t_offset = 7
local _radius_offset = 8 -- radius, px
local _mass_t_offset = 9
local _mass_offset = 10 -- mass, fraction
local _inverse_mass_offset = 11 -- 1 / mass, precomputed for performance
local _follow_x_offset = 12
local _follow_y_offset = 13
local _cell_x_offset = 14 -- spatial hash x coordinate, set in _step
local _cell_y_offset = 15 -- spatial hash y coordinate
local _batch_id_offset = 16 -- batch id
local _batch_radius_offset = 17
local _r_offset = 18 -- rgba red
local _g_offset = 19 -- rgba green
local _b_offset = 20 -- rgba blue
local _a_offset = 21 -- rgba opacity
local _last_update_x_offset = 22 -- last whole step x position, px
local _last_update_y_offset = 23 -- last whole step x position, px

-- XPBD lambda accumulators (per-particle, per-constraint)
local _follow_lambda_offset   = 24 -- scalar lambda for follow constraint
local _collision_lambda_offset = 25 -- scalar lambda for collision constraints (aggregate)
local _cohesion_lambda_offset  = 26 -- scalar lambda for cohesion constraints (aggregate)

local _stride = _cohesion_lambda_offset + 1

--- convert particle index to index in shared particle property array
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end


--- @brief add a new batch to the simulation
--- @param x number x position, px
--- @param y number y position, px
--- @param radius number? radius of the egg white, px
--- @param color rt.RGBA? color in rgba format, components in [0, 1]
--- @param config table?
--- @return number integer id of the new batch
function rt.FluidSimulation:add(x, y, radius, color, config)
    config = config or table.deepcopy(self._default_config)
    color = color or config.color

    meta.assert(
        x, "Number",
        y, "Number",
        radius, "Number",
        color, rt.RGBA,
        config, "Table"
    )

    config.batch_radius = radius

    local particle_radius = math.mix(
        config.min_radius,
        config.max_radius,
        0.5
    ) -- expected value. symmetrically normal distributed around mean

    local n_particles = math.ceil(
        (math.pi * radius^2) / (math.pi * particle_radius^2)
    ) -- (area of white) / (area of particle), where circular area = pi r^2

    if radius <= 0 then
        rt.error( "In rt.FluidSimulation.add: white radius cannot be 0 or negative")
    end

    if n_particles <= 1 then
        rt.error( "In rt.FluidSimulation.add: white particle count cannot be 1 or negative")
    end

    local warn = function(which, egg_radius, particle_radius, n_particles)
        rt.warning("In rt.FluidSimulation.add: trying to add ", which, " of radius `", egg_radius, "`, but the ", which, " particle radius is `~", particle_radius, "`, so only `", n_particles, "` particles will be created. Consider increasing the ", which, " radius or decreasing the ", which, " particle size")
    end

    if n_particles < 10 then
        warn("white", radius, particle_radius, n_particles)
    end

    self._total_n_particles = self._total_n_particles + n_particles

    local batch_id, batch = self:_new_batch(
        x, y,
        n_particles,
        config
    )

    self._batch_id_to_batch[batch_id] = batch
    self._n_batches = self._n_batches + 1

    return batch_id
end

--- @brief removes a batch from the simulation
--- @param batch_id number id of the batch to remove, acquired from rt.FluidSimulation.add
--- @return nil
function rt.FluidSimulation:remove(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.warning("In rt.FluidSimulation.remove: no batch with id `", batch_id, "`")
        return
    end

    self._batch_id_to_batch[batch_id] = nil
    self._n_batches = self._n_batches - 1
    self._total_n_particles = self._total_n_particles - batch.n_particles

    self:_remove(batch.particle_indices)
end

--- @brief draw all batches
--- @return nil
function rt.FluidSimulation:draw()
    self:_update_canvases()
    self:_draw_canvases()
end

--- @brief update all batches
--- @param step_delta number fixed timestep, seconds
--- @param n_substeps number number of solver iterations per step, integer
--- @param n_collision_steps number number of collision sub steps per iteration step, integer
function rt.FluidSimulation:update(delta, step_delta, n_substeps, n_collision_steps)
    if step_delta == nil then step_delta = 1 / 60 end
    if n_substeps == nil then n_substeps = 2 end
    if n_collision_steps == nil then n_collision_steps = 3 end

    meta.assert(
        delta, "Number",
        step_delta, "Number",
        n_substeps, "Number",
        n_collision_steps, "Number"
    )

    -- catch floats instead of ints
    n_substeps = math.ceil(n_substeps)
    n_collision_steps = math.ceil(n_collision_steps)

    if step_delta < 0 or math.is_nan(step_delta) then
        rt.error("In rt.FluidSimulation.update: `step_delta` is not a number > 0")
        return
    end

    if n_substeps < 1 or math.is_nan(n_substeps) then
        rt.error("In rt.FluidSimulation.update: `n_substeps` is not a number > 0")
        return
    end

    if n_collision_steps < 1 or math.is_nan(n_collision_steps) then
        rt.error("In rt.FluidSimulation.update: `n_collision_steps` is not a number > 0")
        return
    end

    -- accumulate delta time, run sim at fixed framerate for better stability
    self._elapsed = self._elapsed + delta
    local step = step_delta
    local n_steps = 0
    local max_n_steps = math.max(4, 4 * math.ceil((1 / 60) / step_delta))
    while self._elapsed >= step do
        self:_step(step, n_substeps, n_collision_steps)
        self._elapsed = self._elapsed - step

        -- safety check to prevent death spiral
        n_steps = n_steps + 1
        if n_steps > max_n_steps then
            self._elapsed = 0
            break
        end
    end

    self._interpolation_alpha = math.clamp(self._elapsed / step, 0, 1)

    self:_update_data_mesh()
    -- no need to update color mesh
end

--- @brief update the mutable simulation parameters for the white
--- @param config table table of properties, see the readme for a list of valid properties
function rt.FluidSimulation:set_config(batch_id, config)
    if config == nil then config = self._default_config end
    meta.assert(batch_id, "Number", config, "Table")
    self:_load_config(batch_id, config)
end

--- @brief
function rt.FluidSimulation:get_config(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.error( "In rt.FluidSimulation.get_target_position: no batch with id `", batch_id, "`")
        return nil
    else
        return batch.config
    end
end

--- @brief set the target position a batch should move to
--- @param batch_id number batch id returned by rt.FluidSimulation.add
--- @param x number x coordinate, in px
--- @param y number y coordinate, in px
function rt.FluidSimulation:set_target_position(batch_id, x, y)
    meta.assert(batch_id, "Number", x, "Number", y, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.warning( "In rt.FluidSimulation.set_target_position: no batch with id `", batch_id, "`")
    else
        batch.follow_x = x
        batch.follow_y = y
        self._follow_changed = true
    end
end

--- @brief get the target position a batch should move to
--- @return number, number
function rt.FluidSimulation:get_target_position(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.error( "In rt.FluidSimulation.get_target_position: no batch with id `", batch_id, "`")
        return nil, nil
    else
        return batch.follow_x, batch.follow_y
    end
end

--- @brief get average of all particle positions of a batch
function rt.FluidSimulation:get_position(batch_id)
    meta.assert(batch_id, "Number")

    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then
        rt.error( "In rt.FluidSimulation.get_target_position: no batch with id `", batch_id, "`")
        return nil, nil
    else
        if batch.centroid_needs_update then
            self:_update_batch_centroid(batch)
        end

        return batch.centroid_x, batch.centroid_y
    end
end

--- @brief
function rt.FluidSimulation:set_target_shape(batch_id, tris)
    local batch = self._batch_id_to_batch[batch_id]
    if batch == nil then rt.error("In rt.FluidSimulation.set_target_shape: no batch with id `", batch_id, "`") end

    local circle_i_to_radius = table.new(batch.n_particles, 0)
    local min_radius, max_radius = batch.config.min_radius, batch.config.max_radius
    for particle_i = 1, batch.n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        circle_i_to_radius[particle_i] = math.mix(
            min_radius,
            max_radius,
            self._data[i + _radius_t_offset]
        ) -- interpolate in case _step has not yet updated particle radius
    end

    local new_positions = self:_distribute_particles(tris, circle_i_to_radius)

    local particle_i = 1
    for position_i = 1, #new_positions, 2 do
        local i = _particle_i_to_data_offset(particle_i)
        self._data[i + _follow_x_offset] = new_positions[position_i + 0]
        self._data[i + _follow_y_offset] = new_positions[position_i + 1]
        particle_i = particle_i + 1
    end

    self._follow_changed = false -- do not update
end

--- @brief list the ids of all batches
--- @return number[] array of batch ids
function rt.FluidSimulation:list_ids()
    local ids = {}
    for id, _ in pairs(self._batch_id_to_batch) do
        table.insert(ids, id)
    end
    return ids
end

--- @brief get total number of particles
--- @return number
function rt.FluidSimulation:get_n_particles(batch_or_nil)
    if batch_or_nil == nil then
        return self._total_n_particles
    else
        local batch = self._batch_id_to_batch[batch_or_nil]
        if batch == nil then
            rt.error("In rt.FluidSimulation:get_n_particles: no batch with id `", batch_or_nil, "`")
        end
        return batch.n_particles
    end
end

-- ### internals, never call any of the functions below ### --

--- @brief [internal] clear the simulation, useful for debugging
--- @private
function rt.FluidSimulation:_reinitialize()
    -- internal properties
    self._batch_id_to_batch = {} -- Table<Number, Batch>
    self._current_batch_id = 1
    self._n_batches = 0

    self._config_changed = true
    self._follow_changed = true

    -- particle properties are stored inline
    self._data = {}
    self._total_n_particles = 0

    self._data_mesh_data = {}
    self._color_data_mesh_data = {}

    self._max_radius = 1
    self._canvases_need_update = false

    self._elapsed = 0
    self._interpolation_alpha = 0

    self:_initialize_shaders()
    self:_initialize_particle_texture()

    local position_name = "particle_position"
    local velocity_name = "particle_velocity"
    local radius_name = "particle_radius"
    local color_name = "particle_color"

    assert(love.getVersion() >= 12, "Love v12.0 or later required, mesh data format is incompatible with earlier versions")

    do
        -- default love mesh format
        -- location = 0: VertexPosition
        -- location = 1: VertexTexCoord
        -- location = 2: VertexColor

        local i = 2
        self._data_mesh_format = {
            { location = i+1, name = position_name, format = "floatvec4" }, -- xy: position, zw: previous position
            { location = i+2, name = velocity_name, format = "floatvec2" },
            { location = i+3, name = radius_name, format = "float" },
        }

        -- data and color mesh are separate, as only the data mesh changes every
        -- frame, uploading the same color every frame to vram is suboptimal
        self._color_mesh_format = {
            { location = i+4, name = color_name, format = "floatvec4" }
        }
    end

    self:_initialize_instance_mesh()
    self:_update_data_mesh()
    self:_update_color_mesh()

    self._canvas = nil -- rt.RenderTexture

    self._last_env = nil -- cf. _step
    self._render_texture_format = "rgba8"

    -- step once to init environments
    self:_step(0, 1, 1)
end

--- @brief [internal] load and compile necessary shaders
--- @private
function rt.FluidSimulation:_initialize_shaders()
    self._particle_texture_shader = rt.Shader(self._particle_texture_shader_path)
    self._outline_shader = rt.Shader(self._outline_shader_path)
    self._lighting_shader = rt.Shader(self._lighting_shader_path)
    self._instanced_draw_shader = rt.Shader(self._instanced_draw_shader_path)

    -- on vulkan, first use of a shader would cause stutter, so force use here, equivalent to precompiling the shader
    if love.getVersion() >= 12 and love.graphics.getRendererInfo() == "Vulkan" then
        love.graphics.push("all")
        local texture = rt.RenderTexture(1, 1)
        texture:bind()

        for _, shader in ipairs({
            self._particle_texture_shader,
            self._lighting_shader,
            self._outline_shader
        }) do
            shader:bind()
            love.graphics.rectangle("fill", 0, 0, 1, 1)
            shader:unbind()
        end

        texture:unbind()
        love.graphics.pop("all")
    end
end

--- @brief [internal] initialize mass distribution texture used for particle density estimation
--- @private
function rt.FluidSimulation:_initialize_particle_texture()
    -- create particle texture, this will hold density information
    -- we use the same texture for all particles regardless of size,
    -- instead love.graphics.scale'ing based on particle size,
    -- this way all draws are batched

    local radius = self._particle_texture_radius * self._particle_texture_resolution_factor

    local padding = self._particle_texture_padding -- px

    -- create canvas, transparent outer padding so derivative on borders is 0
    local canvas_width = (radius + padding) * 2
    local canvas_height = canvas_width

    self._particle_texture = rt.RenderTexture(
        canvas_width, canvas_height,
        0,
        self._render_texture_format
    )

    self._particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    self._particle_texture:set_wrap_mode(rt.TextureWrapMode.ZERO)

    local x, y, width, height = 0, 0, 2 * radius, 2 * radius

    -- fill particle with density data using shader
    love.graphics.push("all")
    love.graphics.reset()
    self._particle_texture:bind()
    self._particle_texture_shader:bind()

    love.graphics.translate(
        (canvas_width - width) / 2,
        (canvas_height - height) / 2
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, width, height)

    self._particle_texture_shader:unbind()
    self._particle_texture:unbind()
    love.graphics.pop()
end

--- @brief [internal] initialize data related to instanced drawing
--- @private
function rt.FluidSimulation:_initialize_instance_mesh()
    -- 5-vertex quad with side length 1 centered at 0, 0
    local x, y, r = 0, 0, 1
    local mesh = rt.Mesh({
        { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
        { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
        { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
        { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
        { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
    }, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)

    mesh:set_vertex_map(
        1, 2, 3,
        1, 3, 4,
        1, 4, 5,
        1, 5, 2
    )
    mesh:set_texture(self._particle_texture)
    self._instance_mesh = mesh
end

--- @brief [internal] upload vertex data mesh
--- @private
function rt.FluidSimulation:_update_data_mesh()
    local function update_data_mesh(particles, n_particles, instance_mesh, mesh_data, mesh)
        if n_particles == 0 then return nil end
        local before = #mesh_data

        -- update mesh data
        for particle_i = 1, n_particles do
            local current = mesh_data[particle_i]
            if current == nil then
                current = {}
                mesh_data[particle_i] = current
            end

            local i = _particle_i_to_data_offset(particle_i)
            current[1] = particles[i + _x_offset]
            current[2] = particles[i + _y_offset]
            current[3] = particles[i + _last_update_x_offset]
            current[4] = particles[i + _last_update_y_offset]

            current[5] = particles[i + _velocity_x_offset]
            current[6] = particles[i + _velocity_y_offset]

            current[7] = particles[i + _radius_offset]
        end

        while #mesh_data > n_particles do
            table.remove(mesh_data, #mesh_data)
        end

        local after = #mesh_data

        if mesh == nil or before ~= after then
            -- if resized, reallocate mesh
            local data_mesh = rt.Mesh(
                mesh_data,
                rt.MeshDrawMode.TRIANGLES, -- unused, this mesh will never be drawn
                self._data_mesh_format,
                rt.GraphicsBufferUsage.STREAM
            )

            -- attach for rendering
            for _, entry in ipairs(self._data_mesh_format) do
                instance_mesh:attach_attribute(data_mesh, entry.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
            end

            return data_mesh
        else
            -- else upload vertex data
            mesh:replace_data(mesh_data)
            mesh:flush()
            return mesh
        end
    end

    self._data_mesh = update_data_mesh(
        self._data,
        self._total_n_particles,
        self._instance_mesh,
        self._data_mesh_data,
        self._data_mesh
    )
end

--- @brief [internal] upload color mesh data for instanced drawing
--- @private
function rt.FluidSimulation:_update_color_mesh()
    local function update_color_mesh(particles, n_particles, instance_mesh, mesh_data, mesh)
        if n_particles == 0 then return nil end
        local before = #mesh_data

        for particle_i = 1, n_particles do
            local current = mesh_data[particle_i]
            if current == nil then
                current = {}
                mesh_data[particle_i] = current
            end

            local i = _particle_i_to_data_offset(particle_i)
            current[1] = particles[i + _r_offset]
            current[2] = particles[i + _g_offset]
            current[3] = particles[i + _b_offset]
            current[4] = particles[i + _a_offset]
        end

        while #mesh_data > n_particles do
            mesh_data[#mesh_data] = nil
        end

        local after = #mesh_data

        if mesh == nil or before ~= after then
            local color_data_mesh = rt.Mesh(
                mesh_data,
                rt.MeshDrawMode.TRIANGLES, -- unused
                self._color_mesh_format,
                rt.GraphicsBufferUsage.STREAM
            )

            for _, entry in ipairs(self._color_mesh_format) do
                instance_mesh:attach_attribute(color_data_mesh, entry.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
            end

            return color_data_mesh
        else
            mesh:replace_data(mesh_data)
            mesh:flush()
            return mesh
        end
    end

    self._color_data_mesh = update_color_mesh(
        self._data,
        self._total_n_particles,
        self._instance_mesh,
        self._color_data_mesh_data,
        self._color_data_mesh
    )
end

--- @brief [internal] create a new particle batch
--- @private
function rt.FluidSimulation:_new_batch(
    center_x, center_y, n_particles, config
)
    local batch = {
        particle_indices = {},
        color = config.color,
        config = config,
        config_was_updated = true,

        target_x = center_x,
        target_y = center_y,

        centroid_x = center_x,
        centroid_y = center_y,
        centroid_needs_update = true
    }

    -- generate uniformly distributed value in interval
    local random_uniform = function(min, max)
        local t = love.math.random(0, 1)
        return math.mix(min, max, t)
    end

    -- uniformly distribute points across the disk using fibonacci spiral
    local fibonacci_spiral = function(i, n, x_radius, y_radius)
        local golden_ratio = (1 + math.sqrt(5)) / 2
        local golden_angle = 2 * math.pi / (golden_ratio * golden_ratio)

        local r = math.sqrt((i - 1) / n)
        local theta = i * golden_angle

        local x = r * x_radius * math.cos(theta)
        local y = r * y_radius * math.sin(theta)

        return x, y
    end

    -- instead of pure random mass, mass should always be exactly distributed in gaussian-like curve
    local get_mass = function(i, n)
        local variance = self._mass_distribution_variance
        local function butterworth(t)
            return 1 / (1 + (variance * (t - 0.5))^4)
        end

        -- 2-point gauss-legendre integration, reduces aliasing at low particle counts
        local left = (i - 0.5) / n
        local right = (i + 0.5) / n

        local center = 0.5 * (left + right)
        local half_width = 0.5 * (right - left)

        local t1 = center - half_width / math.sqrt(3)
        local t2 = center + half_width / math.sqrt(3)

        return 0.5 * (butterworth(t1) + butterworth(t2))
    end

    -- add particle data to the batch particle property buffer
    local add_particle = function(
        array, config,
        particle_i, n_particles,
        batch_id
    )
        -- generate position
        local dx, dy = fibonacci_spiral(
            particle_i, n_particles,
            config.batch_radius, config.batch_radius
        )

        local x = center_x + dx
        local y = center_y + dy

        -- mass and radius use the same interpolation factor, since volume and mass are correlated
        local t = get_mass(particle_i, n_particles)
        local mass = math.mix(
            config.min_mass,
            config.max_mass,
            t
        )

        local radius = math.mix(config.min_radius, config.max_radius, t)

        local i = #array + 1
        array[i + _x_offset] = x
        array[i + _y_offset] = y
        array[i + _z_offset] = 0
        array[i + _velocity_x_offset] = 0
        array[i + _velocity_y_offset] = 0
        array[i + _previous_x_offset] = x
        array[i + _previous_y_offset] = y
        array[i + _radius_t_offset] = t
        array[i + _radius_offset] = radius
        array[i + _mass_t_offset] = t
        array[i + _mass_offset] = mass
        array[i + _inverse_mass_offset] = 1 / mass
        array[i + _follow_x_offset] = x
        array[i + _follow_y_offset] = y
        array[i + _cell_x_offset] = -math.huge
        array[i + _cell_y_offset] = -math.huge
        array[i + _batch_id_offset] = batch_id
        array[i + _batch_radius_offset] = config.batch_radius
        array[i + _r_offset] = config.color.r
        array[i + _g_offset] = config.color.g
        array[i + _b_offset] = config.color.b
        array[i + _a_offset] = config.color.a

        array[i + _last_update_x_offset] = x
        array[i + _last_update_y_offset] = y

        -- initialize XPBD lambdas
        array[i + _follow_lambda_offset] = 0.0
        array[i + _collision_lambda_offset] = 0.0
        array[i + _cohesion_lambda_offset] = 0.0

        assert(#array - i == _stride - 1)

        self._max_radius = math.max(self._max_radius, radius)
        return i
    end

    local batch_id = self._current_batch_id
    self._current_batch_id = self._current_batch_id + 1

    for i = 1, n_particles do
        table.insert(batch.particle_indices, add_particle(
            self._data,
            batch.config,
            i, n_particles,
            batch_id
        ))
    end

    batch.n_particles = n_particles

    self:_update_data_mesh()
    self:_update_color_mesh()

    return batch_id, batch
end

--- @brief [internal] remove particle data from shared array
--- @private
function rt.FluidSimulation:_remove(indices)
    local function remove_particles(indices, data, list_name)
        if not indices or #indices == 0 then return end

        local stride = _stride
        local total_particles = #data / stride

        -- mark particles to remove
        local remove = {}
        for _, base in ipairs(indices) do
            local p = math.floor((base - 1) / stride) + 1
            remove[p] = true
        end

        -- compute new index for each particle (prefix sum)
        local new_index = {}
        local write = 0
        for read = 1, total_particles do
            if not remove[read] then
                write = write + 1
                new_index[read] = write
            end
        end

        -- compact particle data
        for read = 1, total_particles do
            local write_i = new_index[read]
            if write_i and write_i ~= read then
                local src = (read  - 1) * stride + 1
                local dst = (write_i - 1) * stride + 1
                for o = 0, stride - 1 do
                    data[dst + o] = data[src + o]
                end
            end
        end

        -- truncate array (only table.remove usage)
        for i = write * stride + 1, #data do
            data[i] = nil
        end

        -- update only affected batches
        for _, batch in pairs(self._batch_id_to_batch) do
            local list = batch[list_name]
            if list ~= nil then
                local old_count = #list
                local write_pos = 1
                for read_pos = 1, old_count do
                    local old_base_index = list[read_pos]
                    local old_particle_id = math.floor((old_base_index - 1) / stride) + 1
                    local new_particle_id = new_index[old_particle_id]
                    if new_particle_id then
                        list[write_pos] = (new_particle_id - 1) * stride + 1
                        write_pos = write_pos + 1
                    end
                end

                for i = write_pos, old_count do list[i] = nil end
            end
        end
    end

    remove_particles(indices, self._data, "particle_indices")

    self:_update_data_mesh()
    self:_update_color_mesh()
end

--- @brief [internal] write new color for all particles
--- @private
function rt.FluidSimulation:_update_particle_color(batch)
    local particles = self._data
    local r, g, b, a = batch.config.color:unpack()
    for _, particle_i in ipairs(batch.particle_indices) do
        local i = _particle_i_to_data_offset(particle_i)
        particles[i + _r_offset] = r
        particles[i + _g_offset] = g
        particles[i + _b_offset] = b
        particles[i + _a_offset] = a
    end
end

--- @brief [internal] recompute batch centroid
--- @private
function rt.FluidSimulation:_update_batch_centroid(batch)
    local x, y = 0, 0
    for _, i in ipairs(batch.particle_indices) do
        x = x + self._data[i + _x_offset]
        y = y + self._data[i + _y_offset]
    end

    batch.centroid_x = x / batch.n_particles
    batch.centroid_y = y / batch.n_particles
end

do
    -- parameter to type and bounds for error handling
    local _valid_config_keys = {
        damping = {
            type = "Number",
            min = 0,
            max = 1
        },

        color = {
            type = "color",
        },

        outline_color = {
            type = "color",
        },

        outline_thickness = {
            type = "Number",
            min = 0
        },

        collision_strength = {
            type = "Number",
            min = 0,
            max = 1
        },

        collision_overlap_factor = {
            type = "Number",
            min = 0,
            max = nil
        },

        cohesion_strength = {
            type = "Number",
            min = 0,
            max = 1
        },

        cohesion_interaction_distance_factor = {
            type = "Number",
            min = 0,
            max = nil
        },

        follow_strength = {
            type = "Number",
            min = 0,
            max = 1
        },

        min_radius = {
            type = "Number",
            min = 0,
            max = nil
        },

        max_radius = {
            type = "Number",
            min = 0,
            max = nil
        },

        min_mass = {
            type = "Number",
            min = 0,
            max = nil
        },

        max_mass = {
            type = "Number",
            min = 0,
            max = nil
        },

        batch_radius = {
            type = "Number",
            min = 0,
            max = nil
        },

        motion_blur = {
            type = "Number",
            min = 0,
            max = 1
        },

        texture_scale = {
            type = "Number",
            min = 1,
            max = nil
        },

        highlight_strength = {
            type = "Number",
            min = 0,
            max = nil
        },

        shadow_strength = {
            type = "Number",
            min = 0,
            max = nil
        }
    }

    --- @brief [internal] override config setting
    --- @private
    function rt.FluidSimulation:_load_config(batch_id, config)
        local error = function(...)
            rt.error("In rt.FluidSimulation.set_config: ", ...)
        end

        local warning = function(...)
            rt.warning("In rt.FluidSimulation.set_config: ", ...)
        end

        local batch = self._batch_id_to_batch[batch_id]
        if batch == nil then
            rt.error("In rt.FluidSimulation._load_config: no batch with id `", batch_id, "`")
            return
        end

        for key, value in pairs(config) do
            local entry = _valid_config_keys[key]
            if entry == nil then
                warning("unrecognized config key `", key, "`, it will be ignored")
                goto ignore
            end

            if entry.type == "color" then
                -- assert value is rgba table
                if not meta.isa(value, rt.RGBA) then
                    error("expected `rt.RGBA`, got `", meta.typeof(value), "`")
                end
            else
                -- assert type and bounds
                if entry.type ~= nil and meta.typeof(value) ~= entry.type then
                    error("wrong type for config key `", key, "`, expected `", entry.type, "`, got `", meta.typeof(value), "`")
                    return
                elseif entry.type ~= nil and entry.type == "Number" and math.is_nan(value) then
                    warning("config key `", key, "` is NaN, it will be ignored")
                    goto ignore
                elseif entry.min ~= nil and value < entry.min then
                    warning("config key `", key, "`'s value is `", value, "`, expected a value larger than `", entry.min, "`")
                    value = math.max(value, entry.min)
                elseif entry.max ~= nil and value > entry.max then
                    warning("config key `", key, "`'s value is `", value, "`, expected a value smaller than `", entry.max, "`")
                    value = math.min(value, entry.max)
                end
            end

            batch.config[key] = value

            self._mass_changed = string.contains(key, "mass")
            self._particle_radius_changed = string.contains(key, "radius")
            self._batch_radius_changed = string.contains(key, "batch_radius")

            ::ignore::
        end
        self._mass_changed = true
        self._particle_radius_changed = true
        self._batch_radius_changed = true

    end
end

-- ### STEP HELPERS ### --
do
    -- table.clear, fallback implementations for non-luajit
    pcall(require, "table.clear")
    if not table.clear then
        function table.clear(t)
            for key in pairs(t) do
                t[key] = nil
            end
            return t
        end
    end

    --- convert config strength to XPBD compliance parameters
    local function _strength_to_compliance(strength, sub_step_delta)
        local alpha = 1 - math.clamp(strength, 0, 1)
        local alpha_per_substep = alpha / (sub_step_delta^2)
        return alpha_per_substep
    end

    --- setup environment
    local _create_environment = function(current_env)
        if current_env == nil then
            -- create new environment
            return {
                particles = {}, -- Table<Number>, particle properties stored inline

                spatial_hash = {}, -- Table<Number, Table<Number>> particle cell hash to list of particles

                damping = 1, -- overridden in _step

                min_x = math.huge, -- particle position bounds, px
                min_y = math.huge,
                max_x = -math.huge,
                max_y = -math.huge,

                n_particles = 0,

                center_of_mass_x = 0, -- set in post-solve, px
                center_of_mass_y = 0,
                centroid_x = 0,
                centroid_y = 0,

                should_update_follow = true,
                should_update_batch_radius = true,
                should_update_mass = true,
                should_update_particle_radius = true
            }
        else
            -- if old env present, keep allocated to keep gc / allocation pressure low
            local env = current_env

            -- reset tables
            table.clear(env.spatial_hash)

            -- reset variables
            env.min_x = math.huge
            env.min_y = math.huge
            env.max_x = -math.huge
            env.max_y = -math.huge
            env.centroid_x = 0
            env.centroid_y = 0

            return env
        end
    end

    --- pre solve: integrate velocity and update last position, reset XPBD lambdas
    local _pre_solve = function(
        particles, n_particles,
        damping, delta,
        should_update_follow,
        should_update_radius,
        should_update_mass,
        should_update_batch_radius,
        batch_id_to_batch
    )
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset

            local x, y = particles[x_i], particles[y_i]

            particles[i + _previous_x_offset] = x
            particles[i + _previous_y_offset] = y

            local velocity_x = particles[velocity_x_i] * damping
            local velocity_y = particles[velocity_y_i] * damping

            particles[velocity_x_i] = velocity_x
            particles[velocity_y_i] = velocity_y

            particles[x_i] = x + delta * velocity_x
            particles[y_i] = y + delta * velocity_y

            local batch_id = particles[i + _batch_id_offset]
            local batch = batch_id_to_batch[batch_id]

            if should_update_follow then
                particles[i + _follow_x_offset] = batch.follow_x
                particles[i + _follow_y_offset] = batch.follow_y
            end

            if should_update_mass then
                local mass = math.mix(
                    batch.config.min_mass, batch.config.max_mass,
                    particles[i + _mass_t_offset]
                )
                particles[i + _mass_offset] = mass
                particles[i + _inverse_mass_offset] = 1 / mass
            end

            if should_update_radius then
                particles[i + _radius_offset] = math.mix(
                    batch.config.min_radius, batch.config.max_radius,
                    particles[i + _radius_t_offset]
                )
            end

            if should_update_batch_radius then
                particles[i + _batch_radius_offset] = batch.config.batch_radius
            end

            -- Reset XPBD lambdas at the beginning of each sub-step
            particles[i + _follow_lambda_offset] = 0.0
            particles[i + _collision_lambda_offset] = 0.0
            particles[i + _cohesion_lambda_offset] = 0.0
        end
    end

    -- XPBD distance constraint between two points (A,B)
    -- C = |b - a| - d0 = 0
    -- Returns corrections and both delta_lambda and lambda_new.
    local function _enforce_distance_xpbd(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,         -- compliance (already scaled by sub_delta^2)
        lambda_before  -- accumulated lambda for this constraint
    )
        local delta_x = bx - ax
        local delta_y = by - ay
        local length = math.magnitude(delta_x, delta_y)
        if length < math.eps then
            return 0, 0, 0, 0, 0.0, lambda_before
        end

        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        local constraint = length - target_distance
        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, 0.0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- x_i += w_i * d_lambda * gradC_i
        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x) -- grad_a = -n
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_bx = inverse_mass_b * delta_lambda * ( normal_x) -- grad_b = +n
        local correction_by = inverse_mass_b * delta_lambda * ( normal_y)

        return correction_ax, correction_ay, correction_bx, correction_by, delta_lambda, lambda_new
    end

    --- make particles move towards target (XPBD distance with kinematic target)
    local _solve_follow_constraint = function(
        particles, n_particles,
        compliance
    )
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)

            local ax = particles[i + _x_offset]
            local ay = particles[i + _y_offset]
            local bx = particles[i + _follow_x_offset]
            local by = particles[i + _follow_y_offset]
            local target_distance = particles[i + _batch_radius_offset]

            local inverse_mass_a = particles[i + _inverse_mass_offset]
            local inverse_mass_b = 0.0 -- kinematic target

            if inverse_mass_a < math.eps then goto next_particle end

            local lambda_before = particles[i + _follow_lambda_offset]
            local correction_ax, correction_ay, _, _, delta_lambda, lambda_new = _enforce_distance_xpbd(
                ax, ay, bx, by,
                inverse_mass_a, inverse_mass_b,
                target_distance,
                compliance,
                lambda_before
            )

            particles[i + _x_offset] = ax + correction_ax
            particles[i + _y_offset] = ay + correction_ay

            -- accumulate lambda for this constraint on the particle
            particles[i + _follow_lambda_offset] = lambda_before + delta_lambda

            ::next_particle::
        end
    end

    --- szudzik's pairing function, converts x, y integer index to hash
    local _xy_to_hash = function(x, y)
        local a = x >= 0 and (x * 2) or (-x * 2 - 1)
        local b = y >= 0 and (y * 2) or (-y * 2 - 1)

        if a >= b then
            return a * a + a + b
        else
            return b * b + a
        end
    end

    --- repopulate spatial hash for later positional queries
    local _rebuild_spatial_hash = function(particles, n_particles, spatial_hash, spatial_hash_cell_radius)
        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x = i + _x_offset
            local y = i + _y_offset
            local hash_cell_x = i + _cell_x_offset
            local hash_cell_y = i + _cell_y_offset

            local cell_x = math.floor(particles[x] / spatial_hash_cell_radius)
            local cell_y = math.floor(particles[y] / spatial_hash_cell_radius)

            -- store in particle data for later access
            particles[hash_cell_x] = cell_x
            particles[hash_cell_y] = cell_y

            -- convert to hash, then store in that cell
            local hash = _xy_to_hash(cell_x, cell_y)
            local entry = spatial_hash[hash]
            if entry == nil then
                entry = {}
                spatial_hash[hash] = entry
            end

            table.insert(entry, particle_i)
        end
    end

    --- enforce collision and cohesion (XPBD distance with per-particle lambda accumulation)
    local function _solve_collision(
        particles, n_particles,
        spatial_hash,
        collision_overlap_factor, collision_compliance,
        cohesion_interaction_distance_factor, cohesion_compliance,
        max_n_collisions
    )
        local n_collided = 0
        for self_particle_i = 1, n_particles do
            local self_i = _particle_i_to_data_offset(self_particle_i)
            local self_x_i = self_i + _x_offset
            local self_y_i = self_i + _y_offset

            local self_inverse_mass = particles[self_i + _inverse_mass_offset]
            local self_radius = particles[self_i + _radius_offset]
            local self_batch_id = particles[self_i + _batch_id_offset]

            local cell_x = particles[self_i + _cell_x_offset]
            local cell_y = particles[self_i + _cell_y_offset]

            for x_offset = -1, 1 do
                for y_offset = -1, 1 do
                    local spatial_hash_hash = _xy_to_hash(
                        cell_x + x_offset,
                        cell_y + y_offset
                    )

                    local entry = spatial_hash[spatial_hash_hash]
                    if entry == nil then goto next_index end

                    for _, other_particle_i in ipairs(entry) do

                        -- avoid collision with self and duplicates (process only ordered pairs)
                        if self_particle_i >= other_particle_i then goto next_pair end

                        local other_i = _particle_i_to_data_offset(other_particle_i)
                        local other_x_i = other_i + _x_offset
                        local other_y_i = other_i + _y_offset

                        local other_inverse_mass = particles[other_i + _inverse_mass_offset]
                        local other_radius = particles[other_i + _radius_offset]
                        local other_batch_id = particles[other_i + _batch_id_offset]

                        -- degenerate particle data
                        if self_inverse_mass + other_inverse_mass < math.eps then goto next_pair end

                        do -- cohesion: move particles in the same batch towards target interaction distance
                            local self_x, self_y, other_x, other_y =
                            particles[self_x_i],  particles[self_y_i],
                            particles[other_x_i],  particles[other_y_i]

                            local interaction_distance
                            if self_batch_id == other_batch_id then
                                interaction_distance = 0
                            else
                                interaction_distance = cohesion_interaction_distance_factor * (self_radius + other_radius)
                            end

                            if self_batch_id == other_batch_id and
                                math.squared_distance(self_x, self_y, other_x, other_y) <= interaction_distance^2
                            then
                                local lambda_a = particles[self_i + _cohesion_lambda_offset]
                                local lambda_b = particles[other_i + _cohesion_lambda_offset]
                                local lambda_pair_before = 0.5 * (lambda_a + lambda_b)

                                local correction_ax, correction_ay,
                                      correction_bx, correction_by,
                                      delta_lambda, _ = _enforce_distance_xpbd(
                                    self_x, self_y, other_x, other_y,
                                    self_inverse_mass, other_inverse_mass,
                                    interaction_distance, cohesion_compliance, lambda_pair_before
                                )

                                particles[self_x_i] = self_x + correction_ax
                                particles[self_y_i] = self_y + correction_ay
                                particles[other_x_i] = other_x + correction_bx
                                particles[other_y_i] = other_y + correction_by

                                -- accumulate per-particle lambdas
                                particles[self_i + _cohesion_lambda_offset] = lambda_a + delta_lambda
                                particles[other_i + _cohesion_lambda_offset] = lambda_b + delta_lambda
                            end
                        end

                        do -- collision: enforce distance between particles to be larger than minimum
                            local min_distance = collision_overlap_factor * (self_radius + other_radius)

                            local self_x, self_y, other_x, other_y =
                            particles[self_x_i],  particles[self_y_i],
                            particles[other_x_i],  particles[other_y_i]

                            local distance2 = math.squared_distance(self_x, self_y, other_x, other_y)

                            if distance2 <= min_distance^2 then
                                local lambda_a = particles[self_i + _collision_lambda_offset]
                                local lambda_b = particles[other_i + _collision_lambda_offset]
                                local lambda_pair_before = 0.5 * (lambda_a + lambda_b)

                                local correction_ax, correction_ay,
                                      correction_bx, correction_by,
                                      delta_lambda, _ = _enforce_distance_xpbd(
                                    self_x, self_y, other_x, other_y,
                                    self_inverse_mass, other_inverse_mass,
                                    min_distance, collision_compliance, lambda_pair_before
                                )

                                particles[self_x_i] = self_x + correction_ax
                                particles[self_y_i] = self_y + correction_ay
                                particles[other_x_i] = other_x + correction_bx
                                particles[other_y_i] = other_y + correction_by

                                -- accumulate per-particle lambdas
                                particles[self_i + _collision_lambda_offset] = lambda_a + delta_lambda
                                particles[other_i + _collision_lambda_offset] = lambda_b + delta_lambda
                            end
                        end

                        -- emergency safety check, if too many particles cluster together this avoids slowdown
                        n_collided = n_collided + 1
                        if n_collided >= max_n_collisions then return end

                        ::next_pair::
                    end
                    ::next_index::
                end
            end
        end
    end

    --- update true velocity, get aabb and centroid
    local function _post_solve(particles, n_particles, delta)
        local min_x, min_y = math.huge, math.huge
        local max_x, max_y = -math.huge, -math.huge
        local centroid_x, centroid_y = 0, 0

        local max_velocity = 0
        local max_radius = 0

        for particle_i = 1, n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local previous_x_i = i + _previous_x_offset
            local previous_y_i = i + _previous_y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset
            local radius_i = i + _radius_offset

            local x = particles[x_i]
            local y = particles[y_i]

            local velocity_x = (x - particles[previous_x_i]) / delta
            local velocity_y = (y - particles[previous_y_i]) / delta
            particles[velocity_x_i] = velocity_x
            particles[velocity_y_i] = velocity_y

            local velocity_magnitude = math.magnitude(velocity_x, velocity_y)
            if velocity_magnitude > max_velocity then
                max_velocity = velocity_magnitude
            end

            centroid_x = centroid_x + x
            centroid_y = centroid_y + y

            -- log AABB including particle radius
            local r = particles[radius_i]
            if r > max_radius then max_radius = r end
            min_x = math.min(min_x, x - r)
            min_y = math.min(min_y, y - r)
            max_x = math.max(max_x, x + r)
            max_y = math.max(max_y, y + r)
        end

        if n_particles > 0 then
            centroid_x = centroid_x / n_particles
            centroid_y = centroid_y / n_particles
        end

        return min_x, min_y, max_x, max_y, centroid_x, centroid_y, max_radius, max_velocity
    end

    --- @brief [internal] step the simulation
    --- @private
    function rt.FluidSimulation:_step(delta, n_sub_steps, n_collision_steps)
        local sub_delta = math.max(delta / n_sub_steps, math.eps)

        local function update_environment(old_env, config, particles, n_particles)
            local env = _create_environment(old_env)
            env.particles = particles
            env.n_particles = n_particles

            if old_env ~= nil then
                env.should_update_mass = self._mass_changed
                env.should_update_particle_radius = self._particle_radius_changed
                env.should_update_batch_radius = self._batch_radius_changed
                env.should_update_follow = self._follow_changed

                self._mass_changed = false
                self._particle_radius_changed = false
                self._batch_radius_changed = false
                self._follow_changed = false
            else
                env.should_update_follow = true
                env.should_update_mass = true
                env.should_update_particle_radius = true
                env.should_update_batch_radius = true
            end

            env.min_mass = config.min_mass
            env.max_mass = config.max_mass
            env.min_radius = config.min_radius
            env.max_radius = config.max_radius

            env.texture_scale = config.texture_scale
            env.motion_blur = config.motion_blur

            -- collision budget, limit maximum number of collisions processed per step
            -- this is to guard against all particles being so close together that the
            -- number of collision explodes
            local fraction = self._max_collision_fraction
            env.max_n_collisions = fraction * env.n_particles^2

            -- compute spatial hash cell radius to cover both collision and cohesion radii
            local max_factor = math.max(
                config.collision_overlap_factor,
                config.cohesion_interaction_distance_factor
            )
            env.spatial_hash_cell_radius = math.max(1, config.max_radius * max_factor)

            env.damping = 1 - math.clamp(config.damping, 0, 1)

            env.follow_compliance = _strength_to_compliance(config.follow_strength, sub_delta)
            env.collision_compliance = _strength_to_compliance(config.collision_strength, sub_delta)
            env.cohesion_compliance = _strength_to_compliance(config.cohesion_strength, sub_delta)
            return env
        end

        local env = update_environment(
            self._last_env, self._default_config,
            self._data, self._total_n_particles
        )

        -- update pre-step positions for frame interpolation
        local update_last_positions = function(env)
            local particles = env.particles
            local sum_x, sum_y = 0, 0
            for particle_i = 1, env.n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local x = particles[i + _x_offset]
                local y = particles[i + _y_offset]
                particles[i + _last_update_x_offset] = x
                particles[i + _last_update_y_offset] = y
                sum_x = sum_x + x
                sum_y = sum_y + y
            end

            if env.n_particles > 0 then
                env.last_centroid_x = sum_x / env.n_particles
                env.last_centroid_y = sum_y / env.n_particles
            else
                env.last_centroid_x = 0
                env.last_centroid_y = 0
            end
        end

        update_last_positions(env)

        -- step the simulation
        for sub_step_i = 1, n_sub_steps do
            _pre_solve(
                env.particles,
                env.n_particles,
                env.damping,
                sub_delta,
                env.should_update_follow,
                env.should_update_particle_radius,
                env.should_update_mass,
                env.should_update_batch_radius,
                self._batch_id_to_batch
            )

            _solve_follow_constraint(
                env.particles,
                env.n_particles,
                env.follow_compliance
            )

            for collision_i = 1, n_collision_steps do
                _rebuild_spatial_hash(
                    env.particles,
                    env.n_particles,
                    env.spatial_hash,
                    env.spatial_hash_cell_radius
                )

                _solve_collision(
                    env.particles,
                    env.n_particles,
                    env.spatial_hash,
                    self._default_config.collision_overlap_factor,
                    env.collision_compliance,
                    self._default_config.cohesion_interaction_distance_factor,
                    env.cohesion_compliance,
                    env.max_n_collisions
                )

                if collision_i < n_collision_steps then
                    -- clear after each pass to avoid double counting
                    table.clear(env.spatial_hash)
                end
            end

            env.min_x, env.min_y,
            env.max_x, env.max_y,
            env.centroid_x, env.centroid_y,
            env.max_radius, env.max_velocity = _post_solve(
                env.particles,
                env.n_particles,
                sub_delta
            )
        end -- sub-steps

        -- after solver, resize render textures if necessary
        local function resize_canvas_maybe(canvas, env)
            if env.n_particles == 0 then
                return canvas
            end

            local current_w, current_h = 0, 0
            if canvas ~= nil then
                current_w, current_h = canvas:get_size()
            end

            -- compute canvas padding
            local padding = env.max_radius * env.texture_scale
                * (1 +  math.max(1, env.max_velocity) * env.motion_blur)

            local new_w = math.ceil((env.max_x - env.min_x) + 2 * padding)
            local new_h = math.ceil((env.max_y - env.min_y) + 2 * padding)

            -- safety check, so canvases isn't unbounded on instable behavior
            new_w = math.min(new_w, 2560)
            new_h = math.min(new_h, 2560)

            -- reallocate if canvases needs to grow
            if new_w > current_w or new_h > current_h then
                local new_canvas = rt.RenderTexture(
                    math.max(new_w, current_w),
                    math.max(new_h, current_h),
                    self._canvas_msaa,
                    self._render_texture_format
                )
                new_canvas:set_scale_mode(rt.TextureScaleMode.LINEAR)

                if canvas ~= nil then
                    canvas:free() -- free old as early as possible, uses a lot of vram
                end
                return new_canvas
            else
                return canvas
            end
        end

        self._canvas = resize_canvas_maybe(self._canvas, env)

        -- keep env of last step
        self._last_env = env

        self._canvases_need_update = true

        for _, batch in pairs(self._batch_id_to_batch) do
            batch.centroid_needs_update = true
        end
    end
end -- step helpers

do
    --- @brief [internal] update canvases with particle data
    --- @private
    function rt.FluidSimulation:_update_canvases()
        if self._canvases_need_update == false
            or self._canvas == nil
        then return end

        local t = self._interpolation_alpha
        local draw_particles = function(env, instance_mesh)
            -- frame interpolation for the centroid
            local predicted_centroid_x = math.mix(env.last_centroid_x or env.centroid_x, env.centroid_x, t)
            local predicted_centroid_y = math.mix(env.last_centroid_y or env.centroid_y, env.centroid_y, t)

            love.graphics.push()
            love.graphics.translate(-predicted_centroid_x, -predicted_centroid_y)
            love.graphics.setColor(1, 1, 1, 1)
            instance_mesh:draw_instanced(env.n_particles)
            love.graphics.pop()
        end

        love.graphics.push("all")
        love.graphics.reset()

        -- alpha is accumulated by additive blending, then normalized to 0, 1 automatically
        love.graphics.setBlendMode("screen", "premultiplied")

        self._instanced_draw_shader:bind()
        self._instanced_draw_shader:send("interpolation_alpha", t)

        local canvas = self._canvas
        local canvas_width, canvas_height = canvas:get_size()
        local env = self._last_env
        self._instanced_draw_shader:send("motion_blur", env.motion_blur)
        self._instanced_draw_shader:send("texture_scale", env.texture_scale)
        canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        love.graphics.translate(canvas_width / 2, canvas_height / 2)
        draw_particles(self._last_env, self._instance_mesh)
        love.graphics.pop()

        canvas:unbind()

        self._instanced_draw_shader:unbind()

        love.graphics.pop() -- all
        self._canvases_need_update = false
    end

    --- @brief [internal] composite canvases to final image
    --- @private
    function rt.FluidSimulation:_draw_canvases()
        if self._canvas == nil then return end

        love.graphics.push("all")
        love.graphics.setBlendMode("alpha", "alphamultiply")

        -- reuse threshold parameters
        self._outline_shader:send("threshold", self._thresholding_threshold)

        self._lighting_shader:send("threshold", self._thresholding_threshold)
        self._lighting_shader:send("smoothness", self._thresholding_smoothness)
        self._lighting_shader:send("use_particle_color", true)

        local draw_canvas = function(canvas, env, config)
            local canvas_width, canvas_height = canvas:get_size()
            local canvas_x = env.centroid_x - 0.5 * canvas_width
            local canvas_y = env.centroid_y - 0.5 * canvas_height

            local color = config.color
            local outline_color = config.outline_color
            local outline_thickness = config.outline_thickness

            if outline_thickness > 0 then
                self._outline_shader:bind()
                self._outline_shader:send("outline_thickness", outline_thickness)
                love.graphics.setColor(outline_color:unpack())
                canvas:draw(canvas_x, canvas_y)
                self._outline_shader:unbind()
            end

            love.graphics.setColor(color:unpack())
            self._lighting_shader:bind()

            self._lighting_shader:send("highlight_strength", config.highlight_strength)
            self._lighting_shader:send("use_highlight",
                config.highlight_strength > 0 and self._use_lighting
            )

            self._lighting_shader:send("shadow_strength", config.shadow_strength)
            self._lighting_shader:send("use_shadow",
                config.shadow_strength > 0 and self._use_lighting
            )

            canvas:draw(canvas_x, canvas_y)

            self._lighting_shader:unbind()
        end

        draw_canvas(self._canvas,
            self._last_env,
            self._default_config
        )

        love.graphics.pop()
    end
end

--- @brief [internal]
function rt.FluidSimulation:_distribute_particles(polygon_tris, circle_i_to_radius)
    local N = #circle_i_to_radius
    if N == 0 then return {} end
    if polygon_tris == nil or #polygon_tris == 0 then return {} end

    -- Local aliases for performance and fallback RNG
    local sqrt, abs, max, min, floor = math.sqrt, math.abs, math.max, math.min, math.floor
    local random = (love and love.math and love.math.random) or math.random
    local distance, cross, mix = math.distance, math.cross, math.mix
    local EPS = math.eps or 1e-9
    local SQRT3 = sqrt(3.0)

    -- Precompute triangle stats and global bbox
    local tri_count = #polygon_tris
    local tri_areas = {}
    local total_area = 0.0
    local minx, miny = 1/0, 1/0
    local maxx, maxy = -1/0, -1/0

    -- For faster barycentric sampling: store triangle bases: a, ab, ac per tri
    -- Layout: [ax,ay, abx,aby, acx,acy] per triangle
    local tri_basis = {}
    tri_basis[6 * tri_count] = nil

    for i = 1, tri_count do
        local t = polygon_tris[i]
        local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
        local abx, aby = bx - ax, by - ay
        local acx, acy = cx - ax, cy - ay
        local area = 0.5 * abs(cross(abx, aby, acx, acy))
        tri_areas[i] = area
        total_area = total_area + area

        local base = (i - 1) * 6
        tri_basis[base + 1] = ax
        tri_basis[base + 2] = ay
        tri_basis[base + 3] = abx
        tri_basis[base + 4] = aby
        tri_basis[base + 5] = acx
        tri_basis[base + 6] = acy

        -- bbox accumulation
        local tminx = min(ax, min(bx, cx))
        local tmaxx = max(ax, max(bx, cx))
        local tminy = min(ay, min(by, cy))
        local tmaxy = max(ay, max(by, cy))
        if tminx < minx then minx = tminx end
        if tmaxx > maxx then maxx = tmaxx end
        if tminy < miny then miny = tminy end
        if tmaxy > maxy then maxy = tmaxy end
    end
    if total_area <= EPS then
        return {}
    end

    -- Build Walker alias table for O(1) triangle sampling
    -- prob[i] in [0,1], alias[i] in [1..tri_count]
    local prob = {}
    local alias = {}
    prob[tri_count] = nil
    alias[tri_count] = nil

    do
        -- Normalize areas
        local scaled = {}
        scaled[tri_count] = nil
        local inv_total = 1.0 / total_area
        for i = 1, tri_count do
            scaled[i] = tri_areas[i] * inv_total * tri_count
        end
        -- Worklists
        local small, large = {}, {}
        for i = 1, tri_count do
            if scaled[i] < 1.0 then
                small[#small+1] = i
            else
                large[#large+1] = i
            end
        end
        while #small > 0 and #large > 0 do
            local l = small[#small]; small[#small] = nil
            local g = large[#large]; large[#large] = nil
            prob[l] = scaled[l]
            alias[l] = g
            scaled[g] = (scaled[g] + scaled[l]) - 1.0
            if scaled[g] < 1.0 then
                small[#small+1] = g
            else
                large[#large+1] = g
            end
        end
        while #large > 0 do
            local g = large[#large]; large[#large] = nil
            prob[g] = 1.0
            alias[g] = g
        end
        while #small > 0 do
            local l = small[#small]; small[#small] = nil
            prob[l] = 1.0
            alias[l] = l
        end
    end

    -- O(1) sample of a triangle index
    local function sample_triangle_index()
        -- random() in [0,1), scale by tri_count
        local r = random() * tri_count
        local k = floor(r) + 1
        local frac = r - floor(r)
        if frac < prob[k] then
            return k
        else
            return alias[k]
        end
    end

    -- Uniform sample inside polygon by:
    -- 1) Choose triangle with alias sampler
    -- 2) Barycentric sample inside chosen triangle using bases
    local function sample_point_in_polygon()
        local tri_index = sample_triangle_index()
        -- Barycentric fold
        local u = random()
        local v = random()
        if (u + v) > 1.0 then
            u = 1.0 - u
            v = 1.0 - v
        end
        local base = (tri_index - 1) * 6
        local ax = tri_basis[base + 1]
        local ay = tri_basis[base + 2]
        local abx = tri_basis[base + 3]
        local aby = tri_basis[base + 4]
        local acx = tri_basis[base + 5]
        local acy = tri_basis[base + 6]
        local px = ax + u * abx + v * acx
        local py = ay + u * aby + v * acy
        return px, py
    end

    -- Initial centers: triangular lattice inside polygon.
    -- Lattice spacing 'a' estimated from polygon area and number of circles.
    local a = sqrt((2.0 * total_area) / (SQRT3 * N))
    a = a * 0.95
    local h = a * (SQRT3 * 0.5)

    -- Point-in-triangle for lattice filtering (triangles tessellate the polygon)
    local function point_in_triangle(px, py, ax, ay, bx, by, cx, cy)
        local c1 = math.cross(bx - ax, by - ay, px - ax, py - ay)
        local c2 = math.cross(cx - bx, cy - by, px - bx, py - by)
        local c3 = math.cross(ax - cx, ay - cy, px - cx, py - cy)
        local has_neg = (c1 < -EPS) or (c2 < -EPS) or (c3 < -EPS)
        local has_pos = (c1 > EPS) or (c2 > EPS) or (c3 > EPS)
        return not (has_neg and has_pos)
    end

    -- For lattice inclusion, accelerate "point in polygon (triangulation)" by
    -- checking each triangle's bbox and doing the triangle test.
    -- This is kept simple since this step runs once, while Lloyd runs multiple times.
    local tri_bbox = {}
    tri_bbox[4 * tri_count] = nil
    do
        for i = 1, tri_count do
            local t = polygon_tris[i]
            local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
            local tminx = math.min(ax, math.min(bx, cx))
            local tmaxx = math.max(ax, math.max(bx, cx))
            local tminy = math.min(ay, math.min(by, cy))
            local tmaxy = math.max(ay, math.max(by, cy))
            local base = (i - 1) * 4
            tri_bbox[base + 1] = tminx
            tri_bbox[base + 2] = tmaxx
            tri_bbox[base + 3] = tminy
            tri_bbox[base + 4] = tmaxy
        end
    end

    local function point_in_polygon(px, py)
        for i = 1, tri_count do
            local bb = (i - 1) * 4
            local tminx = tri_bbox[bb + 1]
            local tmaxx = tri_bbox[bb + 2]
            local tminy = tri_bbox[bb + 3]
            local tmaxy = tri_bbox[bb + 4]
            if px >= tminx and px <= tmaxx and py >= tminy and py <= tmaxy then
                local t = polygon_tris[i]
                if point_in_triangle(px, py, t[1], t[2], t[3], t[4], t[5], t[6]) then
                    return true
                end
            end
        end
        return false
    end

    -- Build lattice points within expanded bbox, filter by polygon inclusion
    local candidates = {}
    local row = 0
    local y = miny - h
    local y_end = maxy + h
    while y <= y_end do
        local x_offset = ((row % 2) ~= 0) and (a * 0.5) or 0.0
        local x = (minx - a) + x_offset
        local x_end = maxx + a
        while x <= x_end do
            if point_in_polygon(x, y) then
                candidates[#candidates+1] = x
                candidates[#candidates+1] = y
            end
            x = x + a
        end
        row = row + 1
        y = y + h
    end

    -- Top up if not enough lattice points (use uniform sampling inside polygon)
    local need = N - floor(#candidates / 2)
    if need > 0 then
        for _ = 1, need do
            local sx, sy = sample_point_in_polygon()
            candidates[#candidates+1] = sx
            candidates[#candidates+1] = sy
        end
    end

    -- Shuffle candidates (Fisher-Yates on pairs)
    local cand_pairs = floor(#candidates / 2)
    for i = cand_pairs, 2, -1 do
        local j = 1 + floor(random() * i)
        local ia = (i - 1) * 2 + 1
        local ja = (j - 1) * 2 + 1
        candidates[ia], candidates[ja] = candidates[ja], candidates[ia]
        candidates[ia+1], candidates[ja+1] = candidates[ja+1], candidates[ia+1]
    end

    local centers = {}
    centers[2 * N] = nil
    for i = 1, N do
        local ci = (i - 1) * 2 + 1
        local si = (i - 1) * 2 + 1
        centers[ci] = candidates[si]
        centers[ci+1] = candidates[si+1]
    end

    -- Lloyd parameters (iterations kept modest; acceleration is structural)
    local n_lloyd_iterations = rt.settings.fluid_simulation.n_lloyd_iterations
    local alpha = 0.5
    local radii = circle_i_to_radius
    local tiny = EPS

    -- Preallocate working buffers for reuse
    local sums = {}
    local counts = {}
    sums[2 * N] = nil
    counts[N] = nil

    -- Spatial grid to accelerate nearest-center queries
    -- Use lattice spacing 'a' as grid cell size
    local cell = a
    if cell < EPS then cell = 1.0 end
    local inv_cell = 1.0 / cell
    local grid_w = max(1, floor((maxx - minx) * inv_cell) + 1)
    local grid_h = max(1, floor((maxy - miny) * inv_cell) + 1)
    local grid_size = grid_w * grid_h
    local grid = {}          -- grid[cell_idx] = array of center indices
    local center_cell_ix = {} -- per-center cached cell index (for rebuilding)

    local function cell_index(ix, iy)
        return iy * grid_w + ix + 1
    end

    local function clampi(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function rebuild_grid()
        for i = 1, grid_size do grid[i] = nil end
        -- Populate grid
        for i = 1, N do
            local ci = (i - 1) * 2 + 1
            local x = centers[ci]
            local y = centers[ci+1]
            local ix = clampi(floor((x - minx) * inv_cell), 0, grid_w - 1)
            local iy = clampi(floor((y - miny) * inv_cell), 0, grid_h - 1)
            local gi = cell_index(ix, iy)
            local bucket = grid[gi]
            if bucket == nil then
                bucket = {}
                grid[gi] = bucket
            end
            bucket[#bucket+1] = i
            center_cell_ix[i] = gi
        end
    end

    local function nearest_center_scaled(sx, sy)
        -- Query around sample's cell, expanding rings until at least one candidate is found.
        local ix = clampi(floor((sx - minx) * inv_cell), 0, grid_w - 1)
        local iy = clampi(floor((sy - miny) * inv_cell), 0, grid_h - 1)

        local best_i = nil
        local best_d = 1/0

        local r = 0
        local maxR = max(grid_w, grid_h)
        while r <= maxR do
            local found_any = false
            local xmin = clampi(ix - r, 0, grid_w - 1)
            local xmax = clampi(ix + r, 0, grid_w - 1)
            local ymin = clampi(iy - r, 0, grid_w - 1)
            local ymax = clampi(iy + r, 0, grid_w - 1)

            for yy = ymin, ymax do
                for xx = xmin, xmax do
                    local gi = cell_index(xx, yy)
                    local bucket = grid[gi]
                    if bucket ~= nil then
                        found_any = true
                        for k = 1, #bucket do
                            local idx = bucket[k]
                            local ci = (idx - 1) * 2 + 1
                            local cx = centers[ci]
                            local cy = centers[ci+1]
                            local denom = max(radii[idx], tiny)
                            local d = distance(sx, sy, cx, cy) / denom
                            if d < best_d then
                                best_d = d
                                best_i = idx
                            end
                        end
                    end
                end
            end

            if found_any and best_i ~= nil then
                break
            end
            r = r + 1
        end

        -- Fallback (should be rare): if no buckets found (empty grid), do a linear scan
        if best_i == nil then
            best_i = 1
            local ci = 1
            local denom = max(radii[1], tiny)
            best_d = distance(sx, sy, centers[ci], centers[ci+1]) / denom
            for i = 2, N do
                ci = (i - 1) * 2 + 1
                local d = distance(sx, sy, centers[ci], centers[ci+1]) / max(radii[i], tiny)
                if d < best_d then
                    best_d = d
                    best_i = i
                end
            end
        end

        return best_i
    end

    local function lloyd_iteration()
        -- Zero buffers
        for i = 1, 2 * N do sums[i] = 0.0 end
        for i = 1, N do counts[i] = 0 end

        rebuild_grid()

        -- Monte Carlo samples proportional to N
        local M = min(max(12 * N, 400), 12000)

        for _ = 1, M do
            local sx, sy = sample_point_in_polygon()
            local best_i = nearest_center_scaled(sx, sy)

            local bi = (best_i - 1) * 2 + 1
            sums[bi] = sums[bi] + sx
            sums[bi + 1] = sums[bi + 1] + sy
            counts[best_i] = counts[best_i] + 1
        end

        -- Update centers to centroids (with mixing)
        for i = 1, N do
            local c = counts[i]
            local ci = (i - 1) * 2 + 1
            if c > 0 then
                local meanx = sums[ci] / c
                local meany = sums[ci + 1] / c
                local ox = centers[ci]
                local oy = centers[ci + 1]
                centers[ci] = mix(ox, meanx, alpha)
                centers[ci + 1] = mix(oy, meany, alpha)
            else
                -- Rare: re-seed to a random valid point
                local rx, ry = sample_point_in_polygon()
                centers[ci] = rx
                centers[ci + 1] = ry
            end
        end
    end

    for _ = 1, n_lloyd_iterations do
        lloyd_iteration()
    end

    return centers
end
]]