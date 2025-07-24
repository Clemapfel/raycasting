require "common.delaunay_triangulation"
require "overworld.objects.npc_deformable_mesh"
require "overworld.blood_drop"

rt.settings.overworld.npc = {
    segment_length = 10,
    buffer_depth = rt.settings.player.radius,
    blood_drop_velocity = 300,
    blood_drop_gravity = 300
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

local _collision_group = b2.CollisionGroup.GROUP_07

local _data_mesh_format = {
    { location = 4, name = "origin", format = "floatvec2" }, -- spring origin
    { location = 5, name = "contour_vector", format = "floatvec3" } -- normalized xy, z is length
}

local _mesh_shader, _outline_shader

local first = true -- TODO

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    if _mesh_shader == nil then
        _mesh_shader = rt.Shader("overworld/objects/npc_mesh.glsl")
    end

    if _outline_shader == nil then
        _outline_shader = rt.Shader("overworld/objects/npc_outline.glsl")
    end

    if first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "z" then
                _mesh_shader:recompile()
            end
        end)
        first = false
    end

    self._velocity_x = 0
    self._velocity_y = 0

    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    -- inner, hard-body shell
    local contour = object:create_contour()

    self._deformable_mesh = ow.DeformableMesh(self._world, contour) -- has inner hard shell
    self._deformable_mesh:get_body():add_tag("stencil", "hitbox")

    self._mesh = object:create_mesh()

    table.insert(contour, contour[1])
    table.insert(contour, contour[2])
    self._contour = contour

    self._deformable_mesh_center_x, self._deformable_mesh_center_y = self._deformable_mesh:get_center()

    self._sensor = object:create_physics_body(self._world)
    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    self._blood_drops = {}

    self._color = { rt.Palette.TRUE_WHITE:unpack() }

    self._is_active = false
    self._sensor:signal_connect("collision_start", function(_, normal_x, normal_y, x, y)
        self._is_active = true

        --[[
        -- spawn blood drops
        local x, y = self._scene:get_player():get_position()
        local up = 3 / 4 * 2 * math.pi
        for i = 1, rt.random.integer(10, 30) do
            local angle = rt.random.number(up - 0.5 * math.pi, up + 0.5 * math.pi)
            local magnitude = rt.settings.overworld.npc.blood_drop_velocity
            local vx, vy = math.cos(angle) * magnitude, math.sin(angle) * magnitude
            local blood_drop = ow.BloodDrop(
                self._stage,
                x, y,
                rt.random.number(1, 5), -- radius
                vx, vy,
                rt.random.number(0, 1) -- hue
            )

            blood_drop:signal_connect("collision", function()
                local to_remove
                for i, drop in values(self._blood_drops) do
                    if drop == blood_drop then
                        to_remove = i
                    end
                end

                assert(i ~= nil)
                table.remove(self._blood_drops, to_remove)
                return meta.DISCONNECT_SIGNAL
            end)

            table.insert(self._blood_drops, blood_drop)
        end
        ]]--
    end)

    self._sensor:signal_connect("collision_end", function()
        self._is_active = false
        self._last_force_x, self._last_force_y = 0, 0
    end)

    self._is_visible = self._scene:get_is_body_visible(self._sensor)
    self._last_force_x, self._last_force_y = 0, 0
end

--- @brief
function ow.NPC:draw()
    if not self._scene:get_is_body_visible(self._sensor) then
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

    _mesh_shader:bind()
    _mesh_shader:send("player_color", color)
    _mesh_shader:send("player_position", { player_x, player_y })

    self._deformable_mesh:draw_body()

    -- outline

    local contour = self._deformable_mesh:get_contour()

    love.graphics.setLineWidth(8)
    love.graphics.setLineJoin("bevel")

    rt.Palette.BLACK:bind()
    for i = 1, #contour, 2 do
        love.graphics.circle("fill", contour[i+0], contour[i+1], 0.5 * love.graphics.getLineWidth())
    end

    love.graphics.line(contour)

    _mesh_shader:unbind()

    love.graphics.setLineWidth(4)
    love.graphics.setColor(self._color)

    _outline_shader:bind()
    _outline_shader:send("player_color", color)
    _outline_shader:send("player_position", { player_x, player_y })

    love.graphics.line(contour)

    _outline_shader:unbind()

    self._deformable_mesh:draw_highlight()

    rt.graphics.set_stencil_mode(nil)

    --[[
    for drop in values(self._blood_drops) do
        drop:draw()
    end
    ]]--
end

--- @brief
function ow.NPC:update(delta)
    --if not self._scene:get_is_body_visible(self._sensor) then return

    for drop in values(self._blood_drops) do
        drop:get_body():apply_force(0, rt.settings.overworld.npc.blood_drop_gravity)
    end

    local player = self._scene:get_player()
    local x, y = player:get_position()
    local radius = player:get_radius()
    local force_x, force_y = self._deformable_mesh:step(delta, x, y, radius)

end

--- @brief
function ow.NPC:get_render_priority()
    return math.huge
end

--- @brief
function ow.NPC:draw_bloom()
    love.graphics.setColor(self._color)
    love.graphics.line(self._deformable_mesh:get_contour())
end