require "common.delaunay_triangulation"
require "overworld.objects.npc_deformable_mesh"
require "overworld.blood_drop"
require "overworld.objects.bounce_pad"

rt.settings.overworld.npc = {
    bounce_max_offset = rt.settings.player.radius, -- in px
    bounce_cooldown = 4 / 60
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @class ow.NPCFrame
ow.NPCFrame = meta.class("NPCFrame") -- dummy

local _collision_group = b2.CollisionGroup.GROUP_07

local _data_mesh_format = {
    { location = 4, name = "origin", format = "floatvec2" }, -- spring origin
    { location = 5, name = "contour_vector", format = "floatvec3" } -- normalized xy, z is length
}

local _mesh_shader = rt.Shader("overworld/objects/npc_mesh.glsl")
local _outline_shader = rt.Shader("overworld/objects/npc_outline.glsl")

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    -- inner, hard-body shell
    local contour = object:create_contour()

    self._deformable_mesh = ow.DeformableMesh(self._scene, self._world, contour) -- has inner hard shell
    self._deformable_mesh:get_body():add_tag("stencil", "hitbox")

    self._mesh = object:create_mesh()

    table.insert(contour, contour[1])
    table.insert(contour, contour[2])
    self._contour = contour

    self._deformable_mesh_center_x, self._deformable_mesh_center_y = self._deformable_mesh:get_center()

    -- create sensor
    self._sensor = object:create_physics_body(self._world)
    self._sensor:set_is_sensor(true)
    self._sensor:set_use_continuous_collision(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    self._color = { rt.Palette.TRUE_WHITE:unpack() }

    self._is_active = false -- mesh deformation active

    -- bounce animation

    self._is_bouncing = false
    self._bounce_position = rt.settings.overworld.bounce_pad.origin -- in [0, 1]
    self._bounce_velocity = 0
    self._bounce_cooldown = math.huge

    self._sensor:signal_connect("collision_start", function(_, other_body, normal_x, normal_y, x, y)
        self._is_active = true
        dbg("enter", meta.hash(other_body))
        -- bounce started in update
    end)

    self._sensor:signal_connect("collision_end", function(_, other_body)
        self._is_active = false
        dbg("exit", meta.hash(other_body))
        self._last_force_x, self._last_force_y = 0, 0
    end)

    self._is_visible = self._stage:get_is_body_visible(self._sensor)
end

--- @brief
function ow.NPC:update(delta)
    if not self._stage:get_is_body_visible(self._sensor) then return end

    -- mesh depression
    local player = self._scene:get_player()
    local x, y = player:get_position()
    local radius = player:get_radius()
    local force_x, force_y = self._deformable_mesh:step(delta, x, y, radius)

    -- start bounce, manual check because collision is too unreliable
    local previous = self._bounce_previous

    -- test point on player circle pointing towards mesh, instead of player center
    local mesh_x, mesh_y = self._deformable_mesh:get_center()
    local dx, dy = math.normalize(mesh_x - x, mesh_y)
    local current = self._sensor:test_point(x + dx * radius, y + dy * radius)

    --[[
    if previous == false and current == true then
        local center_x, center_y = self._deformable_mesh:get_center()
        if y <= center_y and self._bounce_cooldown > rt.settings.overworld.npc.bounce_cooldown then -- only bounce up
            local restitution = self._scene:get_player():bounce(0, -1.3) -- experimentally determined for best game feel
            self._bounce_velocity = restitution
            self._bounce_position = restitution
            self._is_bouncing = true
            self._bounce_cooldown = 0
        end
    end
    ]]--

    self._bounce_previous = current
    self._bounce_cooldown = self._bounce_cooldown + delta

    -- bounce
    local damping = rt.settings.overworld.bounce_pad.damping
    local origin = rt.settings.overworld.bounce_pad.origin
    local stiffness = 0.5 * rt.settings.overworld.bounce_pad.stiffness
    local offset = rt.settings.overworld.bounce_pad.bounce_max_offset

    if self._is_bouncing and not rt.GameState:get_is_performance_mode_enabled() then
        local before = self._bounce_position
        self._bounce_velocity = self._bounce_velocity + -1 * (self._bounce_position - origin) * stiffness
        self._bounce_velocity = self._bounce_velocity * damping
        self._bounce_position = self._bounce_position + self._bounce_velocity * delta

        if math.abs(self._bounce_position - before) * offset < 1 / love.graphics.getWidth() then -- more than 1 px change
            self._bounce_position = 0
            self._bounce_velocity = 0
            self._is_bouncing = false
        end
    end
end

--- @brief
function ow.NPC:draw()
    if not self._stage:get_is_body_visible(self._sensor) then
        if self._is_visible then
            self._is_visible = false
            self._deformable_mesh:reset()
        end

        return
    end

    local stencil = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.DRAW)

    ow.Hitbox:draw_mask(true, true)

    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    local player = self._scene:get_player()
    local player_x, player_y = self._scene:get_camera():world_xy_to_screen_xy(player:get_position())
    local color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }

    -- apply stretch
    local base_x, base_y = self._deformable_mesh:get_base()
    local height = self._deformable_mesh:get_height()
    local scale = self._bounce_position * rt.settings.overworld.npc.bounce_max_offset / height
    love.graphics.push()
    love.graphics.translate(base_x, base_y)
    love.graphics.scale(1, 1 + scale)
    love.graphics.translate(-base_x, -base_y)

    _mesh_shader:bind()
    _mesh_shader:send("player_color", color)
    _mesh_shader:send("player_position", { player_x, player_y })

    self._deformable_mesh:draw_body()

    -- outline

    local contour = self._deformable_mesh:get_contour()

    love.graphics.setLineWidth(6)
    love.graphics.setLineJoin("bevel")

    rt.Palette.BLACK:bind()
    love.graphics.line(contour)

    _mesh_shader:unbind()

    love.graphics.setLineWidth(4)
    love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1))
    self._deformable_mesh:draw_outline()

    love.graphics.setColor(1, 1, 1, 1)
    self._deformable_mesh:draw_highlight()

    love.graphics.pop() -- stretch
    rt.graphics.set_stencil_mode(nil)

    self._sensor:draw() -- TODO
end

--- @brief
function ow.NPC:get_render_priority()
    return math.huge
end

--- @brief
function ow.NPC:draw_bloom()
    if not self._stage:get_is_body_visible(self._deformable_mesh:get_body()) then return end
    love.graphics.setColor(self._color)
    love.graphics.line(self._deformable_mesh:get_contour())
end