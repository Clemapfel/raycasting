require "common.quaternion"
require "common.widget"
require "common.render_texture_3d"

rt.settings.overworld.background = {
    n_particles = 1000,
    min_scale = 1,
    max_scale = 1,
    cell_occupancy_chance = 0.2,

    min_scale_bloom = 0.1,
    max_scale_bloom = 0.2,
    bloom_particle_chance = 0.7,

    fov = 0.3,
    min_depth = 21,
    max_depth = 21 + 200,
    cell_size = 2^3,

    min_rotation_speed = 0.02, -- radians per second
    max_rotation_speed = 0.05,

    z_zoom = 0, -- camera position towards z axis
    stage_z_position = 1, -- world z coord of stage plane,
    cube_thickness = 0.2, -- fraction

    -- shape distribution
    tetrahedron_p = 5,
    octahedron_p = 3,
    cube_p = 7,
    icosahedron_p = 1,
    dodecahedron_p = 1,

    room_color = rt.Palette.GRAY_9
}

--- @class ow.Background
ow.Background = meta.class("OverworldBackground", rt.Widget)

local _particle_shader_no_bloom = rt.Shader("overworld/background_particles.glsl", { IS_BLOOM = 0 })
local _particle_shader_bloom = rt.Shader("overworld/background_particles.glsl", { IS_BLOOM = 1 })
local _room_shader = rt.Shader("overworld/background_room.glsl")
local _front_wall_shader = rt.Shader("overworld/background_front_room.glsl")

local _instance_mesh_format = {
    { location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec3" },
    { location = 1, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4" }
}

local _data_mesh_format = {
    { location = 3, name = "offset", format = "floatvec3" },
    { location = 4, name = "scale", format = "float" },
    { location = 5, name = "rotation", format = "floatvec4"}, -- quaternion
    { location = 6, name = "color", format = "floatvec4" }
}

--- @brief
function ow.Background:instantiate()
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            for shader in range(
                _particle_shader_no_bloom,
                _particle_shader_bloom,
                _room_shader,
                _front_wall_shader
            ) do
                shader:recompile()
            end
        end
    end)
end

--- @brief
function ow.Background:realize()
    if self:already_realized() then return end

    self._particles = {}

    self._room_mesh = nil -- rt.Mesh
    self._front_wall_mesh = nil -- rt.Mesh

    self._canvas = nil -- rt.RenderTexture3D
    self._canvas_needs_update = true

    self._view_transform = rt.Transform()
    self._view_transform:look_at(
        0,  0,  0, -- eye xyz
        0,  0,  1, -- target xyz
        0, -1,  0  -- up xyz
    )

    self._offset_transform = rt.Transform() -- xyz offset
    self._scale_transform = rt.Transform() -- xyz offset

    self._camera_scale = 1
    self._camera_offset = { 0, 0 }
end

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)

    self._canvas = rt.RenderTexture3D(width, height, 8)
    self._canvas:set_fov(rt.settings.overworld.background.fov)

    self._particles = {}
    rt.random.seed(1234)

    local id_tetrahedron, id_octahedron, id_cube, id_icosahedron, id_dodecahedron = 1, 2, 3, 4, 5
    local instances = {
        [id_tetrahedron] = self:_init_tetrahedron_particle(),
        [id_octahedron] = self:_init_octahedron_particle(),
        [id_cube] = self:_init_cube_particle(),
        [id_icosahedron] =  self:_init_icosahedron_particle(),
        [id_dodecahedron] = self:_init_dodecahedron_particle()
    }

    local settings = rt.settings.overworld.background
    local probabilities = {
        [id_tetrahedron] = settings.tetrahedron_p,
        [id_octahedron] = settings.octahedron_p,
        [id_cube] = settings.cube_p,
        [id_icosahedron] =  settings.icosahedron_p,
        [id_dodecahedron] = settings.dodecahedron_p
    }

    -- init entry and instances
    local new_entry = function(instance_mesh, is_bloom)
        return {
            instance_mesh = instance_mesh,
            is_bloom = is_bloom,
            data_mesh = nil,
            data_mesh_data = {},
            data_mesh_data_aux = {},
            n_particles = nil
        }
    end

    local to_sample = {}
    for id, instance_mesh in pairs(instances) do
        local entry = new_entry(instance_mesh, false) -- no bloom
        table.insert(self._particles, entry)
        for _ = 1, probabilities[id] do
            table.insert(to_sample, entry)
        end
    end

    local sphere_entry = new_entry(self:_init_sphere_particle(16, 16), true) -- bloom
    table.insert(self._particles, sphere_entry)

    do
        local aspect = self._bounds.width / self._bounds.height

        local settings = rt.settings.overworld.background
        local min_scale = settings.min_scale
        local max_scale = settings.max_scale

        local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()

        min_x = min_x - max_scale
        max_x = max_x + max_scale
        min_y = min_y - max_scale
        max_y = max_y + max_scale

        min_z = min_z + max_scale
        max_z = max_z - max_scale

        self._room_bounds = {
            min_x, max_x,
            min_y, max_y,
            min_z, max_z
        }

        local cell_size = rt.settings.overworld.background.cell_size
        local shape_probability = rt.settings.overworld.background.cell_occupancy_chance
        local bloom_probability = rt.settings.overworld.background.bloom_particle_chance

        local generate_particle = function(entry, ix, iy, iz, min_scale, max_scale)
            local scale = math.mix(min_scale, max_scale, rt.random.number(0, 1))

            local cell_min_x = min_x + ix * cell_size
            local cell_max_x = math.min(cell_min_x + cell_size, max_x)
            local cell_min_y = min_y + iy * cell_size
            local cell_max_y = math.min(cell_min_y + cell_size, max_y)
            local cell_min_z = min_z + iz * cell_size
            local cell_max_z = math.min(cell_min_z + cell_size, max_z)

            -- prevent cube from reaching outside cell
            local spawn_min_x = cell_min_x + scale
            local spawn_max_x = cell_max_x - scale
            local spawn_min_y = cell_min_y + scale
            local spawn_max_y = cell_max_y - scale
            local spawn_min_z = cell_min_z + scale
            local spawn_max_z = cell_max_z - scale

            local x = rt.random.number(spawn_min_x, spawn_max_x)
            local y = rt.random.number(spawn_min_y, spawn_max_y)
            local z = rt.random.number(spawn_min_z, spawn_max_z)

            local qx, qy, qz, qw = math.quaternion.random()

            local hue = rt.random.number(0, 1)
            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue, 1)

            table.insert(entry.data_mesh_data, {
                x, y, z,
                scale,
                qx, qy, qz, qw,
                r, g, b, a
            })

            table.insert(entry.data_mesh_data_aux, {
                rotation_speed = rt.random.choose(-1, 1) * rt.random.number(
                    settings.min_rotation_speed,
                    settings.max_rotation_speed
                ),

                rotation_axis = { math.normalize(
                    rt.random.number(-1, 1),
                    rt.random.number(-1, 1),
                    rt.random.number(-1, 1)
                )}
            })
        end

        local grid_x_count = math.ceil((max_x - min_x) / cell_size)
        local grid_y_count = math.ceil((max_y - min_y) / cell_size)
        local grid_z_count = math.ceil((max_z - min_z) / cell_size)

        for ix = 0, grid_x_count - 1 do
            for iy = 0, grid_y_count - 1 do
                for iz = 0, grid_z_count - 1 do
                    if rt.random.toss_coin(shape_probability) then
                        generate_particle(
                            rt.random.choose(to_sample),
                            ix, iy, iz,
                            settings.min_scale,
                            settings.max_scale
                        )
                    else
                        generate_particle(
                            sphere_entry,
                            ix, iy, iz,
                            settings.min_scale_bloom,
                            settings.max_scale_bloom
                        )
                    end
                end
            end
        end
    end

    -- post process
    local to_remove = {}
    for entry_i, entry in ipairs(self._particles) do
        entry.n_particles = #entry.data_mesh_data
        if entry.n_particles == 0 then
            table.insert(to_remove, 1, entry_i)
        else
            table.sort(entry.data_mesh_data, function(a, b)
                return a[3] < b[3]
            end)

            entry.data_mesh = rt.Mesh(
                entry.data_mesh_data,
                rt.MeshDrawMode.POINTS,
                _data_mesh_format,
                rt.GraphicsBufferUsage.STREAM
            )

            for format in values(_data_mesh_format) do
                entry.instance_mesh:attach_attribute(
                    entry.data_mesh,
                    format.name,
                    rt.MeshAttributeAttachmentMode.PER_INSTANCE
                )
            end
        end
    end

    for i in values(to_remove) do table.remove(self._particles, i) end

    if self._room_mesh == nil then
        self:_init_room_mesh()
    end

    if self._front_wall_mesh == nil then
        self:_init_front_wall_mesh()
    end
