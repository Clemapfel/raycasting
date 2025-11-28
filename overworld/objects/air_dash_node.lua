require "common.path"
require "overworld.air_dash_node_particle"

rt.settings.overworld.air_dash_node = {
    core_radius = 10,
    cooldown = 25 / 60,
    min_opacity = 0.0
}

--- @class AirDashNode
--- @types Circle
ow.AirDashNode = meta.class("AirDashNode")

local _handler, _is_first = true
function ow.AirDashNode:reinitialize()
    _handler = nil
    _is_first = true
end

local _core_shader = rt.Shader("overworld/objects/air_dash_node_glow.glsl")

local eps = 0.01

--- @brief
function ow.AirDashNode:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.AirDashNode: object `" .. object:get_id() .. "` is not a circle")

    self._x, self._y = object:get_centroid()
    self._tether_start_x, self._tether_start_y = self._x, self._y
    self._radius = object.x_radius

    self._scene = scene
    self._stage = stage

    -- dummy collision, for camera queries
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )

    self._body:set_is_sensor(true)
    self._body:set_collides_with(0x0)
    self._body:set_collision_group(0x0)

    self._is_current = false -- if the player initiates tether, this is the target
    self._is_tethered = false -- player is currently tethered

    self._cooldown_elapsed = math.huge

    -- graphics
    self._is_current_motion = rt.SmoothedMotion1D(0, 1.2)
    self._is_tethered_motion = rt.SmoothedMotion1D(0)

    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1))
    self._particle = ow.AirDashNodeParticle(rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor)
    self._particle_opacity_motion = rt.SmoothedMotion1D(1, 2)
    self._particles = ow.PlayerTetherParticleEffect()

    self._line_opacity_motion = rt.SmoothedMotion1D(0, 3.5)

    do
        local radius_a = 2 * rt.settings.overworld.air_dash_node.core_radius
        local radius_b = self._radius
        local radius_c = 1.25 * self._radius

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
        require "overworld.air_dash_node_handler"
        _handler = ow.AirDashNodeHandler(self._scene, self._stage)
        self._is_handler_proxy = true
        _is_first = false

        DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "k" then
                _core_shader:recompile()
            end
        end)
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
    end

    if before == true and b == false then
        local bx, by = self._tether_start_x, self._tether_start_y

        local dx, dy = self._x - bx, self._y - by
        local ax, ay = self._x + dx, self._y + dy
        dbg(meta.typeof(self._particles))
        self._particles:emit(
            rt.Path(ax, ay, bx, by),
            self:get_color():unpack()
        )

        self._dbg = { ax, ay, bx, by }
    end
end

--- @brief
function ow.AirDashNode:set_is_current(b)
    self._is_current = b
    self._is_current_motion:set_target_value(ternary(b, 1, 0))

    local px, py = self._scene:get_player():get_position()
    local dx, dy = math.normalize(px - self._x, py - self._y)
    self._particle:set_aligned(b, dx, dy, 0)
    --self._particle:set_is_exploded(not b)
end

