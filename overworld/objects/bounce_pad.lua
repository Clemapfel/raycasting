rt.settings.overworld.bounce_pad = {

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
    assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.BouncePad.instantiate: object " .. object.id .. " is not a rectangle")

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

        _bounce_position = 1, -- in [0, 1]
        _bounce_velocity = 1,
        _is_bouncing = true,

        _color = { rt.Palette.BOUNCE_PAD:unpack() }
    })

    self:_update_vertices()

    self._body:add_tag("slippery", "no_blood", "unjumpable")


    self._body:set_collides_with(bit.bor(
        rt.settings.overworld.player.player_collision_group,
        rt.settings.overworld.player.player_outer_body_collision_group
    ))

    self._body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
        local player = self._scene:get_player()

        self._color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }

        local magnitude = math.min(math.magnitude(player:get_velocity()) / rt.settings.overworld.player.bounce_max_force, 1)
        self._bounce_velocity = magnitude
        self._bounce_position = math.max(magnitude, 0.3)
        self._bounce_contact_x, self._bounce_contact_y = cx, cy
        self._is_bouncing = true
    end)

    self._body:signal_connect("collision_end", function()
        self._color = { rt.Palette.BOUNCE_PAD:unpack() }
    end)
end

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
    return math.sqrt(dist_x * dist_x + dist_y * dist_y)
end

--- @brief
function ow.BouncePad:_update_vertices()
    local x, y, w, h = self._x, self._y, self._width, self._height
    local angle = self._angle
    local ox, oy = self._rotation_origin_x, self._rotation_origin_y
    local scale = 1 - self._bounce_position
    local contact_x, contact_y = self._bounce_contact_x, self._bounce_contact_y

    local vertices = {
        [1] = { math.rotate(x,     y,     angle, ox, oy) }, -- top left
        [2] = { math.rotate(x + w, y,     angle, ox, oy) }, -- top right
        [3] = { math.rotate(x + w, y + h, angle, ox, oy) }, -- bottom right
        [4] = { math.rotate(x,     y + h, angle, ox, oy) }, -- bottom left
    }

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

    local side_x, side_y =
        vertices[closest_i2][1] - vertices[closest_i1][1],
        vertices[closest_i2][2] - vertices[closest_i1][2]

    self._dbg = {
        vertices[closest_i1][1], vertices[closest_i1][2],
        vertices[closest_i2][1], vertices[closest_i2][2]
    }

    --[[
    local axis_x, axis_y = center_x + side_x, center_y + side_y
    axis_x = axis_x * scale
    axis_y = axis_y * scale

    vertices[closest_i1][1] = vertices[closest_i1][1] + axis_x
    vertices[closest_i1][2] = vertices[closest_i1][2] + axis_y
    vertices[closest_i2][1] = vertices[closest_i2][1] + axis_x
    vertices[closest_i2][2] = vertices[closest_i2][2] + axis_y
    ]]--

    self._vertices = {
        vertices[1][1], vertices[1][2],
        vertices[2][1], vertices[2][2],
        vertices[3][1], vertices[3][2],
        vertices[4][1], vertices[4][2],
    }
end

-- simulate ball-on-a-spring for bouncing animation
local stiffness = rt.settings.overworld.bounce_pad.stiffness
local origin = rt.settings.overworld.bounce_pad.origin
local damping = rt.settings.overworld.bounce_pad.damping
local magnitude = rt.settings.overworld.bounce_pad.magnitude

--- @brief
function ow.BouncePad:update(delta)
    if self._is_bouncing then
        local before = self._bounce_position
        self._bounce_velocity = self._bounce_velocity + -1 * (self._bounce_position - origin) * stiffness
        self._bounce_velocity = self._bounce_velocity * damping
        self._bounce_position = self._bounce_position + self._bounce_velocity * delta

        if math.abs(self._bounce_position - before) > 1 / love.graphics.getHeight() then
            self:_update_vertices()
        else
            self._is_bouncing = false
        end
    end
end

--- @brief
function ow.BouncePad:draw()
    love.graphics.setColor(table.unpack(self._color))
    love.graphics.polygon("fill", self._vertices)
    love.graphics.polygon("line", self._vertices)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(table.unpack(self._dbg))
end
