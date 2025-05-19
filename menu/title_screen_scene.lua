require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"

rt.settings.menu.title_screen_scene = {
    player_max_velocity = 1000,
    font_path = "assets/fonts/RubikBrokenFax/RubikBrokenFax-Regular.ttf"
}

--- @class mn.TitleScreenScene
mn.TitleScreenScene = meta.class("TitleScreenScene", rt.Scene)

local _title_shader_sdf, _title_shader_no_sdf, _background_shader = nil

--- @brief
function mn.TitleScreenScene:instantiate(state)
    self._state = state
    self._player = state:get_player()
    self._player:set_is_bubble(false)

    self._camera = rt.Camera()
    self._input = rt.InputSubscriber()

    if _background_shader == nil then
        _background_shader = rt.Shader("menu/title_screen_scene_background.glsl")
    end

    self._shader_elapsed = 0
    self._shader_camera_offset = { 0, 0 }
    self._shader_camera_scale = 1
    self._fallspeed = 0

    -- setup dummy platform
    self._world = b2.World()
    local platform_x, platform_y, platform_w, platform_h = 0, self._player:get_radius(), 100, 2
    self._platform = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Rectangle(
        platform_x - platform_w / 2, platform_y,
        platform_w, platform_h
    ))

    self._player:move_to_world(self._world)

    if _title_shader_no_sdf == nil then
        _title_shader_no_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 0 })
    end

    if _title_shader_sdf == nil then
        _title_shader_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 1 })
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then
            _background_shader:recompile()
            self._player:teleport_to(0, 0)
            self._player:set_velocity(0, 0)
            _title_shader_no_sdf:recompile()
            _title_shader_sdf:recompile()
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
    --self._camera:set_bounds(rt.AABB(0 - 0.5 * width, 0 - 0.5 * height, width, height))

    local font_size = 0.15 * love.graphics.getHeight()
    self._font = rt.Font(font_size, rt.settings.menu.title_screen_scene.font_path)
    self._font_scale = font_size / (0.15 * 600)
    local title = rt.Translation.title_screen_scene.title
    self._title_label_no_sdf = love.graphics.newTextBatch(self._font:get_native(rt.FontStyle.REGULAR, false), title)
    self._title_label_sdf = love.graphics.newTextBatch(self._font:get_native(rt.FontStyle.REGULAR, true), title)
    self._title_w, self._title_h = self._font:measure_glyph(title)

    local m = rt.settings.margin_unit
    local outer_margin = 3 * m
    self._title_x = 0 - 0.5 * self._title_w
    self._title_y = 0 - self._title_h - outer_margin

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

local _black =  { rt.Palette.BLACK:unpack() }

--- @brief
function mn.TitleScreenScene:draw()
    love.graphics.clear()
    love.graphics.push()
    love.graphics.origin()
    _background_shader:bind()
    _background_shader:send("black", _black)
    _background_shader:send("elapsed", self._shader_elapsed)
    _background_shader:send("camera_offset", self._shader_camera_offset)
    _background_shader:send("camera_scale", self._shader_camera_scale)
    _background_shader:send("fraction", self._fraction)
    _background_shader:send("hue", self._player:get_hue())

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    _background_shader:unbind()
    love.graphics.pop()

    love.graphics.push()
    local scale = self._camera:get_final_scale() / self._font_scale
    local offset_x, offset_y = self._camera:get_offset()
    local w, h = self._bounds.width, self._bounds.height
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(scale, scale)
    love.graphics.translate(offset_x, offset_y)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    _title_shader_sdf:bind()
    _title_shader_sdf:send("elapsed", self._shader_elapsed)
    _title_shader_sdf:send("black", _black)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._title_label_sdf, self._title_x, self._title_y)
    _title_shader_sdf:unbind()

    _title_shader_no_sdf:bind()
    _title_shader_no_sdf:send("elapsed", self._shader_elapsed)
    _title_shader_no_sdf:send("hue", self._player:get_hue())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._title_label_no_sdf, self._title_x, self._title_y)
    _title_shader_no_sdf:unbind()
    love.graphics.pop()

    self._camera:bind()
    self._player:draw()
    self._platform:draw()
    self._camera:unbind()
end

--- @brief
function mn.TitleScreenScene:get_camera()
    return self._camera
end