require "common.contour"
require "overworld.movable_object"
require "common.quaternion"

rt.settings.overworld.kill_plane = {
    border_width = 20
}

--- @class ow.KillPlane
--- @types Polygon, Rectangle, Ellipse
--- @field is_visible Boolean?
--- @field should_explode Boolean?
ow.KillPlane = meta.class("KillPlane", ow.MovableObject)

local _data_mesh_format = {
    { location = 3, name = "particle_position", format = "floatvec2" },
    { location = 4, name = "particle_scale", format = "floatvec2" },
    { location = 5, name = "particle_rotation", format = "floatvec4" }, -- quaternion
    { location = 6, name = "is_outline", format = "uint32" }
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
    self._outline_thickness = 2
    self._color = rt.Palette.MINT_04
    self._outline_color = rt.Palette.MINT_02

    do -- instanced mesh
        local up_x, up_y = math.cos(-1/2 * math.pi), math.sin(-1/2 * math.pi)
        local right_x, right_y = math.cos(-1/2 * math.pi + 2/3 * math.pi), math.sin(-1/2 * math.pi + 2/3 * math.pi)
        local left_x, left_y = math.cos(-1/2 * math.pi + 4/3 * math.pi), math.sin(-1/2 * math.pi + 4/3 * math.pi)

        local center_x, center_y = 0, 0
        local radius = 1

        local data = {}
        local function add(x, y, is_outline)
            if is_outline == true then is_outline = 1 else is_outline = 0 end
            local u = 0
            local v = 0
            table.insert(data, {
                x, y,
                u, v,
                is_outline, is_outline, is_outline, 1
            })
        end

        add(center_x + up_x * radius, center_y + up_y * radius, false)
        add(center_x + right_x * radius, center_y + right_y * radius, false)
        add(center_x + left_x * radius, center_y + left_y * radius, false)

        --[[
        -- inside tri and outer quads separate so is_outline does not blend

        add(center_x + up_x * radius, center_y + up_y * radius, true)
        add(center_x + up_x * outline_radius, center_y + up_y * outline_radius, true)
        add(center_x + right_x * radius, center_y + right_y * radius, true)
        add(center_x + right_x * outline_radius, center_y + right_y * outline_radius, true)
        add(center_x + left_x * radius, center_y + left_y * radius, true)
        add(center_x + left_x * outline_radius, center_y + left_y * outline_radius, true)
        ]]

        self._instance_mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)

        --[[
        self._instance_mesh:set_vertex_map(
            1, 2, 3,

            4, 5, 6,
            5, 6, 7,
            6, 7, 9,
            6, 8, 9,
            4, 5, 8,
            5, 8, 9
        )]]
    end

    do -- data mesh
        self._dbg = {}
        local data_mesh_data = {}
        local min_radius, max_radius = 3, 9
        local noise_cutoff = 0.75

        local add = function(x, y)
            local radius = rt.random.number(min_radius, max_radius)
            table.insert(data_mesh_data, {
                x, y,
                radius,
                math.quaternion.random()
            })

            table.insert(self._dbg, x)
            table.insert(self._dbg, y)
        end

        local aabb = rt.contour.get_aabb(self._contour)
        local cell_size = 6 -- px

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

function ow.KillPlane:draw()
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x - self._centroid_x, offset_y - self._centroid_y)

    love.graphics.setColor(1, 1, 1, 1)
    _instance_draw_shader:bind()
    _instance_draw_shader:send("outline_thickness", self._outline_thickness)
    _instance_draw_shader:send("outline_color", self._outline_color)
    self._instance_mesh:draw_instanced(self._n_instances)
    _instance_draw_shader:unbind()

    --love.graphics.points(self._dbg)

    love.graphics.pop()
end

--- @brief
function ow.KillPlane:get_render_priority()
    return 2
end