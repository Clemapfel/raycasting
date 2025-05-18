require "physics.physics"
require "common.camera"
require "common.input_subscriber"

rt.settings.menu.title_screen_scene = {
    player_max_velocity = 1000
}

--- @class mn.TitleScreenScene
mn.TitleScreenScene = meta.class("TitleScreenScene", rt.Scene)

--- @brief
function mn.TitleScreenScene:instantiate(state)
    self._state = state
    self._player = state:get_player()
    self._player:set_is_bubble(false)

    self._camera = rt.Camera()
    self._input = rt.InputSubscriber()

    -- setup dummy platform
    self._world = b2.World()
    local platform_x, platform_y, platform_w, platform_h = 0, self._player:get_radius(), 100, 50
    self._platform = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Rectangle(
        platform_x - platform_w / 2, platform_y,
        platform_w, platform_h
    ))

    self._player:move_to_world(self._world)
end

--- @brief
function mn.TitleScreenScene:realize()

end

--- @brief
function mn.TitleScreenScene:size_allocate(x, y, width, height)

end

--- @brief
function mn.TitleScreenScene:enter()
    self._input:activate()
end

--- @brief
function mn.TitleScreenScene:exit()
    self._input:deactivate()
end

--- @brief
function mn.TitleScreenScene:update(delta)
    self._world:update(delta)
    self._player:update(delta)
    self._camera:move_to(self._player:get_position())
    self._camera:update(delta)

    local max_velocity_x, max_velocity_y = rt.settings.player.max_velocity_x, rt.settings.player.max_velocity_y
    local velocity_x, velocity_y = self._player:get_velocity()
    self._player:set_flow(velocity_y / max_velocity_y)
end

--- @brief
function mn.TitleScreenScene:draw()
    self._camera:bind()
    self._player:draw()
    self._platform:draw()
    self._camera:unbind()
end

--- @brief
function mn.TitleScreenScene:get_camera()
    return self._camera
end