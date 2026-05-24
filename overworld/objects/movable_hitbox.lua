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

local schema = {
    slippery = ow.Boolean,
    sticky = ow.Boolean,
    unjumpable = ow.Boolean,
    unwalkable = ow.Boolean
}

--- @brief
function ow.MovableHitbox:instantiate(object, stage, scene)
    object:validate_schema(schema)

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
    self._body:add_tag("use_lighting")

    local mesh, tris = object:create_mesh(true) -- translate to origin
    self._mesh = mesh
    self._tris = tris
    self._contour = rt.contour.close(object:create_contour(true))

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
            { self._contour }, -- mirror
            {} -- occluding
        )
    else
        self._blood_splatter = ow.BloodSplatter(
            self._scene
        )

        self._blood_splatter:create_contour(
            { self._contour }
        )
    end

    -- lighting
    if self._blood_splatter ~= nil then
        self._body:add_tag("segment_light_source")
        self._body:set_user_data(self)
        self.collect_segment_lights = function(self, callback)
            local camera = self._scene:get_camera()
            local bounds = camera:get_world_bounds()
            local padding = rt.settings.overworld.stage.visible_area_padding * camera:get_final_scale()
            bounds.x = bounds.x - padding
            bounds.y = bounds.y - padding
            bounds.width = bounds.width + 2 * padding
            bounds.height = bounds.height + 2 * padding

            self._blood_splatter:set_offset(self._body:get_position())
            self._blood_splatter:collect_segment_lights(bounds, callback)
        end
    end
end

local dt = math.eps * 10e2

function ow.MovableHitbox:update(delta)
    if self._normal_map:get_is_done() == false then
        self._normal_map:update(delta) -- finish loading coroutine
    end

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

    local offset_x, offset_y = self._body:get_position()

    if self._mirror ~= nil then
        self._mirror:set_offset(offset_x, offset_y)
    else
        self._blood_splatter:set_offset(offset_x, offset_y)
    end

    if self._normal_map:get_is_done() then
        self._normal_map:set_offset(offset_x, offset_y)
        self._normal_map.dbg = true
    end

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

    if self._mirror ~= nil then
        self._mirror:draw()
    elseif self._blood_splatter ~= nil then
        self._blood_splatter:draw()
    end

    if self._normal_map:get_is_done() then
        local camera = self._scene:get_camera()
        self._normal_map:draw_shadow(camera)
        self._normal_map:draw_light(camera)
    end
end

