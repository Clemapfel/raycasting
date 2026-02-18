require "common.path"
require "overworld.air_dash_node_particle"
require "overworld.movable_object"

rt.settings.overworld.air_dash_node = {
    core_radius = 10,
    indicator_length = 30,
    cooldown = 45 / 60,
    min_opacity = 0.0,
    particle_emit_delay_duration = 5 / 60, -- seconds

    solid_outline_alpha = 0.5, -- px
    solid_outline_line_width = 2,
    glow_aliasing_width = 15
}

--- @class AirDashNode
--- @types Circle
ow.AirDashNode = meta.class("AirDashNode", ow.MovableObject)

local _handler, _is_first = true
function ow.AirDashNode:reinitialize()
    _handler = nil
    _is_first = true
end

local _core_shader = rt.Shader("overworld/objects/air_dash_node_glow.glsl")

local _noise_texture = rt.NoiseTexture(64, 64, 64,
    rt.NoiseType.GRADIENT, 3.5
)

--- @brief
function ow.AirDashNode:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.AirDashNode: object `" .. object:get_id() .. "` is not a circle")

    self._x, self._y = object:get_centroid()
    self._tether_start_x, self._tether_start_y = self._x, self._y
    self._indicator, self._indicator_data = nil, nil
    self._radius = object.x_radius

    self._scene = scene
    self._stage = stage

    self._indicator_always_visible = object:get_boolean("indicator_always_visible", false)
    if self._indicator_always_visible == nil then self._indicator_always_visible = true end

    -- dummy collision, for camera queries
    self._body = b2.Body(
        stage:get_physics_world(),
        object:get_physics_body_type(),
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )

    self._body:set_is_sensor(true)
    self._body:set_collides_with(0x0)
    self._body:set_collision_group(0x0)
    self._body:add_tag("point_light_source")
    self._body:set_user_data(self)

    self._is_current = false -- if the player initiates tether, this is the target
    self._is_tethered = false -- player is currently tethered

    self._cooldown_elapsed = math.huge

    -- graphics
    self._is_current_motion = rt.SmoothedMotion1D(0)
    self._is_current_motion:set_speed(0.5, 0.5) -- attack, decay

    self._is_tethered_motion = rt.SmoothedMotion1D(0)

    self._hue = (meta.hash(self) % 16) / 16

    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    self._particle = ow.AirDashNodeParticle(rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor)
    self._particles = ow.TetherParticleEffect()
    self._dash_line = { self._x, self._y, self._x, self._y } -- love.Line

    self._queue_emit = nil -- Function
    self._queue_emit_elapsed = math.huge

    do
        local glow_aliasing_width = rt.settings.overworld.air_dash_node.glow_aliasing_width
        local radius_a = 2 * rt.settings.overworld.air_dash_node.core_radius
        local radius_b = self._radius
        local radius_c = self._radius + glow_aliasing_width

        local glow_data = {}
        local glow_vertex_map = {} -- 1-based

        local function add_vertex(which, x, y, u, v, arc_length, density, opacity)
            -- shader information encoded in rgba
            table.insert(which, {
                x, y,
                u, v,
                density,    -- x = density
                arc_length, -- y = arc length
                opacity,    -- z = opacity
                1           -- w = unused
            })
        end

        add_vertex(glow_data,
            self._x, self._y,
            0, 0,
            0,
            1,
            1
        )

        local n_outer_vertices = math.ceil(0.5 * self._radius)
        for i = 1, n_outer_vertices do
            local arc_length = (i - 1) / n_outer_vertices
            local angle = arc_length * 2 * math.pi
            local dx, dy = math.cos(angle), math.sin(angle)

            -- inner
            add_vertex(glow_data,
                self._x + dx * radius_a,
                self._y + dy * radius_a,
                dx, dy, arc_length,
                1,
                0
            )

            -- center
            add_vertex(glow_data,
                self._x + dx * radius_b,
                self._y + dy * radius_b,
                dx, dy, arc_length,
                1,
                1
            )

            -- outer
            add_vertex(glow_data,
                self._x + dx * radius_c,
                self._y + dy * radius_c,
                dx, dy, 1 - arc_length,
                0,
                0
            )
        end

        -- triangulate
        for i = 1, n_outer_vertices do
            local next_i = (i % n_outer_vertices) + 1

            local center_i = 1
            local a_i = 1 + (i - 1) * 3 + 1
            local b_i = 1 + (i - 1) * 3 + 2
            local c_i = 1 + (i - 1) * 3 + 3
            local next_a_i = 1 + (next_i - 1) * 3 + 1
            local next_b_i = 1 + (next_i - 1) * 3 + 2
            local next_c_i = 1 + (next_i - 1) * 3 + 3

            table.insert(glow_vertex_map, a_i)
            table.insert(glow_vertex_map, b_i)
            table.insert(glow_vertex_map, next_b_i)

            table.insert(glow_vertex_map, a_i)
            table.insert(glow_vertex_map, next_b_i)
            table.insert(glow_vertex_map, next_a_i)

            table.insert(glow_vertex_map, b_i)
            table.insert(glow_vertex_map, c_i)
            table.insert(glow_vertex_map, next_c_i)

            table.insert(glow_vertex_map, b_i)
            table.insert(glow_vertex_map, next_c_i)
            table.insert(glow_vertex_map, next_b_i)
        end

        self._glow_mesh = rt.Mesh(glow_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STATIC
        )
        self._glow_mesh:set_vertex_map(glow_vertex_map)
    end

    -- global handler

    if _is_first then -- first node is proxy instance
        require "overworld.air_dash_node_manager"
        _handler = ow.AirDashNodeManager(self._scene, self._stage)
        self._is_handler_proxy = true
        _is_first = false
    else
        self._is_handler_proxy = false
    end

    _handler:notify_node_added(self)
