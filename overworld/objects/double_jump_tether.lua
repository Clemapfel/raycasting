require "overworld.double_jump_particle"

rt.settings.overworld.double_jump_tether = {
    radius_factor = 1.5
}

--- @class DoubleJumpTether
ow.DoubleJumpTether = meta.class("DoubleJumpThether")

local _shader

local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

local eps = 0.01

--- @brief
function ow.DoubleJumpTether:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.DoubleJumpTether: tiled object is not a point")

    self._x, self._y, self._radius = object.x, object.y, rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )
    self._scene = scene
    self._stage = stage

    -- collision
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    self._body:add_tag("light_source")
    self._body:set_user_data(self)

    self._is_consumed = false
    self._was_consumed = false
    self._was_attached = false
    self._body:signal_connect("collision_start", function(_)
        local player = self._scene:get_player()
        if not self._is_consumed and not player:get_is_double_jump_source(self) then
            player:add_double_jump_source(self)
            self._is_consumed = true
            self:update(0)

            player:signal_connect("grounded", function()
                self._is_consumed = false
                return meta.DISCONNECT_SIGNAL
            end)
        end
    end)

    -- graphics
    self._color = { rt.lcha_to_rgba(0.8, 1, _hue_steps[_current_hue_step], 1) }
    _current_hue_step = _current_hue_step % _n_hue_steps + 1
    self._particle = ow.DoubleJumpParticle(self._radius)
    self._line_opacity_motion = rt.SmoothedMotion1D(0, 3.5)
    self._shape_opacity_motion = rt.SmoothedMotion1D(1, 2)
end

--- @brief
function ow.DoubleJumpTether:update(delta)
    local is_attached = self._scene:get_player():get_is_double_jump_source(self)
    local is_visible = self._stage:get_is_body_visible(self._body)

    self._line_opacity_motion:update(delta)

    -- show / hide particle when consumed
    if self._is_consumed == true and self._was_consumed == false then
        self._shape_opacity_motion:set_target_value(0)
    elseif self._is_consumed == false and self._was_consumed == true then
        self._shape_opacity_motion:set_target_value(1)
    end
    self._was_consumed = self._is_consumed

    -- show / hide line when attached
    if is_attached == true and self._was_attached == false then
        self._line_opacity_motion:set_target_value(1)
    elseif is_attached == false and self._was_attached == true then
        self._line_opacity_motion:set_target_value(0)
    end
    self._was_attached = is_attached

    if is_visible then
        self._particle:update(delta)
        self._shape_opacity_motion:update(delta)
    end

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
function ow.DoubleJumpTether:get_render_priority()
    return math.huge -- in front of player
end

--- @brief
function ow.DoubleJumpTether:draw()
    local line_a = self._line_opacity_motion:get_value()
    if line_a > eps and self._line_mesh ~= nil then
        love.graphics.setBlendMode("alpha")
        local r, g, b = table.unpack(self._color)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.draw(self._line_mesh)
    end

    if self._stage:get_is_body_visible(self._body) then
        local shape_a = self._shape_opacity_motion:get_value()
        local r, g, b = table.unpack(self._color)

        -- always draw core, fade out line
        love.graphics.setColor(r, g, b, 1)
        self._particle:draw(self._x, self._y, false, true) -- core only

        if shape_a > eps then
            love.graphics.setColor(r, g, b, shape_a)
            self._particle:draw(self._x, self._y, true, true) -- both
        end
    end
end

--- @brief
function ow.DoubleJumpTether:draw_bloom()
    if self._stage:get_is_body_visible(self._body) == false then return end
    local r, g, b = table.unpack(self._color)
    local shape_a = self._shape_opacity_motion:get_value()
    if shape_a > eps then
        love.graphics.setColor(r, g, b, shape_a)
        self._particle:draw(self._x, self._y, false, true) -- line only
    end
end

--- @brief
function ow.DoubleJumpTether:get_color()
    return rt.RGBA(table.unpack(self._color))
end
