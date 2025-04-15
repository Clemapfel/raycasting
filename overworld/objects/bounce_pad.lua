rt.settings.overworld.bounce_pad = {
    cooldown = 1 / 60,
    -- bounce simulation parameters
    stiffness = 10,
    damping = 0.95,
    center = 0,
    magnitude = 100,
    bounce_magnitude_min = 0.3
}

--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    local angle = object.rotation
    meta.install(self, {
        _world = stage:get_physics_world(),
        _body = object:create_physics_body(stage:get_physics_world()),
        _cooldown_timestamp = -math.huge, -- prevent multiple impulses per step

        _bounce_axis_x = 0,
        _bounce_axis_y = 1,
        _bounce_origin_x = 0,
        _bounce_origin_y = 0,

        _bounce_position = 1, -- in [0, 1]
        _bounce_velocity = 1
    })

    self._body:add_tag("no_blood")
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, x1, y1, x2, y2, contact)
        local player = other_body:get_user_data()
        if player == nil then return end

        if other_body:get_is_sensor() then return end

        contact:setRestitution(0)
        local elapsed = love.timer.getTime() - self._cooldown_timestamp
        if elapsed < rt.settings.overworld.bounce_pad.cooldown then
            return
        else
            player:bounce(normal_x, normal_y)
            self._cooldown_timestamp = love.timer.getTime()
        end

        if x2 ~= nil or y2 ~= nil then
            x1 = (x1 + x2) / 2
            y1 = (y1 + y2) / 2
        end

        -- get opposite side of shape
        local px, py = player:get_position()
        local dx, dy = px - x1, py - y1
        dx, dy = -dx, -dy

        local ray_origin_x, ray_origin_y = px + dx * 10e6, py + dy * 10e6
        local ray_destination_x, ray_destination_y = px, py

        local shape = table.first(self._body:get_native():getShapes())
        local tx, ty = self._body:get_position()
        local angle = self._body:get_rotation()

        local cx, cy = x1, y1
        if x2 ~= nil or y2 ~= nil then -- if two points, use mean
            cx = (x1 + x2) / 2
            cy = (y1 + y2) / 2
        end

        local success, nx, ny, fraction = pcall(shape.rayCast, shape, ray_origin_x, ray_origin_y, ray_destination_x, ray_destination_y, 2, tx, ty, angle)
        if not success or nx == nil or ny == nil then return end

        local hit_x = ray_origin_x + (ray_destination_x - ray_origin_x) * fraction
        local hit_y = ray_origin_y + (ray_destination_y - ray_origin_y) * fraction
        self._bounce_axis_x, self._bounce_axis_y = math.normalize(px - x1, py - y1)
        self._bounce_origin_x, self._bounce_origin_y = hit_x, hit_y

        local magnitude = math.min(math.magnitude(player:get_velocity()) / rt.settings.overworld.player.bounce_max_force, 1)
        self._bounce_velocity = magnitude
        self._bounce_position = math.max(magnitude, rt.settings.overworld.bounce_pad.bounce_magnitude_min)
    end)

end

-- simulate ball-on-a-spring for bouncing animation
local stiffness = rt.settings.overworld.bounce_pad.stiffness
local center = rt.settings.overworld.bounce_pad.center
local damping = rt.settings.overworld.bounce_pad.damping
local magnitude = rt.settings.overworld.bounce_pad.magnitude

--- @brief
function ow.BouncePad:draw()
    rt.Palette.PINK:bind()

    local scale = self._bounce_position * 0.2
    local x, y = self._bounce_origin_x, self._bounce_origin_y
    local axis_x, axis_y = self._bounce_axis_x, self._bounce_axis_y

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(1, 1 + scale)
    love.graphics.rotate(self._body:get_rotation())

    love.graphics.translate(-x, -y)

    self._body:draw()
    love.graphics.pop()

    love.graphics.line(x, y, x + self._bounce_axis_x * scale, y + self._bounce_axis_y * scale)
end

--- @brief
function ow.BouncePad:update(delta)
    if math.abs(self._bounce_velocity) > 1 / magnitude then
        self._bounce_velocity = self._bounce_velocity + -1 * (self._bounce_position - center) * stiffness
        self._bounce_velocity = self._bounce_velocity * damping
        self._bounce_position = self._bounce_position + self._bounce_velocity * delta
    end
end

--- @brief
function ow.BouncePad:get_physics_body()
    return self._body
end