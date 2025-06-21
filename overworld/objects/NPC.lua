rt.settings.overworld.NPC = {
    radius = 4 * rt.settings.player.radius,
    n_outer_bodies = 16
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT)

    --[[
    self._world = stage:get_physics_world()

    local radius = rt.settings.overworld.NPC.radius
    do -- move spawn point out of ground
        local x, y = object.x, object.y
        local top_x, top_y = self._world:query_ray(x, y, 0, -1 * 10e6)
        local bottom_x, bottom_y = self._world:query_ray(x, y, 0, 1 * 10e6)

        self._x = bottom_x
        self._y = math.max(bottom_y - 2.5 * radius, top_y)
    end

    local n_outer_bodies = rt.settings.overworld.NPC.n_outer_bodies
    self._radius = radius
    self._inner_body_radius = 10
    self._outer_body_radius = 2 * (2 * math.pi * self._radius) / n_outer_bodies
    self._inner_body_radius = 0.25
    self._body = b2.Body(
        self._world, b2.BodyType.DYNAMIC,
        self._x, self._y,
        b2.Circle(0, 0, self._inner_body_radius)
    )

    self._spring_bodies = {}
    self._spring_joints = {}
    self._spring_body_offsets_x = {}
    self._spring_body_offsets_y = {}

    local outer_body_shape =  b2.Circle(0, 0, self._outer_body_radius)

    local step = 2 * math.pi / n_outer_bodies
    for angle = 0, 2 * math.pi, step do
        local offset_x = math.cos(angle) * self._radius
        local offset_y = math.sin(angle) * self._radius
        local cx = self._x + offset_x
        local cy = self._y + offset_y

        local body = b2.Body(self._world, b2.BodyType.DYNAMIC, cx, cy, outer_body_shape)
        initialize_outer_body(body, false)
        body:set_mass(10e-2) -- spring strength

        local joint = b2.Spring(self._body, body, self._x, self._y, cx, cy)

        table.insert(self._spring_bodies, body)
        table.insert(self._spring_joints, joint)
        table.insert(self._spring_body_offsets_x, offset_x)
        table.insert(self._spring_body_offsets_y, offset_y)
    end
    ]]--
end

--- @brief
function ow.NPC:draw()
    --[[
    self._body:draw()
    for body in values(self._spring_bodies) do
        body:draw()
    end
    ]]--
end