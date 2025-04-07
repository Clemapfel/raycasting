rt.settings.overworld.bounce_pad = {
    -- bounce simulation parameters
    stiffness = 10,
    damping = 0.9,
    center = 0,
    magnitude = 100
}

--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    local angle = object.rotation
    meta.install(self, {
        _world = stage:get_physics_world(),
        _body = object:create_physics_body(stage:get_physics_world()),
        _cooldown = false, -- prevent multiple impulses per step

        _bounce_axis_x = 0,
        _bounce_axis_y = 1,

        _bounce_position = 0, -- in [0, 1]
        _bounce_velocity = 0
    })

    local blocking_body = nil
    self._body:set_collides_with(b2.CollisionGroup.GROUP_16)
    self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, x1, y1, x2, y2, contact)
        local player = other_body:get_user_data()
        if player == nil then return end

        if player:get_is_ragdoll() then
            contact:setRestitution(1)
            return
        end

        blocking_body = other_body
        if self._cooldown == false then
            player:bounce(normal_x, normal_y)
            self._cooldown = true
        end

        if x2 ~= nil or y2 ~= nil then
            x1 = (x1 + x2) / 2
            y1 = (y1 + y2) / 2
        end

        local px, py = player:get_position()
        self._bounce_axis_x, self._bounce_axis_y = math.normalize(px - x1, py - y1)
        self._bounce_velocity = -1
        self._bounce_position = 1
    end)

    self._world:signal_connect("step", function()
        self._cooldown = false
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

    local scale = self._bounce_position * magnitude
    local x, y = self._body:get_center_of_mass()
    local axis_x, axis_y = self._bounce_axis_x, self._bounce_axis_y

    -- Draw the object
    self._body:draw()

    -- Draw the bounce axis line
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