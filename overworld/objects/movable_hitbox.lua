require "common.path"
require "common.contour"
require "overworld.normal_map"
require "overworld.mirror"

rt.settings.overworld.moving_hitbox = {
    default_velocity = 100, -- px per second
}

--- @class ow.MovableHitbox
--- @types Polygon, Rectangle
--- @field velocity Number?
--- @field target ow.MovableHitboxTarget! pointer to path
ow.MovableHitbox = meta.class("MovableHitbox", ow.MovableObject)

--- @class ow.SlipperyMovableHitbox
--- @types Polygon, Rectangle, Ellipse
ow.SlipperyMovableHitbox = function(object, stage, scene)
    object.properties["slippery"] = true
    return ow.MovableHitbox(object, stage, scene)
end

--- @brief
function ow.MovableHitbox:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = self._stage:get_physics_world()

    self._body = object:create_physics_body(self._world)
    self._body:set_collision_group(bit.bor(
        rt.settings.overworld.hitbox.collision_group
    ))

    self._body:set_use_continuous_collision(true)
    local start_x, start_y = self._body:get_position()
    self._elapsed = 0

    -- match tags from ow.Hitbox
    for property in range(
        "slippery",
        "sticky",
        "unjumpable",
        "unwalkable"
    ) do
        if object:get_boolean(property) then
            self._body:add_tag(property)
        end
    end

    if self._body:has_tag("slippery") then
        self._body:add_tag("no_blood")
    end
    self._body:add_tag("hitbox", "stencil")

    -- mesh
    local _, tris, mesh_data
    _, tris, mesh_data = object:create_mesh()

    for i, data in ipairs(mesh_data) do
        data[1] = data[1] - start_x
        data[2] = data[2] - start_y
    end

    for tri in values(tris) do
        for j = 1, #tri, 2 do
            tri[j+0] = tri[j+0] - start_x
            tri[j+1] = tri[j+1] - start_y
        end
    end

    self._offset_x, self._offset_y = start_x, start_y
    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._tris = tris

    -- graphics
    self._normal_map = ow.NormalMap(
        object:get_id(), -- id for caching
        function() return self._tris end, -- get triangles
        function() self._mesh:draw() end -- draw mask
    )

    self._is_slippery = object:get_boolean("slippery")
    if self._is_slippery == nil then self._is_slippery = false end

    if self._is_slippery then
        self._mirror = ow.Mirror(
            self._scene,
            function() self._mesh:draw() end, -- mirror mask
            nil  -- occluding mask
        )

        self._mirror:create_contour(
            self._tris, -- mirror tris
            {} -- occluding tris
        )
    else
        self._blood_splatter = ow.BloodSplatter(
            self._scene
        )

        self._blood_splatter:create_contour(
            self._tris
        )
    end

    -- lighting
    if self._blood_splatter ~= nil then
        self._body:add_tag("segment_light_source")
        self._body:set_user_data(self)
        self.get_segment_light_sources = function(self)
            -- blood splatter already notified of offset
            return self._blood_splatter:get_segment_light_sources(self._scene:get_camera():get_world_bounds())
        end
    end
end

local dt = math.eps * 10e2

function ow.MovableHitbox:update(delta)
    if self._normal_map:get_is_done() == false then
        self._normal_map:update(delta) -- finish loading coroutine
    end

    self._offset_x, self._offset_y = self._body:get_position()

    local is_visible = self._stage:get_is_body_visible(self._body)

    if is_visible then
        if self._normal_map:get_is_done() then
            self._normal_map:update()
        end

        if self._mirror ~= nil then
            self._mirror:update(delta)
        else
            local player = self._scene:get_player()
            if player:get_is_colliding_with(self._body) then
                local nx, ny, cx, cy = player:get_collision_normal(self._body)
                local r = player:get_radius() / 2
                self._blood_splatter:add(cx, cy, r, player:get_color():unpack())
            end
        end
    end
end

--- @brief
function ow.MovableHitbox:draw(priority)
    if not self._stage:get_is_body_visible(self._body) then return end

    if self._mirror ~= nil then
        self._mirror:set_offset(self._body:get_predicted_position())
    else
        self._blood_splatter:set_offset(self._body:get_predicted_position())
    end

    love.graphics.push()
    love.graphics.translate(self._body:get_position())
    love.graphics.rotate(self._body:get_rotation())

    if self._is_slippery then
        rt.Palette.SLIPPERY:bind()
    else
        rt.Palette.STICKY:bind()
    end
    self._mesh:draw()

    local camera = self._stage:get_scene():get_camera()
    local camera_offset_x, camera_offset_y = camera:get_position()
    camera_offset_x = -camera_offset_x
    camera_offset_y = -camera_offset_y

    if self._normal_map:get_is_done() then
        -- set offset to compensate for camera movement, and for translation of
        -- tris to origin in instantiate
        self._normal_map:set_offset(camera_offset_x, camera_offset_y)
        self._normal_map:draw_shadow(camera)

        local point_lights, point_colors = self._stage:get_point_light_sources()
        local segment_lights, segment_colors = self._stage:get_segment_light_sources()
        self._normal_map:draw_light(
            camera,
            point_lights,
            point_colors,
            segment_lights,
            segment_colors
        )
    end

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    self._mesh:draw()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    if self._is_slippery then
        rt.Palette.SLIPPERY_OUTLINE:bind()
    else
        rt.Palette.STICKY_OUTLINE:bind()
    end

    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("bevel")

    for tri in values(self._tris) do
        love.graphics.line({
            tri[1], tri[2], tri[3], tri[4], tri[5], tri[6], tri[1], tri[2]
        })
    end

    rt.graphics.set_stencil_mode(nil)

    love.graphics.pop()

    if self._mirror ~= nil then
        self._mirror:draw()
    elseif self._blood_splatter ~= nil then
        self._blood_splatter:draw()
    end
end

