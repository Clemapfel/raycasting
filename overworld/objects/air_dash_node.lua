require "common.path"

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

local _core_shader = rt.Shader("overworld/objects/air_dash_node_core.glsl")

--- @brief
function ow.AirDashNode:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.AirDashNode: object `" .. object:get_id() .. "` is not a circle")

    self._x, self._y = object:get_centroid()
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
        self._update_handler = true
        _is_first = false

        DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "k" then
                _core_shader:recompile()
            end
        end)
    else
        self._update_handler = false
    end

    _handler:notify_node_added(self)
end

--- @brief
function ow.AirDashNode:set_is_tethered(b)
    self._is_tethered = b

    if b == false then
        self._cooldown_elapsed = 0
    end

    self._is_current_motion:set_target_value(ternary(b, 1, 0))
end

--- @brief
function ow.AirDashNode:set_is_current(b)
    self._is_current = b
    self._is_current_motion:set_target_value(ternary(b, 1, 0))
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
    if self._update_handler then _handler:update(delta) end

    if not self._is_tethered then
        self._cooldown_elapsed = self._cooldown_elapsed + delta
    end

    local is_visible = self._stage:get_is_body_visible(self._body)

    if is_visible then
        self._is_current_motion:update(delta)
        self._is_tethered_motion:update(delta)
    end
end

--- @brief
function ow.AirDashNode:draw()
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

    if self._is_current or self._is_tethered then
        local px, py = self._scene:get_player():get_position()
        love.graphics.line(px, py, self._x, self._y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    --love.graphics.circle("fill", self._x, self._y, rt.settings.overworld.air_dash_node.core_radius)
end

--- @brief
function ow.AirDashNode:draw_bloom()
    local r, g, b, a = self._color:unpack()

    local current_a = self._is_current_motion:get_value()
    local cooldown_a = 1 - math.min(1, self._cooldown_elapsed / rt.settings.overworld.air_dash_node.cooldown)
    local opacity =  math.max(
        current_a,
        cooldown_a,
        rt.settings.overworld.air_dash_node.min_opacity
    )

    _core_shader:bind()
    _core_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _core_shader:send("color", { r, g, b, opacity })
    --self._glow_mesh:draw()
    _core_shader:unbind()
end

--- @brief
function ow.AirDashNode:get_color()
    return self._color
end

--- @brief
function ow.AirDashNode:get_render_priority()
    return -1
end
