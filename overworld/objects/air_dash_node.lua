require "common.path"
require "overworld.air_dash_node_particle"
require "overworld.air_dash_node_particle_effect"
require "overworld.movable_object"

rt.settings.overworld.air_dash_node = {
    core_radius = 10,
    indicator_length = 30,
    cooldown = 45 / 60,
    min_opacity = 0.0,
    particle_emit_delay_duration = 5 / 60, -- seconds

    solid_outline_alpha = 0.5, -- px
    solid_outline_line_width = 2,
    glow_aliasing_width = 15,

    n_hue_steps = 16
}

--- @class AirDashNode
--- @types Circle
ow.AirDashNode = meta.class("AirDashNode", ow.MovableObject)

local _glow_shader = rt.Shader("overworld/objects/air_dash_node_glow.glsl")
local _noise_texture = rt.NoiseTexture(64, 64, 64,
    rt.NoiseType.GRADIENT, 3.5
)

ow.AirDashNode.reinitialize = function(scene, stage)
    require "overworld.air_dash_node_manager"
    if stage.air_dash_node_manager ~= nil then
        stage.air_dash_node_manager:clear()
    end

    stage.air_dash_node_manager = ow.AirDashNodeManager(scene, stage)
    stage.air_dash_node_manager_is_first = true
end

