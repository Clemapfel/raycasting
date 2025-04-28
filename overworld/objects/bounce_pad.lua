rt.settings.overworld.bounce_pad = {
    -- bounce animation
    bounce_max_offset = rt.settings.overworld.player.radius * 0.5, -- in px
    color_decay_duration = 1,

    -- bounce animation simulation parameters
    stiffness = 10,
    damping = 0.95,
    origin = 0,
    magnitude = 100,
}

--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    --assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.BouncePad.instantiate: object " .. object.id .. " is not a rectangle")

    meta.install(self, {
        _scene = scene,
        _body = object:create_physics_body(stage:get_physics_world()),

        -- animation
        _vertices = {},
        _angle = object.rotation,
        _x = object.x,
        _y = object.y,
        _width = object.width,
        _height = object.height,
        _rotation_origin_x = object.origin_x,
        _rotation_origin_y = object.origin_y,
        _bounce_contact_x = 0,
        _bounce_contact_y = 0,

        _draw_x = object.x,
        _draw_y = object.y,
        _draw_width = object.width,
        _draw_height = object.height,

        _bounce_position = rt.settings.overworld.bounce_pad.origin, -- in [0, 1]
        _bounce_velocity = 0,
        _is_bouncing = true,
        _color_elapsed = math.huge,

        _default_color = { rt.Palette.BOUNCE_PAD:unpack() }
    })
    self._color = self._default_color
    self._draw_color = self._color

    self:_update_vertices()

    self._body:add_tag("slippery", "no_blood", "unjumpable")

    local bounce_group = rt.settings.overworld.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        local player = self._scene:get_player()
        local restitution = player:bounce(nx, ny)

        -- animation
        self._color = { rt.lcha_to_rgba(0.9, 1, player:get_hue(), 1) }
        self._color_elapsed = 0

        self._bounce_velocity = restitution
        self._bounce_position = restitution
        self._bounce_contact_x, self._bounce_contact_y = cx, cy
        self._is_bouncing = true
    end)
end

local offset = rt.settings.overworld.bounce_pad.bounce_max_offset

-- get distance between point and segment
function _point_to_segment_distance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length_sq = dx * dx + dy * dy

    local t = ((px - x1) * dx + (py - y1) * dy) / length_sq
    t = math.max(0, math.min(1, t))

    local nearest_x = x1 + t * dx
    local nearest_y = y1 + t * dy

    local dist_x = px - nearest_x
    local dist_y = py - nearest_y
    return math.sqrt(dist_x * dist_x + dist_y * dist_y) --, nearest_x, nearest_y
end

--- @brief
function ow.BouncePad:_update_vertices()
    local x, y, w, h = self._x, self._y, self._width, self._height
    local angle = self._angle
    local ox, oy = self._rotation_origin_x, self._rotation_origin_y
    local contact_x, contact_y = self._bounce_contact_x, self._bounce_contact_y

    local vertices = {
        [1] = { math.rotate(x,     y,     angle, ox, oy) }, -- top left
        [2] = { math.rotate(x + w, y,     angle, ox, oy) }, -- top right
        [3] = { math.rotate(x + w, y + h, angle, ox, oy) }, -- bottom right
        [4] = { math.rotate(x,     y + h, angle, ox, oy) }, -- bottom left
    }

    -- find closest side to contact point
    local segments = {
        {1, 2},
        {2, 3},
        {3, 4},
        {4, 1}
    }

    -- sort segments by distance to contact point
    for segment in values(segments) do
        local x1, y1 = table.unpack(vertices[segment[1]])
        local x2, y2 = table.unpack(vertices[segment[2]])
        segment[3] = _point_to_segment_distance(contact_x, contact_y, x1, y1, x2, y2)
    end

    table.sort(segments, function(a, b)
        return a[3] < b[3]
    end)

    local closest_i1, closest_i2 = segments[1][1], segments[1][2]

    -- get axis of scaling, orthogonal two line between two closest
    local center_x, center_y = math.rotate(x + 0.5 * w, y + 0.5 * h, angle, ox, oy)

    local side_x, side_y = math.turn_left(
        vertices[closest_i2][1] - vertices[closest_i1][1],
        vertices[closest_i2][2] - vertices[closest_i1][2]
    )

    local axis_x, axis_y = math.normalize(side_x, side_y)
    local magnitude = offset
    local scale = self._bounce_position

    axis_x = axis_x * scale * magnitude
    axis_y = axis_y * scale * magnitude

    -- scale only two closest vertices for bounce animation
    vertices[closest_i1][1] = vertices[closest_i1][1] + axis_x
    vertices[closest_i1][2] = vertices[closest_i1][2] + axis_y
    vertices[closest_i2][1] = vertices[closest_i2][1] + axis_x
    vertices[closest_i2][2] = vertices[closest_i2][2] + axis_y

    local top_left_x, top_left_y = math.rotate(vertices[1][1], vertices[1][2], -angle, ox, oy)
    local bottom_right_x, bottom_right_y = math.rotate(vertices[3][1], vertices[3][2], -angle, ox, oy)

    self._draw_x = top_left_x
    self._draw_y = top_left_y
    self._draw_width = math.abs(bottom_right_x - top_left_x)
    self._draw_height = math.abs(bottom_right_y - top_left_y)
end

-- simulate ball-on-a-spring for bouncing animation
local stiffness = rt.settings.overworld.bounce_pad.stiffness
local origin = rt.settings.overworld.bounce_pad.origin
local damping = rt.settings.overworld.bounce_pad.damping
local magnitude = rt.settings.overworld.bounce_pad.magnitude
local color_duration = rt.settings.overworld.bounce_pad.color_decay_duration

--- @brief
function ow.BouncePad:update(delta)
    if self._color_elapsed <= color_duration then
        self._color_elapsed = self._color_elapsed + delta

        local default_r, default_g, default_b = table.unpack(self._default_color)
        local target_r, target_g, target_b = table.unpack(self._color)
        local weight = rt.InterpolationFunctions.EXPONENTIAL_DECELERATION(math.min(self._color_elapsed / color_duration, 1))

        self._draw_color = {
            math.mix(default_r, target_r, weight),
            math.mix(default_g, target_g, weight),
            math.mix(default_b, target_b, weight),
            1
        }
    end

    if self._is_bouncing then
        local before = self._bounce_position
        self._bounce_velocity = self._bounce_velocity + -1 * (self._bounce_position - origin) * stiffness
        self._bounce_velocity = self._bounce_velocity * damping
        self._bounce_position = self._bounce_position + self._bounce_velocity * delta

        if math.abs(self._bounce_position - before) * offset < 10e-3 then -- more than 1 px change
            self._bounce_position = 0
            self._bounce_velocity = 0
            self._is_bouncing = false
        end
        self:_update_vertices()
    end
end

--- @brief
function ow.BouncePad:draw()
    love.graphics.push()
    love.graphics.translate(self._rotation_origin_x, self._rotation_origin_y)
    love.graphics.rotate(self._angle)
    love.graphics.translate(-self._rotation_origin_x, -self._rotation_origin_y)

    local r, g, b = table.unpack(self._draw_color)

    love.graphics.setColor(r, g, b, 0.9)
    love.graphics.rectangle("fill", self._draw_x, self._draw_y, self._draw_width, self._draw_height, 5)

    rt.graphics.set_blend_mode(nil)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("line", self._draw_x, self._draw_y, self._draw_width, self._draw_height, 5)

    love.graphics.pop()

end