end

--- @brief
function ow.Background:draw()
    if self._canvas_needs_update == true then
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)

        local scale = self:_get_scale_factor()

        -- room drawn unaffected by stage camera
        --[[
        local room_transform = self._view_transform:clone()
        room_transform:scale(scale, scale, 1)
        room_transform:apply(self._scale_transform)
        room_transform:translate(0, 0, rt.settings.overworld.background.z_zoom)

        self._canvas:set_view_transform(room_transform)
        _room_shader:bind()
        _room_shader:send("elapsed", rt.SceneManager:get_elapsed())
        self._room_mesh:draw()
        _room_shader:unbind()
        ]]--

        local particle_transform = self._view_transform:clone()
        particle_transform:scale(scale, scale, 1)
        particle_transform:apply(self._scale_transform)
        particle_transform:translate(0, 0, rt.settings.overworld.background.z_zoom)
        particle_transform:apply(self._offset_transform)
        self._canvas:set_view_transform(particle_transform)
        _particle_shader_no_bloom:bind()
        for entry in values(self._particles) do
            if entry.is_bloom == false then
                entry.instance_mesh:draw_instanced(entry.n_particles)
            end
        end
        _particle_shader_no_bloom:unbind()

        _particle_shader_no_bloom:bind()
        for entry in values(self._particles) do
            if entry.is_bloom == true then
                entry.instance_mesh:draw_instanced(entry.n_particles)
            end
        end
        _particle_shader_no_bloom:unbind()

        --[[
        local front_wall_transform = rt.Transform()
        front_wall_transform:apply(self._scale_transform)
        front_wall_transform:apply(self._offset_transform)

        _front_wall_shader:bind()
        _front_wall_shader:send("elapsed", rt.SceneManager:get_elapsed())
        _front_wall_shader:send("player_position", { rt.SceneManager:get_current_scene():get_camera():world_xy_to_screen_xy(rt.GameState:get_player():get_position()) })
        _front_wall_shader:send("camera_scale", self._camera_scale)
        _front_wall_shader:send("camera_offset", self._camera_offset)
        self._front_wall_mesh:draw()
        _front_wall_shader:unbind()
        ]]--

        self._canvas:unbind()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.origin()
    self._canvas:draw()
    love.graphics.pop()
end

function ow.Background:draw_bloom()
    --[[
    self._canvas:bind()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    local particle_transform = self._view_transform:clone()
    local scale = self:_get_scale_factor()
    particle_transform:scale(scale, scale, 1)
    particle_transform:apply(self._scale_transform)
    particle_transform:translate(0, 0, rt.settings.overworld.background.z_zoom)
    particle_transform:apply(self._offset_transform)
    self._canvas:set_view_transform(particle_transform)
    _particle_shader_bloom:bind()
    for entry in values(self._particles) do
        if entry.is_bloom == true then
            entry.instance_mesh:draw_instanced(entry.n_particles)
        end
    end
    _particle_shader_bloom:unbind()
    self._canvas:unbind()
    ]]--
    love.graphics.push()
    love.graphics.origin()
    self._canvas:draw()
    love.graphics.pop()
end

