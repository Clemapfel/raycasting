--- @class ow.FrontWall
ow.FrontWall = meta.class("FrontWall")

local _shader = rt.Shader("overworld/objects/front_wall.glsl", {
    MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
    MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights
})

--- @brief
function ow.FrontWall:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._mesh = object:create_mesh()
    self._contour = rt.contour.close(object:create_contour())
end

--- @brief
function ow.FrontWall:draw()
    love.graphics.push("all")

    local camera = self._scene:get_camera()
    local point_light_sources, point_light_colors = self._stage:get_point_light_sources()
    local segment_light_sources, segment_light_colors = self._stage:get_segment_light_sources()

    love.graphics.setColor(1, 1, 1, 1)
    local shader = _shader
    shader:bind()
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
    shader:send("light_range", rt.settings.overworld.wall.light_range) -- sic, use ow.Wall
    shader:send("outline_color", { rt.Palette.WALL:unpack() })
    self._mesh:draw()
    shader:unbind()

    rt.Palette.WALL_OUTLINE:bind()
    love.graphics.setLineWidth(rt.settings.overworld.hitbox.slippery_outline_width)
    love.graphics.line(self._contour)

    love.graphics.pop()
end

--- @brief
function ow.FrontWall:get_render_priority()
    return math.huge -- always front
end