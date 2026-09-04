require "common.contour"
require "overworld.movable_object"
require "common.quaternion"

rt.settings.overworld.kill_plane = {

    noise_cell_size = 10,
    noise_density = 0.4,
    min_radius = 3,
    max_radius = 12,

    min_rotation_speed = 0.05, -- radians per second
    max_rotation_speed = 0.1,

    outline_width = 2.5,
    player_range = 3 * rt.settings.player.radius * rt.settings.player.bubble_radius_factor
}

--- @class ow.KillPlane
--- @types Polygon, Rectangle, Ellipse
ow.KillPlane = meta.class("KillPlane", ow.MovableObject)

local schema = {
    should_explode = ow.Boolean,
    is_visible = ow.Boolean
}

local _data_mesh_format = {
    { location = 3, name = "particle_position", format = "floatvec2" },
    { location = 4, name = "particle_scale", format = "float" },
    { location = 5, name = "particle_rotation", format = "floatvec4" }, -- quaternion
    { location = 6, name = "particle_is_outline", format = "float" }
}

local _instance_draw_shader = rt.Shader("overworld/objects/kill_plane_instanced_draw.glsl")
local _background_shader = rt.Shader("overworld/objects/kill_plane_background.glsl")

local _x_offset = 0
local _y_offset = 1
local _radius_offset = 2
local _qx_offset = 3
local _qy_offset = 4
local _qz_offset = 5
local _qw_offset = 6
local _is_outline_offset = 7
local _particle_stride = _is_outline_offset + 1

local _axis_speed_offset = 0
local _axis_x_offset = 1
local _axis_y_offset = 2
local _axis_z_offset = 3
local _axis_stride = _axis_z_offset + 1