--- @brief
function ow.Background:notify_camera_changed(camera)
    do
        self._scale_transform:reset()
        local scale = camera:get_final_scale()
        self._scale_transform:scale(scale, scale, 1)
    end

    local offset_x, offset_y = camera:get_offset() -- in screen coords (pixels)

    local aspect = self._bounds.width / self._bounds.height
    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)
    local near_z = rt.settings.overworld.background.stage_z_position

    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local world_offset_x = (offset_x / self._bounds.width) * (2 * half_w_near)
    local world_offset_y = (offset_y / self._bounds.height) * (2 * half_h_near) * -1 -- y points down

    self._offset_transform:reset()
    self._offset_transform:translate(
        world_offset_x,
        world_offset_y,
        0
    )

    self._camera_scale = camera:get_final_scale()
    self._camera_offset = { camera:get_offset() }
end

--- @brief compute 3d aabb that is visible given view transform and fov
--- @return Number, Number, Number, Number, Number, Number min_x, max_x, min_y, max_y, min_z, max_z
function ow.Background:_get_3d_bounds()
    local aspect = self._bounds.width / self._bounds.height
    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)

    local settings = rt.settings.overworld.background
    local near_z = settings.min_depth
    local far_z = settings.max_depth
    local z_zoom = settings.z_zoom
    local z_back_eff = far_z + z_zoom

    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local min_x, max_x = -half_w_near, half_w_near
    local min_y, max_y = -half_h_near, half_h_near
    local min_z, max_z = near_z, far_z

    return min_x, max_x, min_y, max_y, min_z, max_z
end

--- @brief scale factor such that only back wall is visible
function ow.Background:_get_scale_factor()
    local aspect = self._bounds.width / self._bounds.height

    local fov = math.pi * self._canvas:get_fov()
    local tan_half = math.tan(0.5 * fov)

    local settings = rt.settings.overworld.background
    local near_z = settings.min_depth
    local far_z = settings.max_depth
    local z_zoom = settings.z_zoom or 0

    local z_back_eff = far_z + z_zoom

    local half_h_near = tan_half * near_z
    local half_w_near = half_h_near * aspect

    local s_norm = 1 / math.sqrt(3)
    local max_radius = s_norm * settings.max_scale

    local room_half_w = math.max(half_w_near - max_radius, math.eps)
    local room_half_h = math.max(half_h_near - max_radius, math.eps)

    local half_h_back = tan_half * z_back_eff
    local half_w_back = half_h_back * aspect

    local sx = half_w_back / room_half_w
    local sy = half_h_back / room_half_h
    return math.max(sx, sy)
end

--- @brief
function ow.Background:update(delta)
    self._canvas_needs_update = true

    local min_x, max_x, min_y, max_y, min_z, max_z = table.unpack(self._room_bounds)

    local transform = self._offset_transform:clone()
    min_x, min_y, min_z = transform:inverse_transform_point(min_x, min_y, min_z)
    max_x, max_y, max_z = transform:inverse_transform_point(max_x, max_y, max_z)

    for entry in values(self._particles) do
        for data_i, data in ipairs(entry.data_mesh_data) do
            local aux_data = entry.data_mesh_data_aux[data_i]
            local x, y, z = data[1], data[2], data[3]
            local bx, by, bz = x, y, z

            -- wrap when moving out of visible box
            local x_wrapped, y_wrapped, z_wrapped = false, false, false

            local width = max_x - min_x
            if x > max_x then
                x = min_x + (x - max_x) % width
                x_wrapped = true
            elseif x < min_x then
                x = max_x - (min_x - x) % width
                x_wrapped = true
            end

            local height = max_y - min_y
            if y > max_y then
                y = min_y + (y - max_y) % height
                y_wrapped = true
            elseif y < min_y then
                y = max_y - (min_y - y) % height
                y_wrapped = true
            end

            local depth = max_z - min_z
            if z > max_z then
                z = min_z + (z - max_z) % depth
                z_wrapped = true
            elseif z < min_z then
                z = max_z - (min_z - z) % depth
                z_wrapped = true
            end

            -- if wrapped, teleport to new deterministic position
            if x_wrapped then
                y = math.mix(min_y, max_y, rt.random.noise(x, y))
            end

            if y_wrapped then
                x = math.mix(min_x, max_x, rt.random.noise(y, x))
            end

            data[1], data[2], data[3] = x, y, z

            -- rotate
            local angle = delta * 2 * math.pi * aux_data.rotation_speed
            local axis_x, axis_y, axis_z = table.unpack(aux_data.rotation_axis)
            data[5], data[6], data[7], data[8] = math.quaternion.normalize(math.quaternion.multiply(
                data[5], data[6], data[7], data[8],
                math.quaternion.from_axis_angle(axis_x, axis_y, axis_z, angle)
            ))
        end

        entry.data_mesh:replace_data(entry.data_mesh_data)
    end
end

