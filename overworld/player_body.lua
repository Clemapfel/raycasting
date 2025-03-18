local slick = require "physics.slick.slick"

--- @class ow.PlayerBody
ow.PlayerBody = meta.class("PlayerBody", rt.Drawable)

local _shader = nil

--- @brief
function ow.PlayerBody:instantiate(world, player_radius, main_body)
    local x, y = main_body:get_position()

    if _shader == nil then _shader = rt.Shader("overworld/player_body.glsl") end

    local mass_ratio = 0.001
    main_body._native:setMass(10)
    main_body._native:setFixedRotation(true)

    local n_steps = 28
    local radius = player_radius * 1.3
    local perimeter = 2 * math.pi * radius
    local small_radius = perimeter / n_steps * 2
    local n_radius_steps = 1

    self._radius = radius
    self._small_radius = small_radius
    self._bodies = {}
    self._main_body = main_body
    self._line = {}
    for angle = 0, 2 * math.pi, (2 * math.pi) / n_steps do
        local r = radius
        local ax, ay = math.cos(angle), math.sin(angle)

        local body_x = x + ax * r
        local body_y = y + ay * r
        local body = b2.Body(world, b2.BodyType.DYNAMIC, body_x, body_y, b2.Circle(0, 0, small_radius))
        body._native:setMass(mass_ratio * main_body._native:getMass())
        local angular = love.physics.newPrismaticJoint(main_body._native, body._native, body_x, body_y, ax, ay, true)
        local distance = love.physics.newRopeJoint(main_body._native, body._native, x, y, body_x, body_y, r, false)
        table.insert(self._bodies, body)
        table.insert(self._line, body_x)
        table.insert(self._line, body_y)
    end

    local buffer = 30
    self._buffer = buffer
    self._texture = rt.Blur(
        2 * radius + 2 * buffer,
        2 * radius + 2 * buffer,
        8
    )
    self._texture:set_blur_strength(3)
end

function ow.PlayerBody:update(delta)
    local contour = {}
    local center_x, center_y = self._main_body:get_position()
    local min_distance = math.huge
    for body in values(self._bodies) do
        local x, y = body:get_position()
        local dx, dy = x - center_x, y - center_y
        local ndx, ndy = math.normalize(dx, dy)
        local d = math.magnitude(dx, dy)
        table.insert(contour, center_x + ndx * (d))
        table.insert(contour, center_y + ndy * (d))

        if math.magnitude(dx, dy) < min_distance then min_distance = math.magnitude(dx, dy) end
    end

    self._min_distance = min_distance
    self._shape = contour
end

--- @brief
function ow.PlayerBody:draw()
    for tri in values(self._shape) do
       --love.graphics.polygon("fill", tri)
    end

    self._texture:bind()
    love.graphics.clear(1, 1, 1, 0)
    love.graphics.push()

    local mx, my = self._main_body:get_predicted_position()
    love.graphics.origin()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(self._small_radius * 2)
    love.graphics.setLineJoin("none")
    love.graphics.line(self._shape)

    local offset = self._radius + self._buffer
    love.graphics.circle("fill", offset, offset, self._radius)

    for body in values(self._bodies) do
        local x, y = body:get_predicted_position()
        love.graphics.circle("fill", x - mx + offset, y - my + offset, self._small_radius)
    end

    love.graphics.pop()
    self._texture:unbind()

    _shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    self._texture:draw(mx - offset, my - offset)
    _shader:unbind()
    love.graphics.setLineWidth(1)
end