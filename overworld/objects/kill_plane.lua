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
--- @field is_visible Boolean?
--- @field should_explode Boolean?
ow.KillPlane = meta.class("KillPlane", ow.MovableObject)

local _data_mesh_format = {
    { location = 3, name = "particle_position", format = "floatvec2" },
    { location = 4, name = "particle_scale", format = "float" },
    { location = 5, name = "particle_rotation", format = "floatvec4" }, -- quaternion
    { location = 6, name = "particle_is_outline", format = "uint32" }
}

local _instance_draw_shader = rt.Shader("overworld/objects/kill_plane_instanced_draw.glsl")

function ow.KillPlane:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    -- collision
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._should_explode = object:get_boolean("should_explode", false)
    if self._should_explode == nil then self._should_explode = true end

    self._is_blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            if self._is_blocked == true then return end
            --self._scene:get_player():kill(self._should_explode)
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

    self._contour = rt.contour.close(object:create_contour())
    self._centroid_x, self._centroid_y = object:get_centroid()

    self._mask = object:create_mesh()
    self._outline_width = rt.settings.overworld.kill_plane.outline_width
    self._color = rt.Palette.MINT_5
    self._outline_color = rt.Palette.MINT_1

    do -- instanced mesh
        local up_x, up_y = math.cos(-1/2 * math.pi), math.sin(-1/2 * math.pi)
        local right_x, right_y = math.cos(-1/2 * math.pi + 2/3 * math.pi), math.sin(-1/2 * math.pi + 2/3 * math.pi)
        local left_x, left_y = math.cos(-1/2 * math.pi + 4/3 * math.pi), math.sin(-1/2 * math.pi + 4/3 * math.pi)

        local center_x, center_y = 0, 0
        local radius = 1

        local data = {}
        local function add(x, y, is_outline)
            local u = 0
            local v = 0
            table.insert(data, {
                x, y,
                u, v,
                1, 1, 1, 1
            })
        end

        add(center_x + up_x * radius, center_y + up_y * radius, false)
        add(center_x + right_x * radius, center_y + right_y * radius, false)
        add(center_x + left_x * radius, center_y + left_y * radius, false)

        self._instance_mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)
    end

    do -- data mesh
        local data_mesh_data = {}
        local axis_data = {}
        local min_radius, max_radius = rt.settings.overworld.kill_plane.min_radius, rt.settings.overworld.kill_plane.max_radius
        local noise_cutoff = 1 - rt.settings.overworld.kill_plane.noise_density
        local not_outline, outline = 0, 1

        local add = function(x, y)
            local radius = rt.random.number(min_radius, max_radius)
            local qx, qy, qz, qw = math.quaternion.random()

            table.insert(data_mesh_data, {
                x, y,
                radius,
                qx, qy, qz, qw,
                outline,
            })

            table.insert(data_mesh_data, {
                x, y,
                radius,
                qx, qy, qz, qw,
                not_outline,
            })

            table.insert(axis_data, {
                speed = rt.random.choose(-1, 1) * rt.random.number(
                    rt.settings.overworld.kill_plane.min_rotation_speed,
                    rt.settings.overworld.kill_plane.max_rotation_speed
                ),
                axis = {
                    math.normalize(
                        rt.random.number(-1, 1),
                        rt.random.number(-1, 1),
                        rt.random.number(-1, 1)
                    )
                }
            })
        end

        local aabb = rt.contour.get_aabb(self._contour)
        local cell_size = rt.settings.overworld.kill_plane.noise_cell_size

        local n_columns = math.ceil(aabb.width / cell_size)
        local x_overhang = aabb.width - n_columns * cell_size

        local n_rows = math.ceil(aabb.height / cell_size)
        local y_overhang = aabb.height - n_columns * cell_size

        local noise_offset = meta.hash(self) * math.pi

        for column_i = 1, n_columns do
            for row_i = 1, n_rows do
                local world_x = aabb.x + (column_i - 1) * cell_size + 0.5 * x_overhang + 0.5 * cell_size
                local world_y = aabb.y + (row_i - 1) * cell_size + 0.5 * y_overhang + 0.5 * cell_size

                if rt.random.noise(noise_offset + world_x, noise_offset + world_y) > noise_cutoff then
                    local angle = rt.random.number(0, 2 * math.pi)
                    local offset = rt.random.number(-0.25 * cell_size, 0.25 * cell_size)
                    add(
                        world_x + offset * math.cos(angle),
                        world_y + offset * math.sin(angle)
                    )
                end
            end
        end

        self._data_mesh_data = data_mesh_data
        self._axis_data = axis_data

        self._data_mesh = rt.Mesh(
            data_mesh_data,
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

        self._n_instances = #self._data_mesh_data
    end
end

--- @brief
function ow.KillPlane:update(delta)
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) then
        return
    end

    local px, py = self._scene:get_player():get_position()
    local ox, oy = self._body:get_position()
    local cx, cy = self._centroid_x, self._centroid_y
    local range = rt.settings.overworld.kill_plane.player_range

    local bounds = self._scene:get_camera():get_world_bounds()

    local axis_i = 1
    for i = 1, #self._data_mesh_data, 2 do
        local data = self._data_mesh_data[i]
        local qx, qy, qz, qw = data[4], data[5], data[6], data[7]
        local axis_data = self._axis_data[axis_i]
        local angle = delta * 2 * math.pi * axis_data.speed
        local axis_x, axis_y, axis_z = table.unpack(axis_data.axis)

        local x_local, y_local = data[1], data[2]
        local x_world = x_local + (ox - cx)
        local y_world = y_local + (oy - cy)

        if bounds:contains(x_world, y_world) then

            local dx = px - x_world
            local dy = py - y_world
            local player_angle = math.angle(dx, dy) + 0.5 * math.pi
            local t = math.min(1, math.distance(x_world, y_world, px, py) / range)

            -- Calculate player-facing orientation
            local player_qx, player_qy, player_qz, player_qw = math.quaternion.from_axis_angle(
                0, 0, 1,
                player_angle
            )

            local rotated_qx, rotated_qy, rotated_qz, rotated_qw = math.quaternion.multiply(
                qx, qy, qz, qw,
                math.quaternion.from_axis_angle(axis_x, axis_y, axis_z, angle)
            )

            local new_qx, new_qy, new_qz, new_qw = math.quaternion.mix(
                player_qx, player_qy, player_qz, player_qw,
                rotated_qx, rotated_qy, rotated_qz, rotated_qw,
                t
            )

            local a = self._data_mesh_data[i+0]
            local b = self._data_mesh_data[i+1]
            a[4], a[5], a[6], a[7] = new_qx, new_qy, new_qz, new_qw
            b[4], b[5], b[6], b[7] = new_qx, new_qy, new_qz, new_qw
        end

        axis_i = axis_i + 1
    end

    self._data_mesh:replace_data(self._data_mesh_data)
end

--- @brief
function ow.KillPlane:draw()
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x - self._centroid_x, offset_y - self._centroid_y)

    local stencil = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.DRAW)
    self._mask:draw()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    rt.Palette.BLACK:bind()
    self._mask:draw()

    self._color:bind()
    _instance_draw_shader:bind()
    _instance_draw_shader:send("outline_thickness", self._outline_width)
    _instance_draw_shader:send("outline_color", { self._outline_color:unpack() })
    _instance_draw_shader:send("black", { rt.Palette.BLACK:unpack()})
    self._instance_mesh:draw_instanced(self._n_instances)
    _instance_draw_shader:unbind()

    rt.graphics.set_stencil_mode(nil)

    love.graphics.setLineJoin("bevel")

    self._color:bind()
    love.graphics.setLineWidth(self._outline_width)
    love.graphics.line(self._contour)

    self._outline_color:bind()
    love.graphics.setLineWidth(self._outline_width - 2)
    love.graphics.line(self._contour)

    love.graphics.pop()
end
