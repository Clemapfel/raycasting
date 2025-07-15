rt.settings.overworld.portal = {
    mesh_w = 30, -- px
    pulse_duration = 1, -- s
    transition_speed = 500, -- px / s
}

--- @class ow.Portal
ow.Portal = meta.class("Portal")

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _assert_point = function(object)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Portal: object `" .. object:get_id() .. " is not a point")
end

local _current_hue = 0
local _get_hue = function()
    local out = _current_hue
    _current_hue = math.fract(_current_hue + 1 / 8)
    return _current_hue
end

local _particle_texture

local _LEFT = true
local _RIGHT = not _LEFT

-- which side of a segment vector points to
local _get_side = function(vx, vy, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local cross = abx * vy - aby * vx
    return cross < 0
end

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    if _particle_texture == nil then
        local radius = 30
        local padding = 3
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))

        local mesh = rt.MeshCircle(0, 0, radius)
        local value = 0.4 -- for additive blending
        mesh:set_vertex_color(1, 1, 1, 1)
        for i = 2, mesh:get_n_vertices() do
            mesh:set_vertex_color(i, 1, 1, 1, 0)
        end

        love.graphics.push()
        love.graphics.origin()
        _particle_texture:bind()
        love.graphics.translate(0.5 * _particle_texture:get_width(), 0.5 * _particle_texture:get_width())
        mesh:draw()
        _particle_texture:unbind()
        love.graphics.pop()
    end

    self._stage = stage
    self._scene = scene
    self._world = self._stage:get_physics_world()

    self._pulse_elapsed = math.huge
    self._pulse_value = 0

    self._hue = 0

    self._direction = object:get_boolean("left_or_right", true)
    self._transition_active = false
    self._transition_elapsed = math.huge
    self._transition_contact_x, self._transition_contact_y = 0, 0
    self._transition_velocity_x, self._transition_velocity_y = 0, 0

    stage:signal_connect("initialized", function()
        -- get portal pairs as ordered points
        self._a = object
        _assert_point(self._a)
        self._ax, self._ay = object.x, object.y

        self._b = object:get_object("other", true)
        _assert_point(self._b)
        self._bx, self._by = self._b.x, self._b.y

        self._target = stage:get_object_instance(object:get_object("target", true))
        assert(self._target ~= nil and meta.isa(self._target, ow.Portal), "In ow.Portal: `target` of object `" .. object:get_id() .. "` is not another portal")

        -- synch hue
        if self._hue_set == false and self._target._hue_set == true then
            self._hue = self._target._hue
        elseif self._hue_set == true and self._target._hue_set == false then
            self._target._hue = self._hue
        elseif self._hue_set == false and self._target._hue_set == false then
            self._hue = _get_hue()
            self._target._hue = self._hue
        end

        self._hue_set = true
        self._target._hue_set = true

        local dx, dy = math.normalize(self._ax - self._bx, self._ay - self._by)
        local left_x, left_y = math.turn_left(dx, dy)
        local right_x, right_y = math.turn_right(dx, dy)

        if self._direction == _LEFT then
            self._normal_x, self._normal_y = left_x, left_y
        else
            self._normal_x, self._normal_y = right_x, right_y
        end

        -- sensors
        self._is_disabled = false

        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        local segment_w = 5
        self._segment_sensor = b2.Body(
            self._world,
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Polygon(
                self._ax - center_x, self._ay - center_y,
                self._ax + self._normal_x * segment_w - center_x, self._ay + self._normal_y * segment_w - center_y,
                self._bx + self._normal_x * segment_w - center_x, self._by + self._normal_y * segment_w - center_y,
                self._bx - center_x, self._by - center_y
            )
        )

        self._segment_sensor:set_use_continuous_collision(true)
        self._segment_sensor:set_collides_with(rt.settings.player.player_collision_group)
        self._segment_sensor:add_tag("unjumpable", "slippery")

        self._segment_sensor:signal_connect("collision_start", function(self_body, other_body, nx, ny, contact_x, contact_y)
            if not self._is_disabled and contact_x ~= nil and contact_y ~= nil then
                -- check if allowed to enter from that side
                local vx, vy = self._scene:get_player():get_velocity()
                local side = _get_side(vx, vy, self._ax, self._ay, self._bx, self._by)
                if (side == self._direction) then
                    -- start transition
                    self._transition_active = true
                    self._transition_elapsed = 0
                    self._transition_contact_x, self._transition_contact_y = contact_x, contact_y
                    self._transition_x, self._transition_y = contact_x, contact_y
                    self._transition_velocity_x, self._transition_velocity_y = self._scene:get_player():get_velocity()
                    self:_set_player_disabled(true)
                    self:_update_transition_stencil()
                end
            end
        end)

        -- rectangle sensor
        local sensor_w = rt.settings.player.radius

        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w - center_x, self._ay +  left_y * sensor_w - center_y,
            self._ax + right_x * sensor_w - center_x, self._ay + right_y * sensor_w - center_y,
            self._bx + right_x * sensor_w - center_x, self._by + right_y * sensor_w - center_y,
            self._bx +  left_x * sensor_w - center_x, self._by +  left_y * sensor_w - center_y
        )

        self._area_sensor = b2.Body(self._world, b2.BodyType.STATIC, center_x, center_y, sensor_shape)
        self._area_sensor:set_is_sensor(true)

        -- graphics
        do
            local outer = function() return 0, 0, 0, 0 end -- rgba
            local inner = function() return 1, 1, 1, 1 end

            local w = rt.settings.overworld.portal.mesh_w

            local padding = 0 --0.25 * math.distance(self._ax, self._ay, self._bx, self._by)
            local ax, ay = self._ax - dx * padding, self._ay - dy * padding
            local bx, by = self._bx + dx * padding, self._by + dy * padding

            if self._direction == _LEFT then
                local left_mesh_data = {
                    { ax +  left_x * w, ay +  left_y * w, 0, 1, outer() },
                    { ax, ay, 0, 0, inner() },
                    { bx, by, 1, 0, inner() },
                    { bx +  left_x * w, by +  left_y * w, 1, 1, outer() }
                }

                self._left_mesh = rt.Mesh(left_mesh_data)
            else
                local right_mesh_data = {
                    { ax, ay, 1, 0, inner() },
                    { ax + right_x * w, ay + right_y * w, 1, 1, outer() },
                    { bx + right_x * w, by + right_y * w, 0, 1, outer() },
                    { bx, by, 0, 0, inner() }
                }

                self._right_mesh = rt.Mesh(right_mesh_data)
            end
        end
    end)
end

--- @brief
function ow.Portal:_set_player_disabled(b)
    local player = self._scene:get_player()
    player:set_is_ghost(b)
    player:set_is_visible(not b)
    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
end


function aabb_line_intersection(top_left_x, top_left_y, top_right_x, top_right_y, bottom_right_x, bottom_right_y, bottom_left_x, bottom_left_y, lx1, ly1, lx2, ly2)
    -- AABB corners: (x1,y1) top-left, (x2,y2) top-right, (x3,y3) bottom-right, (x4,y4) bottom-left
    -- Line: from (lx1,ly1) to (lx2,ly2)

    local ix1, iy1, ix2, iy2 = nil, nil, nil, nil
    local count = 0

    -- Helper function to find intersection between two line segments
    local function line_intersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
        local denom = (ax1 - ax2) * (by1 - by2) - (ay1 - ay2) * (bx1 - bx2)
        if math.abs(denom) < 1e-10 then
            return nil -- Lines are parallel
        end

        local t = ((ax1 - bx1) * (by1 - by2) - (ay1 - by1) * (bx1 - bx2)) / denom
        local u = -((ax1 - ax2) * (ay1 - by1) - (ay1 - ay2) * (ax1 - bx1)) / denom

        -- Check if intersection is within the AABB edge (u between 0 and 1)
        if u >= 0 and u <= 1 then
            local ix = ax1 + t * (ax2 - ax1)
            local iy = ay1 + t * (ay2 - ay1)
            return ix, iy
        end

        return nil
    end

    -- Check intersection with each side of the AABB
    -- Top side: (x1,y1) to (x2,y2)
    local ix, iy = line_intersect(lx1, ly1, lx2, ly2, top_left_x, top_left_y, top_right_x, top_right_y)
    if ix then
        count = count + 1
        if count == 1 then
            ix1, iy1 = ix, iy
        elseif count == 2 then
            ix2, iy2 = ix, iy
        end
    end

    -- Right side: (x2,y2) to (x3,y3)
    if count < 2 then
        ix, iy = line_intersect(lx1, ly1, lx2, ly2, top_right_x, top_right_y, bottom_right_x, bottom_right_y)
        if ix then
            count = count + 1
            if count == 1 then
                ix1, iy1 = ix, iy
            elseif count == 2 then
                ix2, iy2 = ix, iy
            end
        end
    end

    -- Bottom side: (x3,y3) to (x4,y4)
    if count < 2 then
        ix, iy = line_intersect(lx1, ly1, lx2, ly2, bottom_right_x, bottom_right_y, bottom_left_x, bottom_left_y)
        if ix then
            count = count + 1
            if count == 1 then
                ix1, iy1 = ix, iy
            elseif count == 2 then
                ix2, iy2 = ix, iy
            end
        end
    end

    -- Left side: (x4,y4) to (x1,y1)
    if count < 2 then
        ix, iy = line_intersect(lx1, ly1, lx2, ly2, bottom_left_x, bottom_left_y, top_left_x, top_left_y)
        if ix then
            count = count + 1
            if count == 1 then
                ix1, iy1 = ix, iy
            elseif count == 2 then
                ix2, iy2 = ix, iy
            end
        end
    end

    -- Return the two intersection points
    if count >= 2 then
        return ix1, iy1, ix2, iy2
    else
        return nil -- Should not happen if line always intersects exactly 2 sides
    end
end

function point_on_opposite_side(lx1, ly1, lx2, ly2, px, py, vx, vy)
    -- Line: from (lx1,ly1) to (lx2,ly2)
    -- Point: (px, py)
    -- Vector: (vx, vy)
    -- Y-axis extends downwards

    -- Calculate the line's normal vector (perpendicular to the line)
    local line_dx = lx2 - lx1
    local line_dy = ly2 - ly1

    -- Normal vector pointing to the right of the line direction
    local normal_x = -line_dy
    local normal_y = line_dx

    -- Determine which side of the line the vector points towards
    -- by checking the dot product of the vector with the line's normal
    local vector_dot_normal = vx * normal_x + vy * normal_y

    -- Calculate which side of the line the point is on
    -- using the cross product (point - line_start) × line_direction
    local point_relative_x = px - lx1
    local point_relative_y = py - ly1
    local point_cross = point_relative_x * line_dy - point_relative_y * line_dx

    -- If vector_dot_normal and point_cross have opposite signs,
    -- then the point is on the opposite side of the line from where the vector points
    if vector_dot_normal > 0 then
        -- Vector points towards the right side of the line
        return point_cross < 0  -- Point is on the left side (opposite)
    elseif vector_dot_normal < 0 then
        -- Vector points towards the left side of the line
        return point_cross > 0  -- Point is on the right side (opposite)
    else
        -- Vector is parallel to the line
        return false  -- Undefined case, return false
    end
end

function sort_points_by_angle(points)
    -- points is a table of flat numbers: {x1, y1, x2, y2, x3, y3, ...}
    -- Returns the same table sorted by angle relative to centroid

    local count = #points / 2
    if count < 2 then return points end

    -- Calculate centroid
    local cx, cy = 0, 0
    for i = 1, #points, 2 do
        cx = cx + points[i]
        cy = cy + points[i + 1]
    end
    cx = cx / count
    cy = cy / count

    -- Create array of {index, angle} pairs for sorting
    local angle_data = {}
    for i = 1, #points, 2 do
        local dx = points[i] - cx
        local dy = points[i + 1] - cy
        -- Use atan2 for full circle angle (-π to π)
        local angle = math.atan2(dy, dx)
        angle_data[#angle_data + 1] = {i, angle}
    end

    -- Sort by angle using quicksort-style approach
    table.sort(angle_data, function(a, b) return a[2] < b[2] end)

    -- Rebuild points array in sorted order
    local sorted_points = {}
    for i = 1, #angle_data do
        local idx = angle_data[i][1]
        sorted_points[#sorted_points + 1] = points[idx]
        sorted_points[#sorted_points + 1] = points[idx + 1]
    end

    -- Copy back to original array
    for i = 1, #sorted_points do
        points[i] = sorted_points[i]
    end

    return points
end

--- @brief
function ow.Portal:_update_transition_stencil()
    -- generate mesh that is half plane of screen on opposite side of line
    local camera = self._scene:get_camera()
    local ax, ay = camera:world_xy_to_screen_xy(self._ax, self._ay)
    local bx, by = camera:world_xy_to_screen_xy(self._bx, self._by)
    local vx, vy = self._transition_velocity_x, self._transition_velocity_y

    local width, height = love.graphics.getDimensions()
    local top_left_x, top_left_y = 0, 0
    local top_right_x, top_right_y = width, 0
    local bottom_right_x, bottom_right_y = width, height
    local bottom_left_x, bottom_left_y = 0, height

    -- two intersection points are always part of shape
    local vertices = {
        aabb_line_intersection(
            top_left_x, top_left_y,
            top_right_x, top_right_y,
            bottom_right_x, bottom_right_y,
            bottom_left_x, bottom_left_y,
            ax, ay, bx, by
        )
    }

    -- corner candidates
    local points = {
        top_left_x, top_left_y,
        top_right_x, top_right_y,
        bottom_right_x, bottom_right_y,
        bottom_left_x, bottom_left_y
    }

    for i = 1, #points, 2 do
        local x, y = points[i+0], points[i+1]
        if point_on_opposite_side(ax, ay, bx, by, x, y, vx, vy) then
            table.insert(vertices, x)
            table.insert(vertices, y)
        end
    end

    --self._transition_stencil = sort_points_by_angle(vertices)
end

--- @brief
function ow.Portal:update(delta)
    if self._transition_active then
        self._transition_elapsed = self._transition_elapsed + delta
        local traveled = self._transition_elapsed * rt.settings.overworld.portal.transition_speed

        local target = self._target
        local from_x, from_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        local to_x, to_y = math.mix2(target._ax, target._ay, target._bx, target._by, 0.5)
        local distance = math.distance(from_x, from_y, to_x, to_y)
        local t = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(traveled / distance)

        self._transition_x, self._transition_y = math.mix2(from_x, from_y, to_x, to_y, t)
        self._scene:get_camera():move_to(self._transition_x, self._transition_y)
        self:_update_transition_stencil()

        if t >= 1 then
            self:_teleport()
            self:_set_player_disabled(false)
            self._transition_active = false
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
        end
    end

    -- test manually, more reliable at high velocities
    if self._is_disabled then
        if self._area_sensor:test_point(self._scene:get_player():get_position()) == false then
            self._is_disabled = false
        end
    end

    if self._scene:get_is_body_visible(self._area_sensor) == false then return end

    self._pulse_elapsed = self._pulse_elapsed + delta
    local pulse_duration = rt.settings.overworld.portal.pulse_duration
    self._pulse_value = rt.InterpolationFunctions.ENVELOPE(
        math.min(self._pulse_elapsed / pulse_duration),
        pulse_duration * 0.05
    )
end

local _get_ratio = function(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay

    local ab_length_squared = math.dot(abx, aby, abx, aby)
    local t = math.dot(apx, apy, abx, aby) / ab_length_squared
    return math.max(0, math.min(1, t))
end

local _get_sidedness = function(ax, ay, bx, by)
    return math.cross(ax, ay, bx, by) > 0
end

local function teleport_player(
    from_ax, from_ay, from_bx, from_by,
    to_ax, to_ay, to_bx, to_by,
    from_normal_x, from_normal_y, to_normal_x, to_normal_y,
    vx, vy, contact_x, contact_y
)
    -- new position
    local ratio = _get_ratio(contact_x, contact_y, from_ax, from_ay, from_bx, from_by)
    local from_sidedness = _get_sidedness(from_ax, from_ay, from_bx, from_by)
    local to_sidedness = _get_sidedness(to_ax, to_ay, to_bx, to_by)
    if from_sidedness ~= to_sidedness then
        ratio = 1 - ratio
    end

    local new_x, new_y = math.mix2(to_ax, to_ay, to_bx, to_by, 0.5) --ratio)

    -- new velocity
    local magnitude = math.magnitude(vx, vy)
    local new_vx, new_vy = to_normal_x * magnitude, to_normal_y * magnitude

    return new_x, new_y, new_vx, new_vy
end

function ow.Portal:_teleport()
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local target = self._target

    -- disable to prevent loops
    target._is_disabled = true
    self._is_disabled = true

    self._pulse_elapsed = 0
    target._pulse_elapsed = 0

    local new_x, new_y, new_vx, new_vy = teleport_player(
        self._ax, self._ay,  self._bx, self._by,
        target._ax, target._ay, target._bx, target._by,
        self._normal_x, self._normal_y, target._normal_x, target._normal_y,
        self._transition_velocity_x, self._transition_velocity_y,
        self._transition_contact_x, self._transition_contact_y
    )

    local radius = player:get_radius()
    local nvx, nvy = math.normalize(new_vx, new_vy)
    player:teleport_to(new_x + radius * nvx, new_y + radius * nvy)
    player:set_velocity(new_vx, new_vy)

    do
        local contact_x, contact_y = self._transition_contact_x, self._transition_contact_y
        new_vx, new_vy = math.normalize(new_vx, new_vy)

        _dbg = {
            {
                new_x, new_y,
                new_x + new_vx * 10,
                new_y + new_vy * 10
            }, {
                contact_x, contact_y,
                contact_x + new_vx * 10,
                contact_y + new_vy * 10
            }
        }
    end
end

--- @brief
function ow.Portal:draw()
    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, self._hue, 1)

    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(4)
    love.graphics.line(self._ax, self._ay, self._bx, self._by)

    if self._direction == _LEFT then
        self._left_mesh:draw()
    else
        self._right_mesh:draw()
    end

    if self._transition_active then
        love.graphics.circle("fill", self._transition_x, self._transition_y, 5)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    self._segment_sensor:draw()

    if _dbg ~= nil then
        for l in values(_dbg) do love.graphics.line(l) end
    end

    if self._transition_active then
        local value = 254
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)

        love.graphics.push()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.polygon("fill", self._transition_stencil)
        love.graphics.pop()

        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

        local player = self._scene:get_player()
        player:set_is_visible(true)
        rt.graphics.push_stencil()
        player:draw_body()
        rt.graphics.pop_stencil()
        player:draw_core()
        player:set_is_visible(false)

        rt.graphics.set_stencil_mode(nil)
    end
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end