function ow.Background:_init_cube_particle()
    local cube_mesh_data = {}
    local s = 1 / math.sqrt(3)
    local vertex_index = 1

    local function add_vertex(x, y, z, u, v)
        table.insert(cube_mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    local faces = {
        { {-s,-s, s}, { s,-s, s}, { s, s, s}, {-s, s, s} }, -- front
        { { s,-s,-s}, {-s,-s,-s}, {-s, s,-s}, { s, s,-s} }, -- back
        { {-s,-s,-s}, { s,-s,-s}, { s,-s, s}, {-s,-s, s} }, -- top
        { {-s, s, s}, { s, s, s}, { s, s,-s}, {-s, s,-s} }, -- bottom
        { { s,-s, s}, { s,-s,-s}, { s, s,-s}, { s, s, s} }, -- right
        { {-s,-s,-s}, {-s,-s, s}, {-s, s, s}, {-s, s,-s} }, -- left
    }

    local indices = {}

    for _, face in ipairs(faces) do
        local v = {}
        for i = 1, 4 do
            v[i] = add_vertex(face[i][1], face[i][2], face[i][3], 0, 0)
        end
        -- add center vertex
        local cx, cy, cz = 0, 0, 0
        for i = 1, 4 do
            cx = cx + face[i][1]
            cy = cy + face[i][2]
            cz = cz + face[i][3]
        end
        cx, cy, cz = cx / 4, cy / 4, cz / 4
        local vc = add_vertex(cx, cy, cz, 1, 1)

        -- fan triangles
        table.insert(indices, v[1]); table.insert(indices, v[2]); table.insert(indices, vc)
        table.insert(indices, v[2]); table.insert(indices, v[3]); table.insert(indices, vc)
        table.insert(indices, v[3]); table.insert(indices, v[4]); table.insert(indices, vc)
        table.insert(indices, v[4]); table.insert(indices, v[1]); table.insert(indices, vc)
    end

    local mesh = rt.Mesh(
        cube_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    mesh:set_vertex_map(indices)
    return mesh
end

function ow.Background:_init_tetrahedron_particle()
    local mesh_data = {}
    local vertex_index = 1

    local function add_vertex(x, y, z, u, v)
        table.insert(mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    local s = 1 / math.sqrt(3)
    local verts = {
        {  s,  s,  s },
        { -s, -s,  s },
        { -s,  s, -s },
        {  s, -s, -s },
    }

    local faces = {
        {1,2,3},
        {1,4,2},
        {1,3,4},
        {2,4,3}
    }

    local indices = {}

    for _, f in ipairs(faces) do
        local v1 = add_vertex(verts[f[1]][1], verts[f[1]][2], verts[f[1]][3], 0, 0)
        local v2 = add_vertex(verts[f[2]][1], verts[f[2]][2], verts[f[2]][3], 0, 0)
        local v3 = add_vertex(verts[f[3]][1], verts[f[3]][2], verts[f[3]][3], 0, 0)

        local cx = (verts[f[1]][1] + verts[f[2]][1] + verts[f[3]][1]) / 3
        local cy = (verts[f[1]][2] + verts[f[2]][2] + verts[f[3]][2]) / 3
        local cz = (verts[f[1]][3] + verts[f[2]][3] + verts[f[3]][3]) / 3
        local vc = add_vertex(cx, cy, cz, 1, 1)

        table.insert(indices, v1); table.insert(indices, v2); table.insert(indices, vc)
        table.insert(indices, v2); table.insert(indices, v3); table.insert(indices, vc)
        table.insert(indices, v3); table.insert(indices, v1); table.insert(indices, vc)
    end

    local mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat3D, rt.GraphicsBufferUsage.STATIC)
    mesh:set_vertex_map(indices)
    return mesh
end


function ow.Background:_init_octahedron_particle()
    local mesh_data = {}
    local vertex_index = 1

    local function add_vertex(x, y, z, u, v)
        table.insert(mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    local verts = {
        {0, 1, 0},  -- top
        {0, 0, 1},  -- front
        {1, 0, 0},  -- right
        {0, 0, -1}, -- back
        {-1, 0, 0}, -- left
        {0, -1, 0}, -- bottom
    }

    local faces = {
        {1,2,3},
        {1,3,4},
        {1,4,5},
        {1,5,2},
        {6,3,2},
        {6,4,3},
        {6,5,4},
        {6,2,5},
    }

    local indices = {}

    for _, f in ipairs(faces) do
        local v1 = add_vertex(verts[f[1]][1], verts[f[1]][2], verts[f[1]][3], 0, 0)
        local v2 = add_vertex(verts[f[2]][1], verts[f[2]][2], verts[f[2]][3], 0, 0)
        local v3 = add_vertex(verts[f[3]][1], verts[f[3]][2], verts[f[3]][3], 0, 0)

        local cx = (verts[f[1]][1] + verts[f[2]][1] + verts[f[3]][1]) / 3
        local cy = (verts[f[1]][2] + verts[f[2]][2] + verts[f[3]][2]) / 3
        local cz = (verts[f[1]][3] + verts[f[2]][3] + verts[f[3]][3]) / 3
        local vc = add_vertex(cx, cy, cz, 1, 1)

        table.insert(indices, v1); table.insert(indices, v2); table.insert(indices, vc)
        table.insert(indices, v2); table.insert(indices, v3); table.insert(indices, vc)
        table.insert(indices, v3); table.insert(indices, v1); table.insert(indices, vc)
    end

    local mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat3D, rt.GraphicsBufferUsage.STATIC)
    mesh:set_vertex_map(indices)
    return mesh
end

function ow.Background:_init_icosahedron_particle()
    local mesh_data = {}
    local vertex_index = 1

    local function add_vertex(x, y, z, u, v)
        table.insert(mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    local phi = (1 + math.sqrt(5)) / 2
    local scale = 1 / math.sqrt(phi * phi + 1)

    local verts = {
        { 0,  scale,  phi*scale },
        { 0, -scale,  phi*scale },
        { 0,  scale, -phi*scale },
        { 0, -scale, -phi*scale },
        {  scale,  phi*scale, 0 },
        { -scale,  phi*scale, 0 },
        {  scale, -phi*scale, 0 },
        { -scale, -phi*scale, 0 },
        {  phi*scale, 0,  scale },
        {  phi*scale, 0, -scale },
        { -phi*scale, 0,  scale },
        { -phi*scale, 0, -scale },
    }

    local raw_indices = {
        1,2,9, 1,9,5, 1,5,6, 1,6,11, 1,11,2,
        2,11,8, 2,8,7, 2,7,9,
        9,7,10, 9,10,5,
        5,10,3, 5,3,6,
        6,3,12, 6,12,11,
        11,12,8,
        8,12,4, 8,4,7,
        7,4,10,
        10,4,3,
        3,4,12
    }

    local indices = {}

    for i = 1, #raw_indices, 3 do
        local f = { raw_indices[i], raw_indices[i+1], raw_indices[i+2] }

        local v1 = add_vertex(verts[f[1]][1], verts[f[1]][2], verts[f[1]][3], 0, 0)
        local v2 = add_vertex(verts[f[2]][1], verts[f[2]][2], verts[f[2]][3], 0, 0)
        local v3 = add_vertex(verts[f[3]][1], verts[f[3]][2], verts[f[3]][3], 0, 0)

        local cx = (verts[f[1]][1] + verts[f[2]][1] + verts[f[3]][1]) / 3
        local cy = (verts[f[1]][2] + verts[f[2]][2] + verts[f[3]][2]) / 3
        local cz = (verts[f[1]][3] + verts[f[2]][3] + verts[f[3]][3]) / 3
        local vc = add_vertex(cx, cy, cz, 1, 1)

        table.insert(indices, v1); table.insert(indices, v2); table.insert(indices, vc)
        table.insert(indices, v2); table.insert(indices, v3); table.insert(indices, vc)
        table.insert(indices, v3); table.insert(indices, v1); table.insert(indices, vc)
    end

    local mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat3D, rt.GraphicsBufferUsage.STATIC)
    mesh:set_vertex_map(indices)
    return mesh
end

function ow.Background:_init_dodecahedron_particle()
    local mesh_data = {}
    local vertex_index = 1

    local function add_vertex(x, y, z, u, v)
        table.insert(mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    -- Golden ratio
    local phi = (1 + math.sqrt(5)) / 2
    local inv_phi = 1 / phi

    -- Dodecahedron vertices (normalized)
    -- These are the 20 vertices arranged in 3 orthogonal rectangles
    local verts = {
        -- Rectangle in xy-plane
        { 1,  1,  1},
        { 1,  1, -1},
        { 1, -1,  1},
        { 1, -1, -1},
        {-1,  1,  1},
        {-1,  1, -1},
        {-1, -1,  1},
        {-1, -1, -1},

        -- Rectangle in yz-plane
        { 0,  inv_phi,  phi},
        { 0,  inv_phi, -phi},
        { 0, -inv_phi,  phi},
        { 0, -inv_phi, -phi},

        -- Rectangle in xz-plane
        { inv_phi,  phi, 0},
        { inv_phi, -phi, 0},
        {-inv_phi,  phi, 0},
        {-inv_phi, -phi, 0},

        -- Additional rectangle in xz-plane
        { phi, 0,  inv_phi},
        { phi, 0, -inv_phi},
        {-phi, 0,  inv_phi},
        {-phi, 0, -inv_phi},
    }

    -- Normalize vertices
    for i = 1, #verts do
        local x, y, z = verts[i][1], verts[i][2], verts[i][3]
        local len = math.sqrt(x*x + y*y + z*z)
        verts[i][1] = x / len
        verts[i][2] = y / len
        verts[i][3] = z / len
    end

    -- Dodecahedron faces (12 pentagonal faces)
    -- Each face is defined by 5 vertices in CCW order when viewed from outside
    local faces = {
        {1, 9, 11, 3, 17},     -- Front-right
        {1, 17, 18, 2, 13},    -- Top-right
        {1, 13, 15, 5, 9},     -- Top-front
        {9, 5, 19, 7, 11},     -- Front-left
        {11, 7, 16, 14, 3},    -- Bottom-front
        {3, 14, 4, 18, 17},    -- Right
        {2, 18, 4, 12, 10},    -- Back-right
        {13, 2, 10, 6, 15},    -- Top-back
        {15, 6, 20, 19, 5},    -- Left
        {19, 20, 8, 16, 7},    -- Bottom-left
        {16, 8, 12, 4, 14},    -- Bottom-back
        {6, 10, 12, 8, 20},    -- Back
    }

    local indices = {}

    -- Generate mesh for each pentagonal face
    for _, face in ipairs(faces) do
        -- Add the 5 edge vertices
        local edge_verts = {}
        for i = 1, 5 do
            local v = verts[face[i]]
            local idx = add_vertex(v[1], v[2], v[3], 0, 0)
            table.insert(edge_verts, idx)
        end

        -- Calculate center vertex
        local cx, cy, cz = 0, 0, 0
        for i = 1, 5 do
            local v = verts[face[i]]
            cx = cx + v[1]
            cy = cy + v[2]
            cz = cz + v[3]
        end
        cx = cx / 5
        cy = cy / 5
        cz = cz / 5

        -- Add center vertex
        local center_idx = add_vertex(cx, cy, cz, 1, 1)

        -- Create 5 triangles: each edge pair with center
        for i = 1, 5 do
            local v1 = edge_verts[i]
            local v2 = edge_verts[(i % 5) + 1]  -- Wrap around to first vertex

            table.insert(indices, v1)
            table.insert(indices, v2)
            table.insert(indices, center_idx)
        end
    end

    local mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat3D, rt.GraphicsBufferUsage.STATIC)
    mesh:set_vertex_map(indices)
    return mesh
end


function ow.Background:_init_sphere_particle(n_rings, n_segments_per_ring)
    local sphere_mesh_data = {}
    local vertex_index = 1
    local indices = {}

    -- Add an edge vertex (shared between faces). All edge vertices get UV 1,1.
    local function add_vertex(x, y, z, _u, _v)
        table.insert(sphere_mesh_data, { x, y, z, 0, 0, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    -- Add a center vertex (unique per face). Center vertices get UV 0,0.
    local function add_center_vertex(x, y, z)
        table.insert(sphere_mesh_data, { x, y, z, 0, 0, 1, 1, 1, 1 })
        local idx = vertex_index
        vertex_index = vertex_index + 1
        return idx
    end

    -- Top pole
    local top_idx = add_vertex(0, -1, 0, 0.5, 0)

    -- Rings (excluding poles)
    local ring_indices = {}
    for ring = 1, n_rings - 1 do
        ring_indices[ring] = {}
        local phi = math.pi * ring / n_rings
        local y = -math.cos(phi)
        local ring_radius = math.sin(phi)

        for seg = 0, n_segments_per_ring - 1 do
            local theta = 2 * math.pi * seg / n_segments_per_ring
            local x = ring_radius * math.cos(theta)
            local z = ring_radius * math.sin(theta)
            local u = seg / n_segments_per_ring
            local v = ring / n_rings

            -- Note: u,v are ignored in add_vertex; all edge verts are forced to 1,1
            ring_indices[ring][seg + 1] = add_vertex(x, y, z, u, v)
        end
    end

    -- Bottom pole
    local bottom_idx = add_vertex(0, 1, 0, 0.5, 1)

    -- Top cap triangles (fan from top_idx to first ring)
    for seg = 0, n_segments_per_ring - 1 do
        local next_seg = (seg + 1) % n_segments_per_ring
        table.insert(indices, top_idx)
        table.insert(indices, ring_indices[1][seg + 1])
        table.insert(indices, ring_indices[1][next_seg + 1])
    end

    -- Middle quads split into two triangles each
    for ring = 1, n_rings - 2 do
        for seg = 0, n_segments_per_ring - 1 do
            local next_seg = (seg + 1) % n_segments_per_ring
            local curr_ring_curr = ring_indices[ring][seg + 1]
            local curr_ring_next = ring_indices[ring][next_seg + 1]
            local next_ring_curr = ring_indices[ring + 1][seg + 1]
            local next_ring_next = ring_indices[ring + 1][next_seg + 1]

            table.insert(indices, curr_ring_curr)
            table.insert(indices, next_ring_curr)
            table.insert(indices, curr_ring_next)

            table.insert(indices, curr_ring_next)
            table.insert(indices, next_ring_curr)
            table.insert(indices, next_ring_next)
        end
    end

    -- Bottom cap triangles (fan to bottom_idx from last ring)
    for seg = 0, n_segments_per_ring - 1 do
        local next_seg = (seg + 1) % n_segments_per_ring
        table.insert(indices, ring_indices[n_rings - 1][seg + 1])
        table.insert(indices, bottom_idx)
        table.insert(indices, ring_indices[n_rings - 1][next_seg + 1])
    end

    -- Re-triangulate by inserting a center vertex for each triangle
    -- Each original triangle (a,b,c) becomes:
    -- (a, b, center), (b, c, center), (c, a, center)
    local new_indices = {}
    for i = 1, #indices, 3 do
        local a = indices[i]
        local b = indices[i + 1]
        local c = indices[i + 2]

        -- Fetch positions (1-based indexing)
        local va = sphere_mesh_data[a]
        local vb = sphere_mesh_data[b]
        local vc = sphere_mesh_data[c]

        local cx = (va[1] + vb[1] + vc[1]) / 3
        local cy = (va[2] + vb[2] + vc[2]) / 3
        local cz = (va[3] + vb[3] + vc[3]) / 3

        local center_idx = add_center_vertex(cx, cy, cz)

        -- Maintain winding; indices are 1-based
        table.insert(new_indices, a); table.insert(new_indices, b); table.insert(new_indices, center_idx)
        table.insert(new_indices, b); table.insert(new_indices, c); table.insert(new_indices, center_idx)
        table.insert(new_indices, c); table.insert(new_indices, a); table.insert(new_indices, center_idx)
    end

    -- Build mesh
    local instance_mesh = rt.Mesh(
        sphere_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )
    instance_mesh:set_vertex_map(new_indices)

    return instance_mesh
end


function ow.Background:_init_cuboid_particle()
    local mesh_data = {}
    local indices = {}
    local vertex_count = 0

    local s = 1 / math.sqrt(3)  -- outer radius
    local t = rt.settings.overworld.background.cube_thickness * s -- beam thickness (adjust this value as needed)
    local si = s - t -- inner radius

    local vertex_cache = {}

    local n_digits = 8
    local scale = 10^n_digits
    function get_vertex_key(x, y, z)
        -- Round to avoid floating point precision issues
        local px = math.floor(x * scale + 0.5)
        local py = math.floor(y * scale + 0.5)
        local pz = math.floor(z * scale + 0.5)
        return string.format("%d %d %d", px, py, pz)
    end

    function add_vertex(x, y, z, u, v)
        local key = get_vertex_key(x, y, z)
        if vertex_cache[key] then
            return vertex_cache[key]
        end

        table.insert(mesh_data, { x, y, z, u, v, 1, 1, 1, 1 })
        vertex_count = vertex_count + 1
        vertex_cache[key] = vertex_count
        return vertex_count
    end

    function add_quad(v1, v2, v3, v4)
        -- Add two triangles for a quad (v1-v2-v3-v4 in CCW order)
        table.insert(indices, v1)
        table.insert(indices, v2)
        table.insert(indices, v3)
        table.insert(indices, v1)
        table.insert(indices, v3)
        table.insert(indices, v4)
    end

    function add_frame_strip(o1, o2, i1, i2)
        add_quad(o1, o2, i2, i1)
    end

    -- +Z face (front)
    local v = {}
    v[1] = add_vertex(-s, -s, s, 0, 0)
    v[2] = add_vertex(s, -s, s, 1, 0)
    v[3] = add_vertex(s, s, s, 1, 1)
    v[4] = add_vertex(-s, s, s, 0, 1)
    v[5] = add_vertex(-si, -si, s, 1 / 4, 1 / 4)
    v[6] = add_vertex(si, -si, s, 3 / 4, 1 / 4)
    v[7] = add_vertex(si, si, s, 3 / 4, 3 / 4)
    v[8] = add_vertex(-si, si, s, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- -Z face (back)
    v = {}
    v[1] = add_vertex(s, -s, -s, 0, 0)
    v[2] = add_vertex(-s, -s, -s, 1, 0)
    v[3] = add_vertex(-s, s, -s, 1, 1)
    v[4] = add_vertex(s, s, -s, 0, 1)
    v[5] = add_vertex(si, -si, -s, 1 / 4, 1 / 4)
    v[6] = add_vertex(-si, -si, -s, 3 / 4, 1 / 4)
    v[7] = add_vertex(-si, si, -s, 3 / 4, 3 / 4)
    v[8] = add_vertex(si, si, -s, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- +Y face (top)
    v = {}
    v[1] = add_vertex(-s, s, s, 0, 0)
    v[2] = add_vertex(s, s, s, 1, 0)
    v[3] = add_vertex(s, s, -s, 1, 1)
    v[4] = add_vertex(-s, s, -s, 0, 1)
    v[5] = add_vertex(-si, s, si, 1 / 4, 1 / 4)
    v[6] = add_vertex(si, s, si, 3 / 4, 1 / 4)
    v[7] = add_vertex(si, s, -si, 3 / 4, 3 / 4)
    v[8] = add_vertex(-si, s, -si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- -Y face (bottom)
    v = {}
    v[1] = add_vertex(-s, -s, -s, 0, 0)
    v[2] = add_vertex(s, -s, -s, 1, 0)
    v[3] = add_vertex(s, -s, s, 1, 1)
    v[4] = add_vertex(-s, -s, s, 0, 1)
    v[5] = add_vertex(-si, -s, -si, 1 / 4, 1 / 4)
    v[6] = add_vertex(si, -s, -si, 3 / 4, 1 / 4)
    v[7] = add_vertex(si, -s, si, 3 / 4, 3 / 4)
    v[8] = add_vertex(-si, -s, si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- +X face (right)
    v = {}
    v[1] = add_vertex(s, -s, s, 0, 0)
    v[2] = add_vertex(s, -s, -s, 1, 0)
    v[3] = add_vertex(s, s, -s, 1, 1)
    v[4] = add_vertex(s, s, s, 0, 1)
    v[5] = add_vertex(s, -si, si, 1 / 4, 1 / 4)
    v[6] = add_vertex(s, -si, -si, 3 / 4, 1 / 4)
    v[7] = add_vertex(s, si, -si, 3 / 4, 3 / 4)
    v[8] = add_vertex(s, si, si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- -X face (left)
    v = {}
    v[1] = add_vertex(-s, -s, -s, 0, 0)
    v[2] = add_vertex(-s, -s, s, 1, 0)
    v[3] = add_vertex(-s, s, s, 1, 1)
    v[4] = add_vertex(-s, s, -s, 0, 1)
    v[5] = add_vertex(-s, -si, -si, 1 / 4, 1 / 4)
    v[6] = add_vertex(-s, -si, si, 3 / 4, 1 / 4)
    v[7] = add_vertex(-s, si, si, 3 / 4, 3 / 4)
    v[8] = add_vertex(-s, si, -si, 1 / 4, 3 / 4)

    add_frame_strip(v[1], v[2], v[5], v[6])
    add_frame_strip(v[2], v[3], v[6], v[7])
    add_frame_strip(v[3], v[4], v[7], v[8])
    add_frame_strip(v[4], v[1], v[8], v[5])

    -- Interior faces for 12 edge beams
    -- Each beam has 3 interior faces, vertices are now shared via cache

    -- 4 edges parallel to Z axis

    -- Edge at (-s, -s, z)
    v = {}
    v[1] = add_vertex(-si, -s, -si, 0, 0)
    v[2] = add_vertex(-s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(-s, -si, si, 0, 2 / 3)
    v[4] = add_vertex(-si, -s, si, 0, 1)
    v[5] = add_vertex(-si, -si, -s, 1, 0)
    v[6] = add_vertex(-si, -si, s, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[2], v[5], v[6], v[3])

    -- Edge at (s, -s, z)
    v = {}
    v[1] = add_vertex(si, -s, -si, 0, 0)
    v[2] = add_vertex(s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(s, -si, si, 0, 2 / 3)
    v[4] = add_vertex(si, -s, si, 0, 1)
    v[5] = add_vertex(si, -si, -s, 1, 0)
    v[6] = add_vertex(si, -si, s, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[3], v[6], v[5], v[2])

    -- Edge at (s, s, z)
    v = {}
    v[1] = add_vertex(si, s, -si, 0, 0)
    v[2] = add_vertex(s, si, -si, 0, 1 / 3)
    v[3] = add_vertex(s, si, si, 0, 2 / 3)
    v[4] = add_vertex(si, s, si, 0, 1)
    v[5] = add_vertex(si, si, -s, 1, 0)
    v[6] = add_vertex(si, si, s, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[5], v[2], v[3], v[6])

    -- Edge at (-s, s, z)
    v = {}
    v[1] = add_vertex(-si, s, -si, 0, 0)
    v[2] = add_vertex(-s, si, -si, 0, 1 / 3)
    v[3] = add_vertex(-s, si, si, 0, 2 / 3)
    v[4] = add_vertex(-si, s, si, 0, 1)
    v[5] = add_vertex(-si, si, -s, 1, 0)
    v[6] = add_vertex(-si, si, s, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[6], v[3], v[2], v[5])

    -- 4 edges parallel to X axis

    -- Edge at (x, -s, -s)
    v = {}
    v[1] = add_vertex(-si, -s, -si, 0, 0)
    v[2] = add_vertex(-si, -si, -s, 0, 1 / 3)
    v[3] = add_vertex(si, -si, -s, 0, 2 / 3)
    v[4] = add_vertex(si, -s, -si, 0, 1)
    v[5] = add_vertex(-s, -si, -si, 1, 0)
    v[6] = add_vertex(s, -si, -si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[2], v[5], v[6], v[3])

    -- Edge at (x, s, -s)
    v = {}
    v[1] = add_vertex(-si, s, -si, 0, 0)
    v[2] = add_vertex(-si, si, -s, 0, 1 / 3)
    v[3] = add_vertex(si, si, -s, 0, 2 / 3)
    v[4] = add_vertex(si, s, -si, 0, 1)
    v[5] = add_vertex(-s, si, -si, 1, 0)
    v[6] = add_vertex(s, si, -si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[3], v[6], v[5], v[2])

    -- Edge at (x, s, s)
    v = {}
    v[1] = add_vertex(-si, s, si, 0, 0)
    v[2] = add_vertex(-si, si, s, 0, 1 / 3)
    v[3] = add_vertex(si, si, s, 0, 2 / 3)
    v[4] = add_vertex(si, s, si, 0, 1)
    v[5] = add_vertex(-s, si, si, 1, 0)
    v[6] = add_vertex(s, si, si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[5], v[2], v[3], v[6])

    -- Edge at (x, -s, s)
    v = {}
    v[1] = add_vertex(-si, -s, si, 0, 0)
    v[2] = add_vertex(-si, -si, s, 0, 1 / 3)
    v[3] = add_vertex(si, -si, s, 0, 2 / 3)
    v[4] = add_vertex(si, -s, si, 0, 1)
    v[5] = add_vertex(-s, -si, si, 1, 0)
    v[6] = add_vertex(s, -si, si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[6], v[3], v[2], v[5])

    -- 4 edges parallel to Y axis

    -- Edge at (-s, y, -s)
    v = {}
    v[1] = add_vertex(-si, -si, -s, 0, 0)
    v[2] = add_vertex(-s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(-s, si, -si, 0, 2 / 3)
    v[4] = add_vertex(-si, si, -s, 0, 1)
    v[5] = add_vertex(-si, -s, -si, 1, 0)
    v[6] = add_vertex(-si, s, -si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[2], v[5], v[6], v[3])

    -- Edge at (s, y, -s)
    v = {}
    v[1] = add_vertex(si, -si, -s, 0, 0)
    v[2] = add_vertex(s, -si, -si, 0, 1 / 3)
    v[3] = add_vertex(s, si, -si, 0, 2 / 3)
    v[4] = add_vertex(si, si, -s, 0, 1)
    v[5] = add_vertex(si, -s, -si, 1, 0)
    v[6] = add_vertex(si, s, -si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[3], v[6], v[5], v[2])

    -- Edge at (s, y, s)
    v = {}
    v[1] = add_vertex(si, -si, s, 0, 0)
    v[2] = add_vertex(s, -si, si, 0, 1 / 3)
    v[3] = add_vertex(s, si, si, 0, 2 / 3)
    v[4] = add_vertex(si, si, s, 0, 1)
    v[5] = add_vertex(si, -s, si, 1, 0)
    v[6] = add_vertex(si, s, si, 1, 1)
    add_quad(v[1], v[5], v[6], v[4])
    add_quad(v[1], v[2], v[3], v[4])
    add_quad(v[5], v[2], v[3], v[6])

    -- Edge at (-s, y, s)
    v = {}
    v[1] = add_vertex(-si, -si, s, 0, 0)
    v[2] = add_vertex(-s, -si, si, 0, 1 / 3)
    v[3] = add_vertex(-s, si, si, 0, 2 / 3)
    v[4] = add_vertex(-si, si, s, 0, 1)
    v[5] = add_vertex(-si, -s, si, 1, 0)
    v[6] = add_vertex(-si, s, si, 1, 1)
    add_quad(v[4], v[6], v[5], v[1])
    add_quad(v[4], v[3], v[2], v[1])
    add_quad(v[6], v[3], v[2], v[5])

    local instance_mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    instance_mesh:set_vertex_map(indices)
    return instance_mesh
end

--- @brief
function ow.Background:_init_room_mesh()
    local room_mesh_data = {}
    local settings = rt.settings.overworld.background

    -- get 3D visible bounds
    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()
    local hue = 0

    local r, g, b, a = settings.room_color:unpack()
    local function add_vertex(x, y, z, u, v)
        table.insert(room_mesh_data, {
            x, y, z,
            u, v,
            hue * r, hue * g, hue * b, 1
        })
    end

    -- back wall
    hue = 1
    add_vertex(min_x, min_y, max_z, 0, 1)
    add_vertex(max_x, min_y, max_z, 1, 1)
    add_vertex(max_x, max_y, max_z, 1, 0)
    add_vertex(min_x, max_y, max_z, 0, 0)

    -- top wall
    hue = 2
    add_vertex(min_x, min_y, min_z, 0, 1)
    add_vertex(max_x, min_y, min_z, 1, 1)
    add_vertex(max_x, min_y, max_z, 1, 0)
    add_vertex(min_x, min_y, max_z, 0, 0)

    -- bottom wall
    hue = 2
    add_vertex(min_x, max_y, max_z, 0, 1)
    add_vertex(max_x, max_y, max_z, 1, 1)
    add_vertex(max_x, max_y, min_z, 1, 0)
    add_vertex(min_x, max_y, min_z, 0, 0)

    -- right wall
    hue = 1.5
    add_vertex(max_x, min_y, min_z, 0, 1)
    add_vertex(max_x, max_y, min_z, 1, 1)
    add_vertex(max_x, max_y, max_z, 1, 0)
    add_vertex(max_x, min_y, max_z, 0, 0)

    -- left wall
    hue = 1.5
    add_vertex(min_x, min_y, max_z, 0, 1)
    add_vertex(min_x, max_y, max_z, 1, 1)
    add_vertex(min_x, max_y, min_z, 1, 0)
    add_vertex(min_x, min_y, min_z, 0, 0)

    self._room_mesh = rt.Mesh(
        room_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    -- define triangles (no front wall)
    self._room_mesh:set_vertex_map({
        1, 2, 3, -- back wall
        1, 3, 4,

        5, 6, 7, -- top wall
        5, 7, 8,

        9, 10, 11, -- bottom wall
        9, 11, 12,

        13, 14, 15, -- right wall
        13, 15, 16,

        17, 18, 19, -- left wall
        17, 19, 20
    })
end

--- @brief
function ow.Background:_init_front_wall_mesh()
    local mesh_data = {}
    local function add_vertex(x, y, z, u, v)
        table.insert(mesh_data, {
            x, y, z, u, v, 1, 1, 1, 1
        })
    end

    local min_x, max_x, min_y, max_y, min_z, max_z = self:_get_3d_bounds()

    local z = 0
    add_vertex(min_x, min_y, z, 0, 1)
    add_vertex(max_x, min_y, z, 1, 1)
    add_vertex(max_x, max_y, z, 1, 0)
    add_vertex(min_x, max_y, z, 0, 0)

    self._front_wall_mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STATIC
    )

    self._front_wall_mesh:set_vertex_map(
        1, 2, 3, -- back wall
        1, 3, 4
    )
end
