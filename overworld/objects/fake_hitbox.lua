--- @class ow.FakeHitbox
ow.FakeHitbox = meta.class("FakeHitbox")

--- @class ow.SlipperyFakeHitbox
--- @types Polygon, Rectangle, Ellipse
ow.SlipperyFakeHitbox = function(object, stage, scene)
    object.properties["slippery"] = true
    return ow.FakeHitbox(object, stage, scene)
end

--- @class ow.StickyFakeHitbox
--- @types Polygon, Rectangle, Ellipse
ow.StickyFakeHitbox = function(object, stage, scene)
    object.properties["slippery"] = false
    return ow.FakeHitbox(object, stage, scene)
end

local _shader = rt.Shader("overworld/objects/fake_hitbox.glsl", {
    MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
    MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights
})

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "l" then
        _shader:recompile()
    end
end)

--- @brief
function ow.FakeHitbox:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._mesh, self._tris = object:create_mesh()
    self._body = object:create_physics_body(self._stage:get_physics_world())
    self._body:set_collision_group(0x0)
    self._body:set_collides_with(0x0)

    self._contour = rt.contour.close(object:create_contour())

    self._normal_map = ow.NormalMap(
        object:get_id(), -- caching id
        function() return self._tris end, -- get triangles
        function() self._mesh:draw() end -- draw mask
    )

    self._is_slippery = object:get_boolean("slippery")
    if self._is_slippery == nil then self._is_slippery = false end

    if self._is_slippery then
        self._color = rt.Palette.SLIPPERY
        self._outline_color = rt.Palette.SLIPPERY_OUTLINE

        for tri in values(self._tris) do
            table.insert(ow.Hitbox._slippery_mesh_tris, tri)
        end
    else
        self._color = rt.Palette.STICKY
        self._outline_color = rt.Palette.STICKY_OUTLINE

        for tri in values(self._tris) do
            table.insert(ow.Hitbox._sticky_mesh_tris, tri)
        end
    end
end

--- @brief
function ow.FakeHitbox:update(delta)
    if self._normal_map:get_is_done() == false then
        self._normal_map:update(delta)
    end
end

local back_priority, front_priority = -math.huge, -1

--- @brief
function ow.FakeHitbox:draw(priority)
    if not self._stage:get_is_body_visible(self._body) then return end

    local camera = self._scene:get_camera()

    love.graphics.push("all")

    if priority == back_priority then

        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
        ow.Hitbox:draw_mask(true, true)
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

        -- base
        self._color:bind()
        self._mesh:draw()

        -- shadow
        if self._normal_map:get_is_done() then
            self._normal_map:draw_shadow(camera)
        end

        -- outline
        self._outline_color:bind()
        love.graphics.setLineWidth(rt.settings.overworld.hitbox.slippery_outline_width)
        love.graphics.setLineJoin("bevel")
        love.graphics.line(self._contour)

        rt.graphics.set_stencil_mode(nil)
    else

        -- lighting
        local point_light_sources, point_light_colors = self._stage:get_point_light_sources()
        local segment_light_sources, segment_light_colors = self._stage:get_segment_light_sources()

        love.graphics.setColor(1, 1, 1, 0.5) -- hitbox normal map contributes
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
        shader:send("light_range", rt.settings.overworld.wall.light_range - 2) -- sic, use ow.Wall

        self._mesh:draw()
        shader:unbind()
    end

    love.graphics.pop()
end

--- @brief
function ow.FakeHitbox:get_render_priority()
    return back_priority, front_priority
end