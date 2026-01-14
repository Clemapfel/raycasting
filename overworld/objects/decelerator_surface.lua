require "overworld.deformable_mesh"
require "overworld.movable_object"

rt.settings.overworld.decelerator_surface = {
    friction = 1.15,
    subdivision_length = 4,

    max_penetration = rt.settings.player.radius * 0.25
}

--- @class ow.DeceleratorSurface
ow.DeceleratorSurface = meta.class("DeceleratorSurface", ow.MovableObject)

local padding = 20
local _shader = rt.Shader("overworld/objects/decelerator_surface.glsl")

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then _shader:recompile() end
end)

--- @brief
function ow.DeceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("slippery")

    self._body:set_collision_group(rt.settings.player.bounce_collision_group)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)

    local directions = { rt.Direction.LEFT, rt.Direction.RIGHT, rt.Direction.UP, rt.Direction.DOWN }
    self._body:signal_connect("collision_start", function(_, other_body)
        for direction in values(directions) do
            local player = self._scene:get_player()
            player:set_directional_damping(direction, 1 / rt.settings.overworld.decelerator_surface.friction)
        end
    end)

    self._body:signal_connect("collision_end", function(_, other_body)
        for direction in values(directions) do
            local player = self._scene:get_player()
            player:set_directional_damping(direction, 1)
        end
    end)

    local contour = object:create_contour()
    local centroid_x, centroid_y = self._body:get_position()
    for i = 1, #contour, 2 do
        contour[i+0] = contour[i+0] - centroid_x
        contour[i+1] = contour[i+1] - centroid_y
    end

    self._tris = {}
    if rt.contour.is_convex(contour) then
        self._tris = { contour }
    else
        self._tris = object:triangulate()
    end

    self._contour = rt.contour.close(rt.contour.subdivide(
        contour,
        rt.settings.overworld.decelerator_surface.subdivision_length
    ))

    self._draw_contour = table.deepcopy(self._contour)
    self._contour_normals = rt.contour.get_normals(self._contour)
    self._contour_amplitudes = table.deepcopy(self._contour)

    self._stage:signal_connect("initialized", function(_)
        local offset_x, offset_y = self._body:get_position()
        for i = 1, #self._contour_normals, 2 do
            local x, y = self._contour[i] + offset_x, self._contour[i+1] + offset_y
            local dx, dy = self._contour_normals[i], self._contour_normals[i+1]
            x = x + dx * padding
            y = y + dy * padding

            local bodies = stage:get_physics_world():query_aabb(x - 1, y - 1, 2, 2)

            local occupied = false
            for body in values(bodies) do
                if meta.hash(body) ~= meta.hash(self._body) then
                    occupied = true
                    break
                end
            end

            if occupied then
                self._contour_normals[i+0], self._contour_normals[i+1] = 0, 0
            end
        end

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local sdf = function(x, y, px, py, radius)
        if x < px then x = px - math.abs(px - x) end
        if y < py then y = py - math.abs(py - y) end

        local r = 4 * 12
        local dist = math.distance(x, y, px, py)
        local t = dist / r
        local t_scaled = t * 2
        local base_value = (1 - t_scaled * t_scaled) * math.exp(-t_scaled * t_scaled / 2) * 3

        -- Add 2D sine wave pattern based on absolute position
        local sine_start = r * 0.2
        local sine_peak = r * 1
        local sine_end = r * 3.0
        local offset = rt.SceneManager:get_elapsed() * 3

        local offset_envelope = math.min(t^2, 1)
        offset = offset * ternary(x < px, -1, 1)

        local value = base_value

        if dist > sine_start then
            local frequency = 1 / 5
            local sine_wave = math.sin(x * frequency + offset) * math.cos(y * frequency)

            local ramp_up = math.min(1, (dist - sine_start) / (sine_peak - sine_start))
            local decay = math.exp(-(dist - sine_peak) / (sine_end - sine_peak))
            local envelope = ramp_up * decay

            local sine_amplitude = envelope * (1 - 1 + offset_envelope)
            sine_wave = (sine_wave + 1) / 2

            local sine_r = 0.5 * radius
            local sine_t = math.clamp(math.min(math.abs(x - px) / sine_r, math.abs(y - py) / sine_r), 0, 1)
            value = 0.5 * (value + 1) + sine_wave * sine_amplitude * math.min(sine_t, offset_envelope) --value + (1 - value) * 0.5 * sine_wave * sine_amplitude
        end

        return value / 2
    end

    local player = self._scene:get_player()
    local offset_x, offset_y = self._body:get_position()
    local px, py = player:get_position()
    local radius = player:get_radius()

    self._buldge = {}
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i] + offset_x, self._contour[i+1] + offset_y
        local dx, dy = self._contour_normals[i], self._contour_normals[i+1]
        if dx ~= 0 or dy ~= 0 then
            local depression = sdf(x, y, px, py, radius)
            local cx = x + dx * depression * padding
            local cy = y + dy * depression * padding

            if depression > 0 then
                table.insert(self._buldge, { x, y, cx, cy })
            end

            self._draw_contour[i+0] = cx
            self._draw_contour[i+1] = cy
        end
    end

    if #self._draw_contour < #self._contour + 2 then
        table.insert(self._draw_contour, self._draw_contour[1])
        table.insert(self._draw_contour, self._draw_contour[2])
    else
        self._draw_contour[#self._draw_contour-1] = self._draw_contour[1]
        self._draw_contour[#self._draw_contour-0] = self._draw_contour[2]
    end
end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()

    local transform = self._scene:get_camera():get_transform()
    transform:translate(offset_x, offset_y)
    transform = transform:inverse()

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("screen_to_world_transform", transform)

    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    rt.Palette.DECELERATOR_SURFACE:bind()
    for tri in values(self._tris) do
        love.graphics.polygon("fill", tri)
    end

    love.graphics.pop()

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(rt.settings.overworld.decelerator_surface.subdivision_length)
    for line in values(self._buldge) do
        love.graphics.line(line)
    end
    love.graphics.setLineStyle("smooth")

    _shader:unbind()

    local line_width = 1.5
    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width + 1.5)
    --love.graphics.line(self._contour)

    rt.Palette.DECELERATOR_SURFACE_OUTLINE:bind()
    love.graphics.setLineWidth(line_width)
    love.graphics.line(self._draw_contour)

    self._body:draw()
end

--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return 2
end