--- @brief
function ow.AirDashNode:get_position()
    return self._x, self._y
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

    local is_visible = self._stage:get_is_body_visible(self._body)

    self._line_opacity_motion:update(delta)
    if self._was_tethered == false and self._is_tethered == true then
        self._line_opacity_motion:set_target_value(1)
        self._particle_opacity_motion:set_target_value(0)
        self._particle:set_is_exploded(true)
    elseif self._was_tethered == true and self._is_tethered == false then
        self._line_opacity_motion:set_target_value(0)
        self._particle_opacity_motion:set_target_value(1)
        self._particle:set_is_exploded(false)
    end
    self._was_tethered = self._is_tethered

    if is_visible then
        self._is_current_motion:update(delta)
        self._is_tethered_motion:update(delta)
        self._particle:update(delta)
        self._particles:update(delta)
    end

    -- update particle if on screen and visible
    if is_visible then
        if self._particle_opacity_motion:get_value() > eps then
            self._particle:update(delta)
        end
    end

    -- update line if visible
    if self._line_opacity_motion:get_value() > eps then
        local x1, y1 = self._x, self._y
        local x2, y2 = self._scene:get_player():get_position()

        local dx, dy = math.normalize(x2 - x1, y2 - y1)
        local inner_width = 1
        local outer_width = 3

        local up_x, up_y = math.turn_left(dx, dy)
        local inner_up_x, inner_up_y = up_x * inner_width, up_y * inner_width
        local outer_up_x, outer_up_y = up_x * (inner_width + outer_width), up_y * (inner_width + outer_width)

        local down_x, down_y = math.turn_right(dx, dy)
        local inner_down_x, inner_down_y = down_x * inner_width, down_y * inner_width
        local outer_down_x, outer_down_y = down_x * (inner_width + outer_width), down_y * (inner_width + outer_width)

        local inner_up_x1, inner_up_y1 = x1 + inner_up_x, y1 + inner_up_y
        local outer_up_x1, outer_up_y1 = x1 + outer_up_x, y1 + outer_up_y
        local inner_down_x1, inner_down_y1 = x1 + inner_down_x, y1 + inner_down_y
        local outer_down_x1, outer_down_y1 = x1 + outer_down_x, y1 + outer_down_y

        local inner_up_x2, inner_up_y2 = x2 + inner_up_x, y2 + inner_up_y
        local outer_up_x2, outer_up_y2 = x2 + outer_up_x, y2 + outer_up_y
        local inner_down_x2, inner_down_y2 = x2 + inner_down_x, y2 + inner_down_y
        local outer_down_x2, outer_down_y2 = x2 + outer_down_x, y2 + outer_down_y

        local r1, r2 = 1, 1
        local a1, a2 = 1, 0

        local data = {
            { outer_down_x1, outer_down_y1, r2, r2, r2, a2 },
            { inner_down_x1, inner_down_y1, r1, r1, r1, a1 },
            { x1, y1, r1, r1, r1, a1 },
            { inner_up_x1, inner_up_y1, r1, r1, r1, a1 },
            { outer_up_x1, outer_up_y1, r2, r2, r2, a2 },

            { outer_down_x2, outer_down_y2, r2, r2, r2, a2 },
            { inner_down_x2, inner_down_y2, r1, r1, r1, a1 },
            { x2, y2, r1, r1, r1, 2 },
            { inner_up_x2, inner_up_y2, r1, r1, r1, a1 },
            { outer_up_x2, outer_up_y2, r2, r2, r2, a2 },
        }

        if self._line_mesh == nil then
            self._line_mesh = love.graphics.newMesh({
                {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"},
                {location = 2, name = rt.VertexAttribute.COLOR, format = "floatvec4"},
            }, data,
                rt.MeshDrawMode.TRIANGLES,
                rt.GraphicsBufferUsage.STREAM
            )

            self._line_mesh:setVertexMap(
                1, 6, 7,
                1, 2, 7,
                2, 7, 8,
                2, 3, 8,
                3, 8, 9,
                3, 4, 9,
                4, 9, 10,
                4, 5, 10
            )
        else
            self._line_mesh:setVertices(data)
        end
    end
end

--- @brief
function ow.AirDashNode:draw()
    --if self._is_handler_proxy then _handler:draw() end

    if not self._stage:get_is_body_visible(self._body) then return end
    local r, g, b, a = self._color:unpack()

    local current_a = self._is_current_motion:get_value()
    local cooldown_a = 1 - math.min(1, self._cooldown_elapsed / rt.settings.overworld.air_dash_node.cooldown)
    local opacity =  math.max(
        current_a,
        cooldown_a,
        rt.settings.overworld.air_dash_node.min_opacity
    )

    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.NORMAL)

    _core_shader:bind()
    _core_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _core_shader:send("color", { r, g, b, opacity })
    self._glow_mesh:draw()
    _core_shader:unbind()

    rt.graphics.set_blend_mode()

    love.graphics.setColor(r, g, b, 1)
    self._particle:draw(self._x, self._y, true, true)

    local line_a = self._line_opacity_motion:get_value()
    if line_a > eps then
        local r, g, b = self._color:unpack()
        love.graphics.setColor(r, g, b, 1)
        love.graphics.draw(self._line_mesh)
    end
    self._particles:draw()

    if self._is_current or self._is_tethered then
        local px, py = self._scene:get_player():get_position()
        --love.graphics.line(px, py, self._x, self._y)
    end

    if line_a > eps then
        local r, g, b = self._color:unpack()
        love.graphics.setColor(r, g, b, 1)
        love.graphics.draw(self._line_mesh)
    end

    love.graphics.setColor(1, 1, 1, 1)
    --love.graphics.circle("fill", self._x, self._y, rt.settings.overworld.air_dash_node.core_radius)
end

--- @brief
--- @brief
function ow.AirDashNode:draw_bloom()
    if self._stage:get_is_body_visible(self._body) == false then return end

    local r, g, b = self._color:unpack()
    local shape_a = self._particle_opacity_motion:get_value()
    if shape_a > 1e-3 then
        love.graphics.setColor(r, g, b, shape_a)
        self._particle:draw(self._x, self._y, false, true) -- line only
    end
end

--- @brief
function ow.AirDashNode:get_color()
    return self._color
end

--- @brief
function ow.AirDashNode:get_render_priority()
    return -1
end
