rt.settings.overworld.wall = {
    point_light_intensity = 1,
    segment_light_intensity = 1,
    light_range = 30, -- px
}

--- @class ow.Wall
ow.Wall = meta.class("Wall")

--- @enum ow.WallPatternType
ow.WallPatternType = meta.enum("WallPatternType", {
    FLAT = "FLAT",
    SPHERES = "SPHERES"
})

local _pattern_to_shader = {
    [ow.WallPatternType.FLAT] = rt.Shader("overworld/objects/wall_flat.glsl", {
        MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
        MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights
    }),

    [ow.WallPatternType.SPHERES] = rt.Shader("overworld/objects/wall_spheres.glsl", {
        MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
        MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights
    })
}

function ow.Wall:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._mesh = object:create_mesh()
    self._contour = rt.contour.close(object:create_contour())

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_collision_group(0x0)
    self._body:set_collides_with(0x0)
    self._body:add_tag("use_lighting")

    self._opacity = object:get_number("opacity") or rt.Palette.WALL.a

    local pattern = object:get_string("type") or ow.WallPatternType.FLAT
    self._pattern = string.upper(pattern)
    meta.assert_enum_value(self._pattern, ow.WallPatternType)

    self._shader = _pattern_to_shader[self._pattern]

    if ow.Wall._impulse == nil then
        ow.Wall._impulse = rt.ImpulseSubscriber()
    end
end

--- @brief
function ow.Wall:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push("all")
    local shader = self._shader
    shader:bind()

    local light_map = rt.SceneManager:get_light_map()
    shader:try_send("light_intensity", light_map:get_light_intensity())
    shader:try_send("light_direction", light_map:get_light_direction())
    shader:try_send("screen_to_world_transform", self._scene:get_camera():get_transform():inverse())
    shader:try_send("elapsed", rt.SceneManager:get_elapsed())

    local r, g, b =  rt.Palette.WALL:unpack()
    love.graphics.setColor(r, g, b, self._opacity)
    self._mesh:draw()
    shader:unbind()

    rt.Palette.WALL_OUTLINE:bind()
    love.graphics.setLineWidth(rt.settings.overworld.hitbox.slippery_outline_width)
    love.graphics.line(self._contour)

    love.graphics.pop()

end

function ow.Wall:get_render_priority()
    return -math.huge
end
