require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.keybinding_indicator"
require "common.input_mapping"
require "common.control_indicator"

rt.settings.menu.title_screen_scene = {
    player_max_velocity = 1000,
    --font_path = "assets/fonts/RubikBrokenFax/RubikBrokenFax-Regular.ttf",
    --font_path = "assets/fonts/RubikDoodleTriangles/RubikDoodleTriangles-Regular.ttf",
    --font_path = "assets/fonts/RubikScribble/RubikScribble-Regular.ttf",
    font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
    --font_path = "assets/fonts/RubikBubbles/RubikBubbles-Regular.ttf",
    --font_path = "assets/fonts/RubikMarkerHatch/RubikMarkerHatch-Regular.ttf"
}

--- @class mn.TitleScreenScene
mn.TitleScreenScene = meta.class("TitleScreenScene", rt.Scene)

mn.TitleScreenSceneState = meta.enum("TitleScreenSceneState", {
    IDLE = "IDLE",
    FALLING = "FALLING"
})

local _title_shader_sdf, _title_shader_no_sdf, _background_shader = nil

--- @brief
function mn.TitleScreenScene:instantiate(state)
    self._state = mn.TitleScreenSceneState.IDLE
    self._player = state:get_player()
    self._player:set_is_bubble(false)

    self._camera = rt.Camera()
    self._input = rt.InputSubscriber()
    self._player_unlocked = false

    if _background_shader == nil then
        _background_shader = rt.Shader("menu/title_screen_scene_background.glsl")
    end

    self._shader_elapsed = 0
    self._shader_camera_offset = { 0, 0 }
    self._shader_camera_scale = 1
    self._fallspeed = 0
    self._fraction = 0
    self._player_velocity_x, self._player_velocity_y = -1, -1

    -- setup dummy platform
    self._world = b2.World()
    self._boundaries = {}
    self._reset_position = true

    self._player:move_to_world(self._world)
    self._player:set_gravity(0)
    self._player:set_velocity(self._player_velocity_x, self._player_velocity_y)
    self._player:set_is_bubble(true)
    self._player:set_jump_allowed(true)
    self._player:disable()

    if _title_shader_no_sdf == nil then
        _title_shader_no_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 0 })
    end

    if _title_shader_sdf == nil then
        _title_shader_sdf = rt.Shader("menu/title_screen_scene_label.glsl", { MODE = 1 })
    end

    local translation = rt.Translation.title_screen_scene
    self._control_indicator = rt.ControlIndicator({
        [rt.ControlIndicatorButton.JUMP] = translation.control_indicator_select,
        [rt.ControlIndicatorButton.UP_DOWN] = translation.control_indicator_move
    })
    self._control_indicator:set_use_frame(false)

    local font, font_mono = rt.settings.font.default_large, rt.settings.font.default_mono_large
    self._menu_items = {}
    self._selected_item_i = 1
    for text in range(
        translation.level_select,
        translation.settings,
        translation.credits,
        translation.quit
    ) do
        local item = {
            unselected_label = rt.Label("<o>" .. text .. "</o>", font, font_mono),
            selected_label = rt.Label("<o><b><color=SELECTION>" .. text .. "</color></b></o>", font, font_mono),
        }

        table.insert(self._menu_items, item)
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
            self._player:set_jump_allowed(true)
        end
    end)

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.JUMP then
            self._player:set_gravity(1)
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
    self._control_indicator:realize()
    for item in values(self._menu_items) do
        item.unselected_label:realize()
        item.selected_label:realize()
    end
end

