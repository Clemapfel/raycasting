require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.blur"
require "common.sdf"

rt.settings.menu.title_screen_scene = {
    player_max_velocity = 1000,
    font_path = "assets/fonts/NotoSans/NotoSans-Bold.ttf"
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

    -- title
    self._font = rt.Font(0.15 * love.graphics.getHeight(), rt.settings.menu.title_screen_scene.font_path)
    self._title_label = rt.Label("<b><o><rainbow>CHROMA DRIFT</rainbow></o></b>", self._font)
    self._title_label_raw = rt.Label("CHROMA DRIFT", self._font)

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
    self._title_label:realize()
    self._title_label_raw:realize()
end

--- @brief
function mn.TitleScreenScene:size_allocate(x, y, width, height)
    self._blur = rt.Blur(width, height)


    local title_w, title_h = self._title_label:measure()
    self._title_label:reformat(0, 0, width)
    self._title_label_raw:reformat(0, 0, width)
    local x_padding = math.min(100, (width - title_w) / 2)
    local y_padding = math.min(100, (height - title_h) / 2)
    local padding = math.min(x_padding, y_padding)
    self._sdf = rt.SDF(title_w + 2 * padding, title_h + 2 * padding)

    self._sdf:bind()
    love.graphics.clear()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(padding, padding)
    self._title_label_raw:draw()
    --love.graphics.rectangle("fill", 50, 50, 600, 200)
    love.graphics.pop()
    self._sdf:unbind()
    self._sdf:compute(true)

    local m = rt.settings.margin_unit
    local outer_margin = 3 * m
    self._title_x = 0 - 0.5 * title_w
    self._title_y = 0 - title_h - outer_margin

    self._title_x, self._title_y = math.round(self._title_x), math.round(self._title_y)
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
    love.graphics.clear()
    love.graphics.push()
    love.graphics.origin()
    --self._shader:bind()
    self._shader:send("elapsed", self._shader_elapsed)
    self._shader:send("camera_offset", self._shader_camera_offset)
    self._shader:send("camera_scale", self._shader_camera_scale)
    self._shader:send("fraction", self._fraction)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    self._shader:unbind()
    love.graphics.pop()

    self._camera:bind()

    love.graphics.push()
    love.graphics.translate(self._title_x, self._title_y)
    self._title_label:draw()
    love.graphics.pop()


    self._player:draw()
    self._platform:draw()
    self._camera:unbind()

    self._sdf:draw()



end

--- @brief
function mn.TitleScreenScene:get_camera()
    return self._camera
end