--- @brief
function ow.AirDashNode:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.AirDashNode: object `" .. object:get_id() .. "` is not a circle")

    if stage.air_dash_node_manager_is_first == true then
        self._is_handler_proxy = true
    else
        self._is_handler_proxy = false
    end

    local x, y = object:get_centroid()
    self._indicator, self._indicator_data = nil, nil
    self._radius = object.x_radius

    self._scene = scene
    self._stage = stage

    local direction = object:get_object("direction", false)
    self._has_direction = direction ~= nil

    if self._has_direction then
        rt.assert(direction:get_type() == ow.ObjectType.POINT, "In ow.DirectionalAirDashNode: direction object `", direction:get_id(), "` is not a point")
        self._direction_x, self._direction_y = math.normalize(
            direction.x - x,
            direction.y - y
        )
    end

    self._indicator_always_visible = object:get_boolean("indicator_always_visible", false)
    if self._indicator_always_visible == nil then self._indicator_always_visible = true end

    -- dummy collision, for camera queries
    self._body = b2.Body(
        stage:get_physics_world(),
        object:get_physics_body_type(),
        x, y,
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

    if scene.air_dash_node_hue == nil then
        scene.air_dash_node_hue = 0
    end

    local n_hue_steps = rt.settings.overworld.air_dash_node.n_hue_steps
    self._hue = (scene.air_dash_node_hue % n_hue_steps) / n_hue_steps
    scene.air_dash_node_hue = scene.air_dash_node_hue + 1
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))

    self._particle = ow.AirDashNodeParticle(rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor)
    self._particles = ow.AirDashNodeParticleEffect()

    self._circle_vertices = {}
    local n_vertices = rt.Mesh.radius_to_n_vertices(self._radius, self._radius)
    for i = 1, n_vertices + 1 do
        local angle = (i - 1) / n_vertices * 2 * math.pi
        table.insert(self._circle_vertices, math.cos(angle) * self._radius)
        table.insert(self._circle_vertices, math.sin(angle) * self._radius)
    end

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

        local glow_x, glow_y = 0, 0

        add_vertex(glow_data,
            glow_x, glow_y,
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
                glow_x + dx * radius_a,
                glow_y + dy * radius_a,
                dx, dy, arc_length,
                1,
                0
            )

            -- center
            add_vertex(glow_data,
                glow_x + dx * radius_b,
                glow_y + dy * radius_b,
                dx, dy, arc_length,
                1,
                1
            )

            -- outer
            add_vertex(glow_data,
                glow_x + dx * radius_c,
                glow_y + dy * radius_c,
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

    stage.air_dash_node_manager:notify_node_added(self)
end

--- @brief
function ow.AirDashNode:set_is_tethered(b, path)
    local before = self._is_tethered
    self._is_tethered = b

    if b == false then
        self._cooldown_elapsed = 0
    end

    self._is_current_motion:set_target_value(ternary(b, 1, 0))

    if before == false and b == true then
        self._particle:set_is_exploded(true)
    elseif before == true and b == false then
        self._particle:set_is_exploded(false)
    end

    self._tether_path = path

    if self._has_direction then
        self._tether_dx, self._tether_dy = self._direction_x, self._direction_y
    else
        local px, py = self._scene:get_player():get_position()
        local x, y = self._body:get_position()
        self._tether_dx, self._tether_dy = math.normalize(px - x, py - y)
    end
end

--- @brief
function ow.AirDashNode:set_is_current(b)
    self._is_current = b

    if b == true then
        -- skip animation
        self._is_current_motion:set_value(1)
    end

    if self._has_direction then
        self._particle:set_aligned(b, self._direction_x, self._direction_y, 0)
    else
        local x, y = self._body:get_position()
        local px, py = self._scene:get_player():get_position()
        local dx, dy = math.normalize(px - x, py - y)
        self._particle:set_aligned(b, dx, dy, 0)
    end
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
    if self._is_handler_proxy == true then self._stage.air_dash_node_manager:update(delta) end

    if not self._is_tethered then
        self._cooldown_elapsed = self._cooldown_elapsed + delta
    end

    if self._stage:get_is_body_visible(self._body) then
        self._is_current_motion:update(delta)
        self._is_tethered_motion:update(delta)
        self._particle:update(delta)

        if self._has_direction then
            self._particle:set_use_axis(true, self._direction_x, self._direction_y, 0)
        else
            --[[
            local x, y = self._body:get_position()
            local px, py = self._scene:get_player():get_position()
            local dx, dy = math.normalize(px - x, py - y)
            self._particle:set_use_axis(false, dx, dy)
            ]]
        end

        self._particles:update(delta)
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

    local cooldown_t = self._cooldown_elapsed / rt.settings.overworld.air_dash_node.cooldown

    local line_width = rt.settings.overworld.air_dash_node.solid_outline_line_width
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(line_width)

    if priority == _behind_player_priority then

        love.graphics.push()
        love.graphics.translate(offset_x, offset_y)

        local current_a = self._is_current_motion:get_value()
        local cooldown_a = 1 - math.min(1, self._cooldown_elapsed / rt.settings.overworld.air_dash_node.cooldown)
        local opacity = math.max(
            current_a,
            cooldown_a,
            rt.settings.overworld.air_dash_node.min_opacity
        )

        if self._indicator_always_visible then opacity = 1 end

        if cooldown_t >= 1 then
            local alpha = rt.settings.overworld.air_dash_node.solid_outline_alpha * self._is_current_motion:get_value()
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.line(self._circle_vertices)
        end

        if opacity > 0.01 then
            love.graphics.setColor(1, 1, 1, 1)
            _glow_shader:bind()
            _glow_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
            _glow_shader:send("color", { r, g, b, opacity })
            _glow_shader:send("noise_texture", _noise_texture)
            self._glow_mesh:draw()
            _glow_shader:unbind()
        end

        if self._is_current == false then
            love.graphics.setColor(r, g, b, 1)
            self._particle:draw(0, 0, true, true)
        end

        love.graphics.pop()

        self._particles:draw()

    elseif priority == _in_front_of_payer_priority then

        love.graphics.push()
        love.graphics.translate(offset_x, offset_y)

        love.graphics.setColor(r, g, b, 1)

        if self._is_current == true then
            self._particle:draw(0, 0, true, true)
        end

        local x, y = 0, 0
        local dx, dy
        if self._has_direction then
            dx, dy = self._direction_x, self._direction_y
        else
            local px, py = self._scene:get_player():get_position()
            dx, dy = math.normalize(px - offset_x, py - offset_y)
        end

        local ax, ay = x - dx * self._radius, y - dy * self._radius
        local bx, by = x + dx * self._radius, y + dy * self._radius

        local alpha = self._is_current_motion:get_value() - (1 - math.min(1, cooldown_t))

        love.graphics.setColor(r, g, b, 0.5 * alpha)
        love.graphics.line(self._circle_vertices)

        if self._indicator_always_visible == true then alpha = 0.5 end
        love.graphics.setColor(r, g, b, alpha)

        local angle = math.angle(dx, dy)
        local arc_radius = 0.5 * line_width
        love.graphics.arc("fill", "closed", ax, ay, arc_radius, angle + math.pi / 2, angle + 3 * math.pi / 2)
        love.graphics.arc("fill", "closed", bx, by, arc_radius, angle - math.pi / 2, angle + math.pi / 2)

        love.graphics.line(ax, ay, bx, by)

        love.graphics.pop()

        self._particles:draw()
    end
end

--- @brief
function ow.AirDashNode:draw_bloom()
    if self._stage:get_is_body_visible(self._body) == false then return end

    love.graphics.push()
    local offset_x, offset_y = self._body:get_position()
    love.graphics.translate(offset_x, offset_y)

    local r, g, b = self._color:unpack()
    love.graphics.setColor(r, g, b, 1)
    self._particle:draw(0, 0, false, true) -- line only

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
function ow.AirDashNode:collect_point_lights(callback)
    local x, y = self._body:get_position()
    local r, g, b, a = self._color:unpack()
    local radius = self._radius
    callback(x, y, radius, r, g, b, a)
end

--- @brief
function ow.AirDashNode:get_is_directional()
    return self._has_direction
end

--- @brief
function ow.AirDashNode:emit_particles(path)
    local vx, vy = self._scene:get_player():get_position()
    self._particles:emit(path, vx, vy, self._color:unpack())
end
