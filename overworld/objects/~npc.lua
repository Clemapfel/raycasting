require "common.delaunay_triangulation"
require "overworld.player_recorder_body"
require "overworld.player_recorder_eyes"
require "common.render_texture_3d"
require "common.blur"

rt.settings.overworld.npc = {
    -- model
    canvas_radius = 150,
    canvas_padding = 20,
    face_backing_factor = 1.2, -- times eye radius
    radius_factor = 1.5, -- times player radius
    blur_strength = 4,
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    assert(object:get_type() == ow.ObjectType.POINT, "NPC should be Point")
    self._x = object.x
    self._y = object.y

    local radius_factor = object:get_number("radius_factor", false) or 1
    local length_factor = object:get_number("length_factor", false) or 1

    self._radius = radius_factor * self._scene:get_player():get_radius()
    self._max_radius = self._radius * rt.settings.player.bubble_radius_factor
    self._graphics_body = rt.PlayerBody({
        radius = self._radius,
        max_radius = self._max_radius,
        rope_length_radius_factor = rt.settings.player_body.default_rope_length_radius_factor * length_factor,
    })
    self._graphics_body:set_world(self._world)
    self._graphics_body:set_gravity(0, 0)

    local bottom_x, bottom_y = self._world:query_ray(self._x, self._y, 0, 1 * 10e8)
    if bottom_x == nil then
        bottom_x, bottom_y = self._x, self._y
    end

    self._body = b2.Body(
        self._world,
        b2.BodyType.DYNAMIC,
        bottom_x, bottom_y - self._radius,
        b2.Circle(0, 0, self._radius)
    )

    -- core shape
    do
        local n_outer_vertices = rt.settings.player.n_outer_bodies
        local positions = {}
        local r = radius_factor * self._scene:get_player():get_core_radius() - 1.5
        for i = 1, n_outer_vertices do
            local angle = (i - 1) / n_outer_vertices * 2 * math.pi
            table.insert(positions, math.cos(angle) * r)
            table.insert(positions, math.sin(angle) * r)
        end

        self._graphics_body:set_shape(positions)
        self._graphics_body:set_opacity(1)
    end
end

--- @brief
function ow.NPC:update(delta)
    self._graphics_body:set_position(self._body:get_position())
    self._graphics_body:update(delta)
end

--- @brief
function ow.NPC:draw()
    self._graphics_body:draw_body()
    self._graphics_body:draw_core()
    self._graphics_body:draw_bloom()
end

function ow.NPC:draw_bloom()
    self._graphics_body:draw_bloom()
end

--- @brief
function ow.NPC:get_render_priority()
    return -1 -- below player
end