end

--- @brief
function ow.AirDashNode:set_is_tethered(b)
    local before = self._is_tethered
    self._is_tethered = b

    if b == false then
        self._cooldown_elapsed = 0
    end

    self._is_current_motion:set_target_value(ternary(b, 1, 0))

    if before == false and b == true then
        self._tether_start_x, self._tether_start_y = self._scene:get_player():get_position()
        self._particle:set_is_exploded(true)

    elseif before == true and b == false then
        local x, y = self._body:get_position()
        local px, py = self._tether_start_x, self._tether_start_y
        local dx, dy = math.normalize(x - px, y - py)
        local magnitude = rt.settings.overworld.air_dash_node.indicator_length
        dx = dx * magnitude
        dy = dy * magnitude

        local bx, by = x + dx, y + dy
        local ax, ay = px, py --x - dx, y - dy

        self._queue_emit = function()
            self._particles:emit(
                rt.Path(ax, ay, bx, by),
                self:get_color():unpack()
            )
        end
        self._queue_emit_elapsed = 0

        self._dash_line = { ax, ay, bx, by }
        self._particle:set_is_exploded(false)
    end
end

--- @brief
function ow.AirDashNode:set_is_current(b)
    self._is_current = b

    if b == true then
        -- skip animation
        self._is_current_motion:set_value(1)
    end

    local x, y = self._body:get_position()
    local px, py = self._scene:get_player():get_position()
    local dx, dy = math.normalize(px - x, py - y)
    self._particle:set_aligned(b, dx, dy, 0)
end

--- @brief
function ow.AirDashNode:set_is_outline_visible(b)
    self._is_current_motion:set_target_value(ternary(b, 1, 0))
end

--- @brief
function ow.AirDashNode:get_position()
    return self._body:get_position()
end

--- @brief
function ow.AirDashNode:get_radius()
    return self._radius
end

--- @brief
function ow.AirDashNode:get_body()
    return self._body
end

--- @brief
function ow.AirDashNode:get_is_on_cooldown()
    return self._cooldown_elapsed < rt.settings.overworld.air_dash_node.cooldown
end

--- @brief
function ow.AirDashNode:update(delta)
    if self._is_handler_proxy then _handler:update(delta) end

    if not self._is_tethered then
        self._cooldown_elapsed = self._cooldown_elapsed + delta
    end

    if self._queue_emit ~= nil then
        self._queue_emit_elapsed = self._queue_emit_elapsed + delta
    end

    if self._stage:get_is_body_visible(self._body) then
        self._is_current_motion:update(delta)
        self._is_tethered_motion:update(delta)
        self._particle:update(delta)
        self._particles:update(delta)

        if self._is_tethered or self._is_current then
            local x, y = self._body:get_position()
            local px, py = self._scene:get_player():get_position()
            local dx, dy = math.normalize(x - px, y - py)
            local magnitude = rt.settings.overworld.air_dash_node.indicator_length
            dx = dx * magnitude
            dy = dy * magnitude

            local bx, by = x + dx, y + dy
            local ax, ay = px, py --x - dx, y - dy

            local width = rt.settings.overworld.air_dash_node.core_radius  / 2
            local left_x, left_y = math.turn_left(math.normalize(dx, dy))
            local right_x, right_y = math.turn_right(math.normalize(dx, dy))

            local r, g, b, _ = self._color:unpack()

            if self._indicator == nil or self._indicator_data == nil then
                self._indicator_data = {}
                local function add_vertex(x, y, r, g, b)
                    table.insert(self._indicator_data, { x, y, 0, 0, r, g, b, 1 })
                end

                local t = 1.2 -- value boost

                add_vertex(ax, ay, r, g, b)
                add_vertex(x + left_x * width, y + left_y * width, r, g, b)
                add_vertex(x, y, t * r, t * g, t * b)
                add_vertex(x + right_x * width, y + right_y * width, r, g, b)
                add_vertex(bx, by, r, g, b)

                self._indicator_mesh = rt.Mesh(
                    self._indicator_data,
                    rt.MeshDrawMode.TRIANGLES,
                    rt.VertexFormat,
                    rt.GraphicsBufferUsage.STREAM
                )
                self._indicator_mesh:set_vertex_map(
                    1, 2, 3,
                    1, 3, 4,
                    2, 3, 5,
                    3, 4, 5
                )
            else
                local i = 1
                local function add_vertex(x, y)
                    self._indicator_data[i][1] = x
                    self._indicator_data[i][2] = y
                end

                add_vertex(ax, ay, r, g, b)
                add_vertex(x + left_x * width, y + left_y * width, r, g, b)
                add_vertex(x, y, 1, 1, 1)
                add_vertex(x + right_x * width, y + right_y * width, r, g, b)
                add_vertex(bx, by, r, g, b)

                self._indicator_mesh:replace_data(self._indicator_data)
            end

            self._indicator_mesh_outline = {
                ax, ay,
                x + left_x * width, y + left_y * width,
                bx, by,
                x + right_x * width, y + right_y * width,
                ax, ay -- line loop
            }
        end

        if self._queue_emit ~= nil and self._queue_emit_elapsed >= rt.settings.overworld.air_dash_node.particle_emit_delay_duration then
            self._queue_emit()
            self._queue_emit = nil
        end
    end
