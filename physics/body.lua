--- @class b2.Body
b2.Body = meta.class("PhysicsBody")

local _entity_id = 0

--- @brief
--- @param world b2.World
--- @param x Number
--- @param y Number
--- @param shape b2.Shape
--- @param ... b2.Shapes
function b2.Body:instantiate(world, x, y, shape, ...)
    meta.assert(world, "PhysicsWorld", x, "Number", y, "Number")
    local shapes = {shape, ...}
    local natives = {}
    for i, current_shape in ipairs(shapes) do
        assert(meta.isa(current_shape, b2.Shape), "In b2.Body: argument #" .. 3 + i .. ": expected `b2.Shape`, got `" .. meta.typeof(current_shape) .. "`")
        table.insert(natives, current_shape._native)
    end

    meta.install(self, {
        _transform = slick.newTransform(x, y),
        _shapes = shapes,
        _world = world,
        _entity_id = _entity_id,
        _entity = world:add(_entity_id, x, y, slick.newShapeGroup(
            natives
        )),

        velocity_x = 0,
        velocity_y = 0,
        angular_velocity = 0
    })

    world._bodies[_entity_id] = self
    _entity_id = _entity_id + 1

end

--- @brief
function b2.Body:draw()
    for shape in values(self._shapes) do
        shape:draw(self._transform)
    end
end