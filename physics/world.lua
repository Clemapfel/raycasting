--- @class b2.World
b2.World = meta.class("PhysicsWorld")

--- @brief
function b2.World:instantiate(width, height)
    meta.install(self, {
        _native = slick.newWorld(width, height),
        _bodies = {}
    })
end

--- @brief
function b2.World:update(delta)

end

