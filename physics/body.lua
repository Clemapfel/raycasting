--- @class b2.Body
b2.Body = meta.class("PhysicsBody")

local _shape_id = 0

--- @brief
function b2.Body:instantiate(world, x, y, angle)
    if angle == nil then angle = 0 end
    meta.assert(
        world, "PhysicsWorld",
        x, "Number",
        y, "Number"
    )

    meta.install(self, {
        _world = world,
        _entities = {},
        _shapes = {},
        _transform = slick.newTransform(
            x, y,
            angle
        ),
        _is_destroyed = false,

        _position_x = x,
        _position_y = y,
        _velocity_x = 0,
        _velocity_y = 0,
    })

    table.insert(self._world._bodies, self)
end

--- @brief
function b2.Body:add_shape(shape, ...)
    if self._is_destroyed then rt.error("In b2.Body.add_shape: trying to add shape to an already destroyed body") end
    assert(meta.isa(shape, b2.Shape), "In b2.Body.add_shape: expected `b2.Shape`, got `" .. meta.typeof(shape) .. "`")
    table.insert(self._shapes, shape)
    local n = select("#", ...)
    if n > 0 then
        local natives = { shape._native}
        for i = 2, n + 1 do
            local other_shape = select(i - 1, ...)
            meta.assert_typeof(other_shape, "Shape", i)
            table.insert(self._shapes, other_shape)
            table.insert(natives, { other_shape._native})
        end
        self._entities[_shape_id] = self._world._native:add(slick.newShapeGroup(table.unpack(natives)))
    else
        self._entities[_shape_id] = self._world._native:add(_shape_id, self._transform, shape._native)
        _shape_id = _shape_id + 1
    end
end
b2.Body.add_shapes = b2.Body.add_shape

--- @brief
function b2.Body:draw()
    if self._is_destroyed then rt.error("In b2.Body.draw: trying to draw an already destroyed body") end
    for shape in values(self._shapes) do
        shape:draw()
    end
end

--- @brief
function b2.Body:destroy()
    for id in keys(self._entities) do
        self._world:remove(id)
    end
    self._is_destroyed = true
end