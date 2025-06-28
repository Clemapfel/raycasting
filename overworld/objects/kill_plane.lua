rt.settings.overworld.kill_plane = {
    max_respawn_duration = 2
}

--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

--- @class ow.KillPlaneTarget
ow.KillPlaneTarget = meta.class("KillPlaneTarget") -- dummy

local _state_inactive = 1
local _state_waiting_for_leave_bottom = 2
local _state_waiting_for_enter_top = 3

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    -- collision
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        self._body:signal_set_is_blocked("collision_start", true)
        self._world:signal_connect("step", function()
            self._body:signal_set_is_blocked("collision_start", false)
            return meta.DISCONNECT_SIGNAL
        end)
        self._stage:get_active_checkpoint():spawn()
    end)

    -- visual
    self._contour = object:create_contour()
    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    self._mesh = object:create_mesh()

    self._outline_color = rt.Palette.KILL_PLANE:clone()
    self._base_color = rt.Palette.KILL_PLANE:darken(0.8)
end

--- @brief
function ow.KillPlane:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    self._base_color:bind()
    love.graphics.draw(self._mesh:get_native())

    self._outline_color:bind()
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(4)
    love.graphics.line(self._contour)
end