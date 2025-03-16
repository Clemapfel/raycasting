rt.settings.overworld.rope = {
    mass_factor = 0.1
}
--- @class Rope
rt.Rope = meta.class("Rope", rt.Drawable, function(self, world, x, y, radii)
    meta.assert(world, b2.World, x, "Number", y, "Number", radii, "Table")

    local mass_factor = rt.settings.overworld.rope.mass_factor
    local nodes = {}
    local current_x, current_y = x, y
    local hue = 0
    for i = 1, #radii do
        local r, g, b = rt.lcha_to_rgba(0.8, 1, hue)
        hue = hue + 1 / #radii
        local radius = radii[i]

        local body = b2.Body(world, b2.BodyType.DYNAMIC, current_x, current_y, b2.Circle(0, 0, radius))
        body._native:setMass(0)
        body:set_collides_with(bit.bnot(b2.CollisionGroup.GROUP_16))

        table.insert(nodes, {
            current_x = current_x,
            current_y = current_y,
            radius = radius,
            last_x = current_x,
            last_y = current_y,
            body = body,
            r = r,
            g = g,
            b = b,
            a = 1
        })

        current_x = current_x - radius
    end

    meta.install(self, {
        _nodes = nodes,
        _anchor_x = x,
        _anchor_y = y,
        _n_nodes = #radii,
    })
end)

--- @brief
function rt.Rope:draw()
    for i = 1, self._n_nodes do
        local node = self._nodes[i]
        love.graphics.setColor(node.r, node.g, node.b, node.a)
        node.body:draw()
        --love.graphics.circle("line", node.current_x, node.current_y, node.radius)
    end
end

--- @brief
function rt.Rope:update(delta, n_iterations)
    if n_iterations == nil then n_iterations = 10 end
    self:_verlet_step(delta)
    for i = 1, n_iterations do
        self:_apply_collision()
        self:_apply_jakobsen_constraints()
    end
end

local mass_factor = 0.2

--- @brief
function rt.Rope:_verlet_step(delta)
    local delta_squared = delta * delta
    local friction = 1 - 0.5
    local gravity_x, gravity_y = 0, 0
    for i = 1, self._n_nodes, 1 do
        local node = self._nodes[i]
        local current_x, current_y = node.current_x, node.current_y
        local old_x, old_y = node.last_x, node.last_y
        local mass = node.body:get_mass()

        local before_x, before_y = current_x, current_y

        node.current_x = current_x + (current_x - old_x) * friction + gravity_x * mass * delta_squared
        node.current_y = current_y + (current_y - old_y) * friction + gravity_y * mass * delta_squared

        node.last_x = before_x
        node.last_y = before_y

        node.body:set_position(node.current_x, node.current_y)
    end
end

--- @brief
function rt.Rope:_apply_jakobsen_constraints()
    local first = self._nodes[1]
    first.current_x = self._anchor_x
    first.current_y = self._anchor_y

    for i = 1, self._n_nodes - 1 do
        local a = self._nodes[i]
        local b = self._nodes[i + 1]

        local difference_x = a.current_x - b.current_x
        local difference_y = a.current_y - b.current_y

        local distance
        local x_delta = b.current_x - a.current_x
        local y_delta = b.current_y - a.current_y
        distance = math.sqrt(x_delta * x_delta + y_delta * y_delta)
        local difference = ((a.radius + b.radius) - distance) / distance

        local translate_x = difference_x * 0.5 * difference
        local translate_y = difference_y * 0.5 * difference

        a.current_x = a.current_x + translate_x
        a.current_y = a.current_y + translate_y
        b.current_x = b.current_x - translate_x
        b.current_y = b.current_y - translate_y
    end
end

function rt.Rope:_apply_collision()
    for i = 1, self._n_nodes do
        for j = i + 1, self._n_nodes do
            local a = self._nodes[i]
            local b = self._nodes[j]

            local dx = b.current_x - a.current_x
            local dy = b.current_y - a.current_y
            local distance = math.sqrt(dx * dx + dy * dy)
            local min_distance = a.radius + b.radius

            if distance < min_distance then
                local overlap = 0.5 * (min_distance - distance)
                local nx = dx / distance
                local ny = dy / distance

                a.current_x = a.current_x - overlap * nx
                a.current_y = a.current_y - overlap * ny
                b.current_x = b.current_x + overlap * nx
                b.current_y = b.current_y + overlap * ny
            end
        end
    end
end

--- @brief
function rt.Rope:set_anchor(x, y)
    self._anchor_x = x
    self._anchor_y = y
end
