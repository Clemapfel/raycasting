rt.settings.overworld.bubble = {
    respawn_duration = 4,
    line_width = 1,
    outline_width = 0.5, -- black outline
    max_motion_offset = 5,
    motion_velocity = 3.5, -- px / s
    motion_n_path_nodes = 10
}

--- @class ow.Bubble
ow.Bubble = meta.class("Bubble")

local _shader = rt.Shader("overworld/objects/bubble.glsl")

local _hue = 0
local _n_hue_steps = 12

function ow.Bubble:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE, "In ow.Bubble: object is not an ellipse")

    self._scene = scene
    self._stage = stage

    self._x, self._y = object:get_centroid()
    self._x_radius, self._y_radius = object.x_radius, object.y_radius

    self._is_destroyed = false
    self._respawn_elapsed = math.huge
    self._pop_fraction = 1

    -- physics

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("slippery", "no_blood", "unjumpable")
    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        if self._is_destroyed or cx == nil then return end -- popped, or player is sensor

        -- use exact normal, since body is always an ellipse
        local player = self._scene:get_player()
        local px, py = player:get_position()
        local dx, dy = px - self._x, py - self._y
        local restitution = player:bounce(math.normalize(dx, dy))

        self:_pop()

        if cx ~= nil and cy ~= nil then
            local angle = math.angle(cx - self._x, cy - self._y)
            self._pop_origin_x = math.cos(angle)
            self._pop_origin_y = math.sin(angle)
        end
    end)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._body:add_tag("light_source")
    self._body:set_user_data(self)

    self._stage:signal_connect("respawn", function()
        self:_unpop()
    end)

    -- graphics

    local hue = math.fract(_hue / _n_hue_steps)
    _hue = _hue + 1
    self._hue = hue
    self._color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }

    self._contour = {}
    self._outline_contour = {}

    local line_width = rt.settings.overworld.bubble.line_width
    local outline_width = rt.settings.overworld.bubble.outline_width

    local data = {
        { self._x, self._y, 0, 0, 1, 1, 1, 1 }
    }

    local n_outer_vertices = 64

    for i = 1, n_outer_vertices + 1 do
        local angle = (i - 1) / n_outer_vertices * 2 * math.pi
        local x = self._x + math.cos(angle) * self._x_radius
        local y = self._y + math.sin(angle) * self._y_radius

        local u = math.cos(angle)
        local v = math.sin(angle)

        table.insert(data, {
            x, y,
            math.cos(angle),
            math.sin(angle),
            1, 1, 1, 1
        })

        table.insert(self._contour, x)
        table.insert(self._contour, y)

        local outline_x = self._x + math.cos(angle) * (self._x_radius + 0.5 * line_width + 0.5 * outline_width)
        local outline_y = self._y + math.sin(angle) * (self._y_radius + 0.5 * line_width + 0.5 * outline_width)

        table.insert(self._outline_contour, outline_x)
        table.insert(self._outline_contour, outline_y)
    end

    self._mesh = rt.Mesh(data)

    -- random motion
    local max_offset = rt.settings.overworld.bubble.max_motion_offset

    local points = {}
    for i = 1, rt.settings.overworld.bubble.motion_n_path_nodes do
        table.insert(points, rt.random.number(-0.5 * max_offset, 0.5 * max_offset))
        table.insert(points, rt.random.number(-max_offset, max_offset))
    end
    table.insert(points, points[1])
    table.insert(points, points[2])

    self._path = rt.Spline(points)
    self._path_elapsed = 0
    self._path_duration = self._path:get_length() / rt.settings.overworld.bubble.motion_velocity
end

--- @brief
function ow.Bubble:_pop()
    self._is_destroyed = true
    self._respawn_elapsed = 0
    self._body:set_is_sensor(true)
end

--- @brief
function ow.Bubble:_unpop()
    self._is_destroyed = false
    self._body:set_is_sensor(false)
end

--- @brief
function ow.Bubble:update(delta)
    local respawn_duration = rt.settings.overworld.bubble.respawn_duration

    if self._is_destroyed then
        self._respawn_elapsed = self._respawn_elapsed + delta
        if self._respawn_elapsed >= respawn_duration and not self._body:test_point(self._scene:get_player():get_position()) then
            self:_unpop()
            return
        end
    end

    if not self._stage:get_is_body_visible(self._body) then return end

    local x = math.clamp(self._respawn_elapsed / respawn_duration, 0, 1)
    self._pop_fraction = math.pow(x, 40) -- manually chosen easing

    if not self._is_destroyed then
        -- freeze while respawning
        self._path_elapsed = self._path_elapsed + delta
    end
end

--- @brief
function ow.Bubble:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._path:at(math.fract(self._path_elapsed / self._path_duration)))

    -- outline always visible so player know where bubble will respawn
    local opacity = 1 * math.max(0.5, self._pop_fraction)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    local r, g, b = rt.Palette.BLACK:unpack()
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(rt.settings.overworld.bubble.outline_width)
    love.graphics.line(self._outline_contour)

    r, g, b = table.unpack(self._color)
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(rt.settings.overworld.bubble.line_width)
    love.graphics.line(self._contour)

    -- player position in normalized uv space relative to center
    local px, py = self._scene:get_player():get_position()
    local dx, dy = (self._x - px) / self._x_radius, (self._y - py) / self._y_radius

    _shader:bind()
    _shader:send("player_position", { dx, dy })
    _shader:send("player_color", self._color)
    _shader:send("pop_fraction", self._pop_fraction)
    self._mesh:draw()
    _shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.Bubble:draw_bloom()
    if self._is_destroyed or not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._path:at(math.fract(self._path_elapsed / self._path_duration)))

    local line_width = rt.settings.overworld.bubble.line_width
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    local r, g, b = table.unpack(self._color)
    local opacity = 0.5 * self._pop_fraction
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(line_width - 2)
    love.graphics.line(self._contour)

    love.graphics.pop()
end

--- @brief
function ow.Bubble:get_color()
    if self._is_destroyed then
        return rt.RGBA(1, 1, 1, 0)
    else
        return rt.RGBA(table.unpack(self._color))
    end
end

--- @brief
function ow.Bubble:reset()
    self:_unpop()
end