end

local _behind_player_priority = -1
local _in_front_of_payer_priority = 1

--- @brief
function ow.AirDashNode:draw(priority)
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()

    local r, g, b, a = self._color:unpack()
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()

    if priority == _behind_player_priority then

        love.graphics.push()
        love.graphics.translate(-self._x + offset_x, -self._y + offset_y)

        local current_a = self._is_current_motion:get_value()
        if self._indicator_always_visible then current_a = 1 end
        local cooldown_a = 1 - math.min(1, self._cooldown_elapsed / rt.settings.overworld.air_dash_node.cooldown)
        local opacity =  math.max(
            current_a,
            cooldown_a,
            rt.settings.overworld.air_dash_node.min_opacity
        )

        do
            local line_width = rt.settings.overworld.air_dash_node.solid_outline_line_width
            local alpha = rt.settings.overworld.air_dash_node.solid_outline_alpha * self._is_current_motion:get_value()

            love.graphics.setColor(r, g, b, alpha)
            love.graphics.setLineWidth(line_width)
            love.graphics.circle("line", self._x, self._y, self._radius)
        end

        if opacity > 0.01 then
            love.graphics.setColor(1, 1, 1, 1)
            _core_shader:bind()
            _core_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
            _core_shader:send("color", { r, g, b, opacity })
            _core_shader:send("noise_texture", _noise_texture)
            self._glow_mesh:draw()
            _core_shader:unbind()
        end

        if self._is_current == false then
            love.graphics.setColor(r, g, b, 1)
            self._particle:draw(self._x, self._y, true, true)
        end

        love.graphics.pop()

        self._particles:draw()

    elseif priority == _in_front_of_payer_priority then
        if self._indicator_mesh ~= nil and (self._is_current or self._is_tethered
            or self._queue_emit_elapsed < rt.settings.overworld.air_dash_node.particle_emit_delay_duration
        ) then
            local line_width = 0.5 * rt.settings.player.radius
            love.graphics.setColor(black_r, black_g, black_b, 1)
            love.graphics.line(self._indicator_mesh_outline)

            love.graphics.setColor(1, 1, 1, 1)
            self._indicator_mesh:draw()
        end

        love.graphics.push()
        love.graphics.translate(-self._x + offset_x, -self._y + offset_y)

        if self._is_current == true then
            love.graphics.setColor(r, g, b, 1)
            self._particle:draw(self._x, self._y, true, true)
        end

        love.graphics.pop()
    end
end

--- @brief
function ow.AirDashNode:draw_bloom()
    if self._stage:get_is_body_visible(self._body) == false then return end

    love.graphics.push()
    local offset_x, offset_y = self._body:get_position()
    love.graphics.translate(-self._x + offset_x, -self._y + offset_y)

    local r, g, b = self._color:unpack()
    love.graphics.setColor(r, g, b, 1)
    self._particle:draw(self._x, self._y, false, true) -- line only

    love.graphics.pop()
end

--- @brief
function ow.AirDashNode:get_color()
    return self._color
end

--- @brief
function ow.AirDashNode:get_render_priority()
    return _behind_player_priority, _in_front_of_payer_priority
end

--- @brief
function ow.AirDashNode:get_point_light_sources()
    local x, y = self._body:get_position()
    return { { x, y, self._radius } }, { self._color }
end