function ow.KillPlane:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)

    self._scene = scene
    self._stage = stage

    -- collision
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)

    local group = bit.bor(
        rt.settings.player.player_collision_group,
        rt.settings.player.player_outer_body_collision_group
    )
    self._body:set_collides_with(group)

    self._should_explode = object:get_boolean("should_explode", false)
    if self._should_explode == nil then self._should_explode = true end

    self._is_blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag(b2.Tag.PLAYER) then
            local player = self._scene:get_player()
            if self._is_blocked == true
                or player:get_is_disabled()
                or player:get_is_ghost()
            then return end

            player:kill(self._should_explode)
            self._is_blocked = true
            self._stage:get_physics_world():signal_connect("step", function()
                self._is_blocked = false
                return meta.DISCONNECT_SIGNAL
            end)
        end
    end)

    -- visibility : disable mesh
    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end
    if self._is_visible == false then return end

    self._contour = rt.contour.close(object:create_contour(true))  -- translate to origin

    -- lights
    self._body:add_tag(b2.Tag.POINT_LIGHT_SOURCE, b2.Tag.SEGMENT_LIGHT_SOURCE)
    self._body:set_user_data(self)

    local start_x, start_y = self._body:get_position()

    self._segment_lights = {}
    self._point_lights = {}
    if object:get_type() == ow.ObjectType.POLYGON then
        for i = 1, #self._contour - 2, 2 do
            local x1, y1 = self._contour[i+0], self._contour[i+1]
            local x2, y2 = self._contour[math.wrap(i+2, #self._contour)], self._contour[math.wrap(i+3, #self._contour)]
            table.insert(self._segment_lights, { x1, y1, x2, y2 })
        end
    elseif object:get_type() == ow.ObjectType.ELLIPSE then
        table.insert(self._point_lights, {
            object.center_x - start_x,
            object.center_y - start_y,
            math.max(object.x_radius, object.y_radius)
        })
    end

    self._mask = object:create_mesh(true) -- translate to origin
    self._outline_width = rt.settings.overworld.kill_plane.outline_width
    self._color = rt.Palette.KILL_PLANE
    self._outline_color = rt.Palette.KILL_PLANE_OUTLINE

    do -- instanced mesh
        local up_x, up_y = math.cos(-1/2 * math.pi), math.sin(-1/2 * math.pi)
        local right_x, right_y = math.cos(-1/2 * math.pi + 2/3 * math.pi), math.sin(-1/2 * math.pi + 2/3 * math.pi)
        local left_x, left_y = math.cos(-1/2 * math.pi + 4/3 * math.pi), math.sin(-1/2 * math.pi + 4/3 * math.pi)

        local center_x, center_y = 0, 0
        local radius = 1
        local aa_radius = 1.05

        local data = {}
        local function add(x, y, alpha, value)
            local u = 0
            local v = 0
            value = value or 1
            table.insert(data, {
                x, y,
                u, v,
                value, value, value, alpha
            })
        end

        add(center_x + up_x * radius, center_y + up_y * radius, 1, 2)
        add(center_x + right_x * radius, center_y + right_y * radius, 1, 0.75)
        add(center_x + left_x * radius, center_y + left_y * radius, 1, 0.75)

        add(center_x + up_x * aa_radius, center_y + up_y * aa_radius, 0)
        add(center_x + right_x * aa_radius, center_y + right_y * aa_radius, 0)
        add(center_x + left_x * aa_radius, center_y + left_y * aa_radius, 0)

        self._instance_mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)
        self._instance_mesh:set_vertex_map(
            1, 2, 3,

            1, 2, 4,
            2, 5, 4,
            2, 3, 5,
            3, 6, 5,
            3, 1, 6,
            1, 4, 6
        )
    end

    self._n_particles = 0

    do -- data mesh
        local particle_data = {}
        local axis_data = {}
        local min_radius, max_radius = rt.settings.overworld.kill_plane.min_radius, rt.settings.overworld.kill_plane.max_radius
        local noise_cutoff = 1 - rt.settings.overworld.kill_plane.noise_density
        local not_outline, outline = 0, 1

        local aabb = rt.contour.get_aabb(self._contour)
        local cell_size = rt.settings.overworld.kill_plane.noise_cell_size

        local add = function(x, y)
            local radius = rt.random.number(min_radius, max_radius)

            -- prevent overlap with outer border
            x = math.clamp(x, aabb.x + radius + self._outline_width, aabb.x + aabb.width - radius - self._outline_width)
            y = math.clamp(y, aabb.y + radius + self._outline_width, aabb.y + aabb.height - radius - self._outline_width)

            local qx, qy, qz, qw = math.quaternion.random()

            local i = #particle_data + 1
            particle_data[i + _x_offset] = x
            particle_data[i + _y_offset] = y
            particle_data[i + _radius_offset] = radius
            particle_data[i + _qx_offset] = qx
            particle_data[i + _qy_offset] = qy
            particle_data[i + _qz_offset] = qz
            particle_data[i + _qw_offset] = qw
            particle_data[i + _is_outline_offset] = outline

            i = #particle_data + 1
            particle_data[i + _x_offset] = x
            particle_data[i + _y_offset] = y
            particle_data[i + _radius_offset] = radius
            particle_data[i + _qx_offset] = qx
            particle_data[i + _qy_offset] = qy
            particle_data[i + _qz_offset] = qz
            particle_data[i + _qw_offset] = qw
            particle_data[i + _is_outline_offset] = not_outline

            i = #axis_data + 1
            axis_data[i + _axis_speed_offset] = rt.random.choose(-1, 1) * rt.random.number(
                rt.settings.overworld.kill_plane.min_rotation_speed,
                rt.settings.overworld.kill_plane.max_rotation_speed
            )

            local ax, ay, az = math.normalize3(
                rt.random.number(-1, 1),
                rt.random.number(-1, 1),
                rt.random.number(-1, 1)
            )

            axis_data[i + _axis_x_offset] = ax
            axis_data[i + _axis_y_offset] = ay
            axis_data[i + _axis_z_offset] = az

            self._n_particles = self._n_particles + 1
        end

        local n_columns = math.ceil(aabb.width / cell_size)
        local x_overhang = aabb.width - n_columns * cell_size

        local n_rows = math.ceil(aabb.height / cell_size)
        local y_overhang = aabb.height - n_rows * cell_size

        local noise_offset = meta.hash(self) * math.pi

        local n_instances = 0
        do
            local should_break = false
            for column_i = 1, n_columns do
                for row_i = 1, n_rows do
                    local local_x = aabb.x + (column_i - 1) * cell_size + 0.5 * x_overhang + 0.5 * cell_size
                    local local_y = aabb.y + (row_i - 1) * cell_size + 0.5 * y_overhang + 0.5 * cell_size

                    if self._body:test_point(local_x + start_x, local_y + start_y)
                        and rt.random.noise(noise_offset + local_x, noise_offset + local_y) > noise_cutoff
                    then
                        local angle = rt.random.number(0, 2 * math.pi)
                        local offset = rt.random.number(-0.25 * cell_size, 0.25 * cell_size)
                        add(
                            local_x + offset * math.cos(angle),
                            local_y + offset * math.sin(angle)
                        )

                        n_instances = n_instances + 1
                        if n_instances > 10000 then
                            rt.critical("In ow.KillPlane: instance count of kill plane `", object:get_id(), "` exceeded limit. Consider resizing the object")
                            should_break = true
                            break
                        end
                    end
                end

                if should_break then break end
            end
        end

        if #particle_data == 0 then
            self._is_visible = false
            return
        end

        -- first create lua table, then export to bytedata because number of
        -- particles is indeterminate until everything is allocated

        self._byte_data = rt.ByteData(rt.ByteDataFormat.FLOAT32, particle_data)
        self._particle_data = particle_data
        self._axis_data = axis_data

        self._data_mesh = rt.Mesh(
            self._byte_data,
            rt.MeshDrawMode.POINTS,
            _data_mesh_format,
            rt.GraphicsBufferUsage.STREAM
        )

        for format in values(_data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._data_mesh,
                format.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end

        self._n_instances = #particle_data / 2
    end
end

function ow.KillPlane:update(delta)
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) then
        return
    end

    local px, py = self._scene:get_player():get_position()
    local ox, oy = self._body:get_position()
    local range = rt.settings.overworld.kill_plane.player_range

    local bx, by, bw, bh = self._scene:get_camera():get_world_bounds():unpack()

    local use_ffi = ffi ~= nil
    local particle_data
    if use_ffi then
        particle_data = self._byte_data:get_pointer() -- float*, 0-based
    else
        particle_data = self._particle_data -- lua table, 1-based
    end

    local axis_data = self._axis_data
    local particle_stride = _particle_stride
    local axis_stride = _axis_stride

    for i = 1, self._n_particles do
        local outline_i = (i - 1) * 2 * particle_stride + 1
        local fill_i = outline_i + particle_stride

        if use_ffi then
            outline_i = outline_i - 1
            fill_i = fill_i - 1
        end

        local x_local = particle_data[outline_i + _x_offset]
        local y_local = particle_data[outline_i + _y_offset]
        local x_world = x_local + ox
        local y_world = y_local + oy

        local qx = particle_data[outline_i + _qx_offset]
        local qy = particle_data[outline_i + _qy_offset]
        local qz = particle_data[outline_i + _qz_offset]
        local qw = particle_data[outline_i + _qw_offset]

        local axis_i = (i - 1) * axis_stride + 1
        local speed = axis_data[axis_i + _axis_speed_offset]
        local axis_x = axis_data[axis_i + _axis_x_offset]
        local axis_y = axis_data[axis_i + _axis_y_offset]
        local axis_z = axis_data[axis_i + _axis_z_offset]
        local angle = delta * 2 * math.pi * speed

        if x_world >= bx and x_world <= bx + bw and y_world >= by and y_world <= by + bh then
            local dx = px - x_world
            local dy = py - y_world
            local player_angle = math.angle(dx, dy) + 0.5 * math.pi
            local t = math.min(1, math.distance(x_world, y_world, px, py) / range)

            local player_qx, player_qy, player_qz, player_qw = math.quaternion.from_axis_angle(
                0, 0, 1,
                player_angle
            )

            local axis_qx, axis_qy, axis_qz, axis_qw = math.quaternion.from_axis_angle(
                axis_x, axis_y, axis_z, angle
            )

            local rotated_qx, rotated_qy, rotated_qz, rotated_qw = math.quaternion.multiply(
                qx, qy, qz, qw,
                axis_qx, axis_qy, axis_qz, axis_qw
            )

            local new_qx, new_qy, new_qz, new_qw = math.quaternion.mix(
                player_qx, player_qy, player_qz, player_qw,
                rotated_qx, rotated_qy, rotated_qz, rotated_qw,
                t
            )

            particle_data[outline_i + _qx_offset] = new_qx
            particle_data[outline_i + _qy_offset] = new_qy
            particle_data[outline_i + _qz_offset] = new_qz
            particle_data[outline_i + _qw_offset] = new_qw

            particle_data[fill_i + _qx_offset] = new_qx
            particle_data[fill_i + _qy_offset] = new_qy
            particle_data[fill_i + _qz_offset] = new_qz
            particle_data[fill_i + _qw_offset] = new_qw
        end
    end

    if not use_ffi then
        self._byte_data:replace_data(particle_data)
    end

    self._data_mesh:replace_data(self._byte_data)
end

--- @brief
function ow.KillPlane:draw()
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    local transform = self._scene:get_camera():get_transform()
    transform:translate(offset_x, offset_y)
    transform = transform:inverse()

    self._color:bind()
    _background_shader:bind()
    _background_shader:send("screen_to_world_transform", transform)
    _background_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _instance_draw_shader:send("black", { rt.Palette.BLACK:unpack() })
    self._mask:draw()
    _background_shader:unbind()

    self._color:bind()
    _instance_draw_shader:bind()
    _instance_draw_shader:send("outline_thickness", self._outline_width)
    _instance_draw_shader:send("outline_color", { self._outline_color:unpack() })
    _instance_draw_shader:send("black", { rt.Palette.BLACK:unpack() })
    self._instance_mesh:draw_instanced(self._n_instances)
    _instance_draw_shader:unbind()

    love.graphics.setLineJoin("bevel")

    self._color:bind()
    love.graphics.setLineWidth(self._outline_width)
    love.graphics.line(self._contour)

    self._outline_color:bind()
    love.graphics.setLineWidth(self._outline_width - 2)
    love.graphics.line(self._contour)

    love.graphics.pop()
end

--- @brief
function ow.KillPlane:collect_segment_lights(callback)
    local offset_x, offset_y = self._body:get_position()

    local r, g, b, a = rt.Palette.KILL_PLANE:unpack()
    for segment in values(self._segment_lights) do
        local x1, y1, x2, y2 = table.unpack(segment)
        callback(
            x1 + offset_x,
            y1 + offset_y,
            x2 + offset_x,
            y2 + offset_y,
            r, g, b, a
        )
    end
end

--- @brief
function ow.KillPlane:collect_point_lights(callback)
    local offset_x, offset_y = self._body:get_position()

    local r, g, b, a = rt.Palette.KILL_PLANE:unpack()
    for point in values(self._point_lights) do
        local x, y, radius = table.unpack(point)
        callback(
            x + offset_x,
            y + offset_y,
            radius,
            r, g, b, a
        )
    end
end