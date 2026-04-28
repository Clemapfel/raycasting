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
    local angle = object:get_object("angle", false)

    if angle ~= nil and direction == nil then
        rt.assert(false, "In ow.DirectionalAirDashNode: `angle` specified but not `direction` property pointing to an `AirDashNodeDirection` point is present")
    end

    if angle == nil then
        angle = 0.5 * math.pi
    else
        rt.assert(angle >= 0 and angle <= 1, "In ow.DirectionalAirDashNode: `angle` property should be a number in [0, 1], got `", angle, "`")
        angle = angle * 0.5 * math.pi
    end

    local mid = 0 or math.angle(direction.x - object.x, direction.y - object.y)
    self._angle_ranges = {
        {
            mid - 0.5 * angle,
            mid + 0.5 * angle
        },
        {
            mid - math.pi - 0.5 * angle,
            mid - math.pi + 0.5 * angle
        }
    }

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

    self._outline_vertices = {}
    local n_vertices = rt.Mesh.radius_to_n_vertices(self._radius, self._radius)


    self._outline_vertices = {}

    local function push(x, y)
        table.insert(self._outline_vertices, x)
        table.insert(self._outline_vertices, y)
    end

    for s, range in ipairs(self._angle_ranges) do
        local range_start, range_end = range[1], range[2]
        local arc_span = range_end - range_start
        local n_arc_vertices = math.max(2, math.ceil(n_vertices * math.abs(arc_span) / (2 * math.pi)))

        for i = 1, n_arc_vertices + 1 do
            local a = range_start + ((i - 1) / n_arc_vertices) * arc_span
            push(math.cos(a) * self._radius, math.sin(a) * self._radius)
        end

        push(0, 0)

        local next_range = self._angle_ranges[(s % #self._angle_ranges) + 1]
        local next_start = next_range[1]
        push(math.cos(next_start) * self._radius, math.sin(next_start) * self._radius)
    end

    do
        local glow_aliasing_width = rt.settings.overworld.air_dash_node.glow_aliasing_width
        local radius_inner = 2 * rt.settings.overworld.air_dash_node.core_radius
        local radius_mid = self._radius
        local radius_outer = self._radius + glow_aliasing_width

        local glow_data = {}
        local glow_vertex_map = {}

        local function add_vertex(x, y, u, v, arc_length, density, opacity)
            table.insert(glow_data, {
                x, y,
                u, v,
                density,
                arc_length,
                opacity,
                1
            })
        end

        local cx, cy = 0, 0

        -- vertex 1: center
        add_vertex(cx, cy, 0, 0, 0, 1, 1)

        -- for each angle range, emit arc vertices and radial border quads
        -- sector_vertex_ranges[s] = { first_index, count } into glow_data (1-based)
        local sector_first = {}

        for _, range in ipairs(self._angle_ranges) do
            local range_start, range_end = range[1], range[2]
            local arc_span = range_end - range_start

            -- number of arc steps proportional to arc length
            local n_arc = math.max(2, math.ceil(n_vertices * math.abs(arc_span) / (2 * math.pi)))

            local first_index = #glow_data + 1
            table.insert(sector_first, { first = first_index, count = n_arc + 1 })

            for i = 1, n_arc + 1 do
                local t = (i - 1) / n_arc
                local arc_angle = range_start + t * arc_span
                local dx, dy = math.cos(arc_angle), math.sin(arc_angle)
                local arc_length = t  -- normalized 0..1 along this sector's arc

                add_vertex(cx + dx * radius_inner, cy + dy * radius_inner, dx, dy, arc_length, 1, 0)
                add_vertex(cx + dx * radius_mid,   cy + dy * radius_mid,   dx, dy, arc_length, 1, 1)
                add_vertex(cx + dx * radius_outer, cy + dy * radius_outer, dx, dy, 1 - arc_length, 0, 0)
            end

            -- center fan and arc ring triangles
            for i = 1, n_arc do
                local base = first_index + (i - 1) * 3
                local next_base = first_index + i * 3

                local inner_a  = base
                local mid_a    = base + 1
                local inner_b  = next_base
                local mid_b    = next_base + 1

                -- center to inner arc fan
                table.insert(glow_vertex_map, 1)
                table.insert(glow_vertex_map, inner_a)
                table.insert(glow_vertex_map, inner_b)

                -- inner to mid ring
                table.insert(glow_vertex_map, inner_a)
                table.insert(glow_vertex_map, mid_a)
                table.insert(glow_vertex_map, mid_b)

                table.insert(glow_vertex_map, inner_a)
                table.insert(glow_vertex_map, mid_b)
                table.insert(glow_vertex_map, inner_b)

                -- mid to outer ring
                local outer_a = base + 2
                local outer_b = next_base + 2

                table.insert(glow_vertex_map, mid_a)
                table.insert(glow_vertex_map, outer_a)
                table.insert(glow_vertex_map, outer_b)

                table.insert(glow_vertex_map, mid_a)
                table.insert(glow_vertex_map, outer_b)
                table.insert(glow_vertex_map, mid_b)
            end

            -- radial border quads along the two straight edges of the sector
            -- each edge runs from center outward; we emit inner→mid and mid→outer quads
            -- UV arc_length is 0 on the boundary (matching arc endpoint t=0 and t=1)
            -- the quad is degenerate in angle but the shader samples by arc_length + density

            -- start edge (t=0, i=1): vertices at first_index+0,+1,+2
            -- end edge   (t=1, i=n_arc+1): vertices at first_index + n_arc*3 + 0,+1,+2
            -- for each edge we need center→inner→mid→outer as a strip
            -- we build two quads: (center, inner_edge_start, inner_edge_end, ... )
            -- but the straight edges are degenerate (zero width), so we extrude by
            -- glow_aliasing_width perpendicular to the radial direction

            -- edge_start: angle = range_start, edge_end: angle = range_end
            for edge_index, edge_t in ipairs({ 0, 1 }) do
                local edge_angle = range_start + edge_t * arc_span
                local dx, dy = math.cos(edge_angle), math.sin(edge_angle)
                -- perpendicular (pointing inward to sector for both edges)
                -- for edge_t=0: perp is +90deg (rotate CCW), for edge_t=1: perp is -90deg
                local sign = (edge_index == 1) and 1 or -1
                local px, py = -dy * sign, dx * sign

                local edge_arc_length = edge_t

                -- four vertices forming the quad: two along radial, extruded by aliasing width perpendicularly
                local v_inner_on  = #glow_data + 1
                add_vertex(cx + dx * radius_inner,  cy + dy * radius_inner,  dx, dy, edge_arc_length, 1, 0)
                local v_inner_off = #glow_data + 1
                add_vertex(cx + dx * radius_inner + px * glow_aliasing_width,
                    cy + dy * radius_inner + py * glow_aliasing_width,
                    dx, dy, edge_arc_length, 0, 0)

                local v_mid_on  = #glow_data + 1
                add_vertex(cx + dx * radius_mid,  cy + dy * radius_mid,  dx, dy, edge_arc_length, 1, 1)
                local v_mid_off = #glow_data + 1
                add_vertex(cx + dx * radius_mid + px * glow_aliasing_width,
                    cy + dy * radius_mid + py * glow_aliasing_width,
                    dx, dy, edge_arc_length, 0, 1)

                local v_outer_on  = #glow_data + 1
                add_vertex(cx + dx * radius_outer,  cy + dy * radius_outer,  dx, dy, edge_arc_length, 0, 0)
                local v_outer_off = #glow_data + 1
                add_vertex(cx + dx * radius_outer + px * glow_aliasing_width,
                    cy + dy * radius_outer + py * glow_aliasing_width,
                    dx, dy, edge_arc_length, 0, 0)

                -- center to inner radial quad
                table.insert(glow_vertex_map, 1)
                table.insert(glow_vertex_map, v_inner_on)
                table.insert(glow_vertex_map, v_inner_off)

                -- inner to mid quad
                table.insert(glow_vertex_map, v_inner_on)
                table.insert(glow_vertex_map, v_mid_on)
                table.insert(glow_vertex_map, v_mid_off)

                table.insert(glow_vertex_map, v_inner_on)
                table.insert(glow_vertex_map, v_mid_off)
                table.insert(glow_vertex_map, v_inner_off)

                -- mid to outer quad
                table.insert(glow_vertex_map, v_mid_on)
                table.insert(glow_vertex_map, v_outer_on)
                table.insert(glow_vertex_map, v_outer_off)

                table.insert(glow_vertex_map, v_mid_on)
                table.insert(glow_vertex_map, v_outer_off)
                table.insert(glow_vertex_map, v_mid_off)
            end
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
            love.graphics.line(self._outline_vertices)
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
        local dx, dy = self:get_direction()

        local ax, ay = x - dx * self._radius, y - dy * self._radius
        local bx, by = x + dx * self._radius, y + dy * self._radius

        local alpha = self._is_current_motion:get_value() - (1 - math.min(1, cooldown_t))

        love.graphics.setColor(r, g, b, 0.5 * alpha)
        love.graphics.line(self._outline_vertices)

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
function ow.AirDashNode:get_direction()
    local dx, dy = 0, 0
    local x, y = self._body:get_position()
    if self._has_direction then
        dx, dy = self._direction_x, self._direction_y
    else
        local px, py = self._scene:get_player():get_position()
        dx, dy = math.normalize(px - x, py - y)
    end

    return dx, dy
end

--- @brief
function ow.AirDashNode:emit_particles(path)
    local vx, vy = self._scene:get_player():get_position()
    self._particles:emit(path, vx, vy, self._color:unpack())
end