--- @brief
function mn.TitleScreenScene:size_allocate(x, y, width, height)
    local font_size = 0.15 * love.graphics.getHeight()
    self._title_font_scale = rt.Font(font_size, rt.settings.menu.title_screen_scene.font_path)
    self._title_font_scale_scale = font_size / (0.15 * 600)
    local title = rt.Translation.title_screen_scene.title
    self._title_label_no_sdf = love.graphics.newTextBatch(self._title_font_scale:get_native(rt.FontStyle.REGULAR, false), title)
    self._title_label_sdf = love.graphics.newTextBatch(self._title_font_scale:get_native(rt.FontStyle.REGULAR, true), title)
    self._title_w, self._title_h = self._title_font_scale:measure_glyph(title)

    local m = rt.settings.margin_unit
    local outer_margin = 3 * m
    self._title_x = 0 - 0.5 * self._title_w
    self._title_y = 0 - self._title_h - outer_margin

    for boundary in values(self._boundaries) do
        boundary:destroy()
    end

    do
        local scale = self._camera:get_scale_delta()
        local w, h = width / scale, height / scale
        local x, y = 0 - 0.5 * w, 0 - 0.5 * h
        self._boundaries = {
            b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                x, y, x + w, y
            )),

            b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                x + w, y, x + w, y + h
            )),

            b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                x + w, y + h, x, y + h
            )),

            b2.Body(self._world, b2.BodyType.STATIC, 0, 0, b2.Segment(
                x, y + h, x, y
            )),
        }

        for body in values(self._boundaries) do
            body:set_collides_with(rt.settings.player.bounce_collision_group)
            body:set_collision_group(rt.settings.player.bounce_collision_group)
            body:set_use_continuous_collision(true)
            body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
                local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
                local dot_product = current_vx * normal_x + current_vy * normal_y
                self._player_velocity_x = current_vx - 2 * dot_product * normal_x
                self._player_velocity_y = current_vy - 2 * dot_product * normal_y
            end)
        end
    end

    self._player:teleport_to(0, 0)

    self._title_x, self._title_y = math.round(self._title_x), math.round(self._title_y)

    do
        local total_h = 0
        for item in values(self._menu_items) do
            local selected_w, selected_h = item.selected_label:measure()
            local unselected_w, unselected_h = item.unselected_label:measure()
            total_h = total_h + math.max(selected_h, unselected_h)
        end

        local current_y = 2 * m

        local menu_center_x = 0
        for item in values(self._menu_items) do
            local selected_w, selected_h = item.selected_label:measure()
            local unselected_w, unselected_h = item.unselected_label:measure()

            item.selected_label:reformat(menu_center_x - 0.5 * selected_w, current_y, math.huge)
            item.unselected_label:reformat(menu_center_x - 0.5 * unselected_w, current_y, math.huge)
            current_y = current_y + math.max(selected_h, unselected_h)
        end
    end

    local control_w, control_h = self._control_indicator:measure()
    self._control_indicator:reformat(
        0 - 0.5 * width + width - m - control_w,
        0 - 0.5 * height + height - m - control_h,
        control_w, control_h
    )
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

    if self._state == mn.TitleScreenSceneState.IDLE then
        self._camera:set_position(0, 0)
    elseif self._state == mn.TitleScreenSceneState.FALLING then
        self._camera:move_to(self._player:get_position())
    end

    self._camera:update(delta)
    self._player:update(delta)

    local magnitude = 200
    self._player:set_velocity(self._player_velocity_x * magnitude, self._player_velocity_y * magnitude)

    if true then --love.keyboard.isDown("space") then
        self._shader_elapsed = self._shader_elapsed + delta
        self._shader_camera_offset = { self._camera:get_offset() }
        self._shader_camera_scale = self._camera:get_scale()
    end

    if self._player_unlocked then
        local px, py = self._player:get_predicted_position()
        self._fallspeed = math.min(py / 2000, 1)
        self._fraction = py / 12000
        self._player:set_flow(self._fallspeed)
    end

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
    love.graphics.origin()
    local scale = self._camera:get_final_scale() / self._title_font_scale_scale
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
    _title_shader_no_sdf:send("black", _black)
    _title_shader_no_sdf:send("camera_offset", { self._camera:get_offset() })
    _title_shader_no_sdf:send("camera_scale", self._camera:get_scale())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._title_label_no_sdf, self._title_x, self._title_y)
    _title_shader_no_sdf:unbind()
    love.graphics.pop()

    for b in values(self._dbg) do
        b:draw()
    end

    self._camera:bind()
    self._player:draw()

    for i, item in ipairs(self._menu_items) do
        if i == self._selected_item_i then
            item.selected_label:draw()
        else
            item.unselected_label:draw()
        end
    end

    self._control_indicator:draw()

    self._camera:unbind()

end

--- @brief
function mn.TitleScreenScene:get_camera()
    return self._camera
end