rt.settings.overworld.bubble = {
    default_respawn_duration = 4,
    line_width = 3, -- only used for bloom
    max_motion_offset = 5,
    velocity = 3.5, -- px / s
    pop_duration = 1
}

--- @class ow.Bubble
ow.Bubble = meta.class("Bubble")

local _shader = rt.Shader("overworld/objects/bubble.glsl")

local _hue = 0
local _n_hue_steps = 12

local todo = true

--- @brief
function ow.Bubble:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE, "In ow.Bubble: object is not an ellipse")

    if todo then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "o" then _shader:recompile() end
        end)
        todo = false
    end

    self._scene = scene
    self._stage = stage

    self._respawn_elapsed = math.huge
    self._respawn_duration = object:get_number("respawn_duration", false) or rt.settings.overworld.bubble.default_respawn_duration
    self._is_destroyed = false

    local hue = math.fract(_hue / _n_hue_steps)
    _hue = _hue + 1
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, hue, 1))

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("slippery", "no_blood", "unjumpable", "stencil")
    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        if self._is_destroyed or cx == nil then return end -- popped, or player is sensor

        local player = self._scene:get_player()
        local restitution = player:bounce(nx, ny)

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

    self._stage:signal_connect("respawn", function()
        self:_unpop()
    end)

    -- motion
    local max_offset = rt.settings.overworld.bubble.max_motion_offset

    local points = {}
    for i = 1, 100 do
        table.insert(points, rt.random.number(-0.5 * max_offset, 0.5 * max_offset))
        table.insert(points, rt.random.number(-max_offset, max_offset))
    end
    table.insert(points, points[1])
    table.insert(points, points[2])

    self._path = rt.Spline(points)
    self._path_elapsed = 0
    self._path_duration = self._path:get_length() / rt.settings.overworld.bubble.velocity

    -- graphics
    self._x, self._y = object:get_centroid()
    self._x_radius, self._y_radius = object.x_radius, object.y_radius

    self._contour = {}
    local data = {
        { self._x, self._y, 0, 0, 1, 1, 1, 1 }
    }

    local n_outer_vertices = 64
    for i = 1, n_outer_vertices + 1 do
        local angle = (i - 1) / n_outer_vertices * 2 * math.pi
        local x = self._x + math.cos(angle) * self._x_radius
        local y = self._y + math.sin(angle) * self._y_radius

        table.insert(data, {
            x, y,
            math.cos(angle),
            math.sin(angle),
            1, 1, 1, 1
        })

        table.insert(self._contour, x)
        table.insert(self._contour, y)
    end

    self._mesh = rt.Mesh(data)

    self._pop_origin_x = 0
    self._pop_origin_y = 0
    self._pop_elapsed = 10e5 -- math.huge
    self._pop_duration = rt.settings.overworld.bubble.pop_duration
end

--- @brief
function ow.Bubble:_pop()
    self._is_destroyed = true
    self._respawn_elapsed = 0
    self._pop_elapsed = 0
    self._body:set_is_sensor(true)
end

--- @brief
function ow.Bubble:_unpop()
    self._is_destroyed = false
    self._body:set_is_sensor(false)
end

--- @brief
function ow.Bubble:update(delta)
    if self._is_destroyed then
        self._respawn_elapsed = self._respawn_elapsed + delta
        if self._respawn_elapsed >= self._respawn_duration and not self._body:test_point(self._scene:get_player():get_position()) then
            self:_unpop()
        end
    else
        self._path_elapsed = self._path_elapsed + delta
    end

    self._pop_elapsed = self._pop_elapsed + delta
end

--- @brief
function ow.Bubble:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    love.graphics.translate(self._path:at(math.fract(self._path_elapsed / self._path_duration)))

    local opacity = 1

    local r, g, b = self._color:unpack()
    love.graphics.setColor(r, g, b, opacity)

    _shader:bind()
    _shader:send("pop_fraction", math.clamp(self._pop_elapsed / self._pop_duration, 0, 1))
    self._mesh:draw()
    _shader:unbind()

    love.graphics.pop()

    -- if no bloom, outline can't be shown after pop
    if self._is_destroyed and rt.GameState:get_is_bloom_enabled() == false then
        love.graphics.push()
        love.graphics.translate(self._path:at(math.fract(self._path_elapsed / self._path_duration)))

        local opacity = 0.3
        local line_width = rt.settings.overworld.bubble.line_width
        love.graphics.setLineWidth(line_width)
        love.graphics.setLineStyle("smooth")
        love.graphics.setLineJoin("bevel")

        local r, g, b = self._color:unpack()
        love.graphics.setColor(r, g, b, opacity)
        love.graphics.setLineWidth(line_width - 2)
        love.graphics.line(self._contour)

        love.graphics.pop()
    end
end

--- @brief
function ow.Bubble:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    -- should stay visible even if popped

    love.graphics.push()
    love.graphics.translate(self._path:at(math.fract(self._path_elapsed / self._path_duration)))

    local opacity = 1
    local line_width = rt.settings.overworld.bubble.line_width
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    local r, g, b = self._color:unpack()
    love.graphics.setColor(r, g, b, opacity)
    love.graphics.setLineWidth(line_width - 2)
    love.graphics.line(self._contour)

    love.graphics.pop()
end