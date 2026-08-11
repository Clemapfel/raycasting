require "common.path"
require "common.contour"
require "overworld.normal_map"
require "overworld.mirror"
require "overworld.shadow_cast"

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
    object.properties[b2.Tag.SLIPPERY] = true
    return ow.MovableHitbox(object, stage, scene)
end

local schema = {
    slippery = ow.Boolean,
    sticky = ow.Boolean,
    unjumpable = ow.Boolean,
    unwalkable = ow.Boolean
}

--- @brief
function ow.MovableHitbox:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)

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
        b2.Tag.SLIPPERY,
        b2.Tag.STICKY,
        b2.Tag.UNJUMPABLE,
        b2.Tag.UNWALKABLE
    ) do
        if object:get_boolean(property) then
            self._body:add_tag(property)
        end
    end

    if self._body:has_tag(b2.Tag.SLIPPERY) then
        self._body:add_tag(b2.Tag.NO_BLOOD)
    end
    self._body:add_tag(b2.Tag.HITBOX, b2.Tag.STENCIL)
    self._body:add_tag(b2.Tag.USE_LIGHTING)

    local mesh, tris = object:create_mesh(true) -- translate to origin
    self._mesh = mesh
    self._tris = tris
    self._contour = rt.contour.close(object:create_contour(true)) -- translate to origin

    -- graphics
    self._normal_map = ow.NormalMap(
        object:get_id(), -- id for caching
        function() return self._tris end, -- get triangles
        function() self._mesh:draw() end -- draw mask
    )

    self._is_slippery = object:get_boolean(b2.Tag.SLIPPERY)
    if self._is_slippery == nil then self._is_slippery = false end

    self._shadow_cast = ow.ShadowCast(scene)

    if self._is_slippery then
        self._mirror = ow.Mirror(
            self._scene,
            function() self._mesh:draw() end, -- mirror mask
            nil  -- occluding mask
        )

        self._mirror:initialize(
            { self._contour }, -- mirror
            {} -- occluding
        )

        self._shadow_cast:initialize(
            { self._contour }, -- mirror
            {} -- occluding
        )
    else
        self._blood_spatter = ow.BloodSpatter(self._scene)
        self._blood_spatter:initialize(
            { self._contour }
        )

        self._shadow_cast:initialize(
            {}, -- mirror
            { self._contour } -- occluding
        )
    end

    -- lighting
    if self._blood_spatter ~= nil then
        self._body:add_tag(b2.Tag.SEGMENT_LIGHT_SOURCE)
        self._body:set_user_data(self)
        self.collect_segment_lights = function(self, callback)
            local camera = self._scene:get_camera()
            local bounds = camera:get_world_bounds()
            local padding = rt.settings.overworld.stage.visible_area_padding * camera:get_final_scale()
            bounds.x = bounds.x - padding
            bounds.y = bounds.y - padding
            bounds.width = bounds.width + 2 * padding
            bounds.height = bounds.height + 2 * padding

            self._blood_spatter:set_offset(self._body:get_position())
            self._blood_spatter:collect_segment_lights(bounds, callback)
            self._shadow_cast:collect_segment_lights(callback)
        end
    end
end

local dt = math.eps * 10e2

function ow.MovableHitbox:update(delta)
    local is_visible = self._stage:get_is_body_visible(self._body)

    if is_visible then
        local offset_x, offset_y = self._body:get_position()

        if self._mirror ~= nil then -- slippery
            self._mirror:set_offset(offset_x, offset_y)
            self._mirror:update(delta)
        else -- slippery
            self._blood_spatter:update(delta)
            self._blood_spatter:set_offset(offset_x, offset_y)
            self._blood_spatter:notify_camera_changed(self._scene:get_camera())
        end

        self._shadow_cast:set_offset(offset_x, offset_y)
        self._shadow_cast:update(delta)
    end
end

--- @brief
function ow.MovableHitbox:draw(priority)
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    if self._mirror ~= nil then
        self._mirror:set_offset(offset_x, offset_y)
    else
        self._blood_spatter:set_offset(offset_x, offset_y)
    end

    if self._normal_map:get_is_done() then
        self._normal_map:set_offset(offset_x, offset_y)
    end

    self._shadow_cast:set_offset(offset_x, offset_y)

    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    if self._is_slippery then
        rt.Palette.SLIPPERY:bind()
    else
        rt.Palette.STICKY:bind()
    end
    self._mesh:draw()

    if self._is_slippery then
        rt.Palette.SLIPPERY_OUTLINE:bind()
        love.graphics.setLineWidth(rt.settings.overworld.hitbox.slippery_outline_width)
    else
        rt.Palette.STICKY_OUTLINE:bind()
        love.graphics.setLineWidth(rt.settings.overworld.hitbox.sticky_outline_width)
    end

    love.graphics.setLineJoin("bevel")
    love.graphics.line(self._contour)

    love.graphics.pop()

    if self._normal_map:get_is_done() then
        local camera = self._scene:get_camera()
        self._normal_map:draw_shadow(camera)
        self._normal_map:draw_light(camera)
    end

    if self._mirror ~= nil then
        self._mirror:draw()
    elseif self._blood_spatter ~= nil then
        self._blood_spatter:draw()
    end

    self._shadow_cast:draw()
end

--- @brief
function ow.MovableHitbox:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    if self._blood_spatter ~= nil then
        love.graphics.setColor(1, 1, 1, 1)
        self._blood_spatter:draw_bloom()
    end

    self._shadow_cast:draw_bloom()
end

