require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.blur"

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

    self._shader = rt.Shader("menu/title_screen_scene.glsl")
    self._shader_elapsed = 0
    self._shader_camera_offset = { 0, 0 }
    self._shader_camera_scale = 1
    self._fallspeed = 0

    -- setup dummy platform
    self._world = b2.World()
    local platform_x, platform_y, platform_w, platform_h = 0, self._player:get_radius(), 100, 50
    self._platform = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Rectangle(
        platform_x - platform_w / 2, platform_y,
        platform_w, platform_h
    ))

    self._player:move_to_world(self._world)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then
            self._shader:recompile()
            self._player:teleport_to(0, 0)
            self._player:set_velocity(0, 0)
            self._shader_elapsed = 0
        end
    end)

    self._input:signal_connect("mouse_wheel_moved", function(_, dx, dy)
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            local current = self._camera:get_scale()
            require("overworld.overworld_scene")
            current = current + dy * rt.settings.overworld.overworld_scene.camera_scale_velocity
            self._camera:set_scale(math.clamp(current, 1 / 3, 3))
        end
    end)
end

--- @brief
function mn.TitleScreenScene:realize()

end

--- @brief
function mn.TitleScreenScene:size_allocate(x, y, width, height)
    self._blur = rt.Blur(love.graphics.getDimensions())
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
    self._camera:move_to(self._player:get_position())
    self._camera:update(delta)
    self._player:update(delta)

    if true then --love.keyboard.isDown("space") then
        self._shader_elapsed = self._shader_elapsed + delta
        self._shader_camera_offset = { self._camera:get_offset() }
        self._shader_camera_scale = self._camera:get_scale()
    end

    local px, py = self._player:get_predicted_position()
    self._fallspeed = math.min(py / 2000, 1)
    self._fraction = py / 12000
    self._player:set_flow(self._fallspeed)
end

--- @brief
function mn.TitleScreenScene:draw()
    self._blur:bind()
    love.graphics.clear()
    love.graphics.push()
    love.graphics.origin()
    self._shader:bind()
    self._shader:send("elapsed", self._shader_elapsed)
    self._shader:send("camera_offset", self._shader_camera_offset)
    self._shader:send("camera_scale", self._shader_camera_scale)
    self._shader:send("fraction", self._fraction)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    self._shader:unbind()
    love.graphics.pop()
    self._blur:unbind()
    
    self._blur:set_blur_strength(self._fallspeed * 5)
    self._blur:draw()

    self._camera:bind()
    self._player:draw()
    self._platform:draw()
    self._camera:unbind()
end

--- @brief
function mn.TitleScreenScene:get_camera()
    return self._camera
end