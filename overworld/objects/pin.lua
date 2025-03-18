--- @class ow.Pin
ow.Pin = meta.class("OverworldPin")

--- @brief
function ow.Pin:instantiate(object, stage, scene)
    assert(object.type == ow.ObjectType.POINT, "In ow.Pin: expected object of type `POINT`, got `" .. object.type .. "`")

    stage:signal_connect("initialized", function(stage)
        local world = stage:get_physics_world()
        local x, y = object.x, object.y

        local radius = 1
        local bodies = world:query_aabb(x + radius, y + radius, 2 * radius, 2 * radius)

        local n = table.sizeof(bodies)
        if n < 2 then
            rt.warning("In ow.Pin: object `" .. object.id .. "` does not overlap two or more bodies")
            return
        end

        table.sort(bodies, function(a, b)
            return a:get_native():getMass() > b:get_native():getMass()
        end)

        for i = 1, n-1 do
            local a = bodies[i]
            local b = bodies[i+1]

            local joint = love.physics.newWeldJoint(
                a:get_native(),
                b:get_native(),
                object.x, object.y
            )

            joint:setStiffness(100)
            joint:setDamping(100)
        end
    end)
end