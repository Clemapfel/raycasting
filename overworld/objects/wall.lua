rt.settings.overworld.wall = {
    point_light_intensity = 1,
    segment_light_intensity = 1,
    light_range = 30, -- px
}

--- @class ow.Wall
ow.Wall = meta.class("Wall")

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

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then _pattern_to_shader[ow.WallPatternType.FLAT]:recompile() end
end)

function ow.Wall:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._mesh = object:create_mesh()
    self._contour = rt.contour.close(object:create_contour())

    local pattern = object:get_string("pattern") or ow.WallPatternType.FLAT
    self._pattern = string.upper(pattern)
    meta.assert_enum_value(self._pattern, ow.WallPatternType)

    self._shader = _pattern_to_shader[self._pattern]

    if ow.Wall._impulse == nil then
        ow.Wall._impulse = rt.ImpulseSubscriber()
    end
end

--- @brief
function ow.Wall:draw()
    love.graphics.push("all")

    local camera = self._scene:get_camera()
    local point_light_sources, point_light_colors = self._stage:get_point_light_sources()
    local segment_light_sources, segment_light_colors = self._stage:get_segment_light_sources()

    love.graphics.setColor(1, 1, 1, 1)
    local shader = self._shader
    shader:bind()
    shader:send("elapsed", rt.SceneManager:get_elapsed())
    shader:send("camera_scale", camera:get_final_scale())
    shader:send("n_point_light_sources", #point_light_sources)
    if #point_light_sources > 0 then
        shader:send("point_light_sources", table.unpack(point_light_sources))
        shader:send("point_light_colors", table.unpack(point_light_colors))
    end

    shader:send("n_segment_light_sources", #segment_light_sources)
    if #segment_light_sources > 0 then
        shader:send("segment_light_sources", table.unpack(segment_light_sources))
        shader:send("segment_light_colors", table.unpack(segment_light_colors))
    end

    local brightness_factor = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, ow.Wall._impulse:get_pulse())
    shader:send("point_light_intensity", rt.settings.overworld.wall.point_light_intensity * brightness_factor)
    shader:send("segment_light_intensity", rt.settings.overworld.wall.segment_light_intensity * brightness_factor)
    shader:send("screen_to_world_transform", camera:get_transform():inverse())
    shader:send("light_range", rt.settings.overworld.wall.light_range * brightness_factor)
    shader:send("outline_color", { rt.Palette.WALL:unpack() })
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
