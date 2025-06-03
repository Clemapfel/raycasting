require "physics.physics"
require "common.camera"
require "common.input_subscriber"
require "common.translation"
require "common.keybinding_indicator"
require "common.input_mapping"
require "common.control_indicator"
require "common.timed_animation"

rt.settings.menu.title_screen_scene = {
    max_velocity = 1500,
    x_damping = 0.98,
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
    TITLE_SCREEN = "TITLE_SCREEN",
    FALLING = "FALLING",
    LEVEL_SELECT = "LEVEL_SELECT"
})

local _title_shader_sdf, _title_shader_no_sdf, _background_shader = nil

--- @brief
function mn.TitleScreenScene:instantiate(state)
    self._state = mn.TitleScreenSceneState.TITLE_SCREEN
    self._player = state:get_player()
    self._player_velocity_x, self._player_velocity_y = -1, -1

    self._camera = rt.Camera()
    self._input = rt.InputSubscriber()

    if _background_shader == nil then
        _background_shader = rt.Shader("menu/title_screen_scene_background.glsl")
    end

    self._shader_elapsed = 0
    self._shader_camera_offset = { 0, 0 }
    self._shader_camera_scale = 1
    self._fallspeed = 0
    self._shader_fraction = 0

    -- setup dummy platform
    self._world = b2.World()
    self._world:set_use_fixed_timestep(false)
    self._boundaries = {}
    self._reset_position = true

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
    self._control_indicator:set_has_frame(false)

    local font, font_mono = rt.settings.font.default_large, rt.settings.font.default_mono_large
    self._menu_items = {}
    self._selected_item_i = 1
    self._n_menu_items = 0
    for text in range(
        translation.level_select,
        translation.settings,
        translation.credits,
        translation.quit
    ) do
        local item = {
            unselected_label = rt.Label("<o>" .. text .. "</o>", font, rt.FontSize.LARGE),
            selected_label = rt.Label("<o><b><color=SELECTION>" .. text .. "</color></b></o>", font, rt.FontSize.LARGE),
        }

        table.insert(self._menu_items, item)
        self._n_menu_items = self._n_menu_items + 1
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP then
            self:_select()
        elseif which == rt.InputAction.UP then
            if self._selected_item_i > 1 then
                self._selected_item_i = self._selected_item_i - 1
            end
        elseif which == rt.InputAction.DOWN then
            if self._selected_item_i < self._n_menu_items then
                self._selected_item_i = self._selected_item_i + 1
            end
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
    local font_size = rt.FontSize.GIGANTIC
    self._title_font_scale = rt.Font(rt.settings.menu.title_screen_scene.font_path)
    self._title_font_scale_scale = rt.Font:get_actual_size(font_size) / (rt.FontSize.GIGANTIC * 600)
    local title = rt.Translation.title_screen_scene.title
    self._title_label_no_sdf = love.graphics.newTextBatch(self._title_font_scale:get_native(font_size, rt.FontStyle.REGULAR, false), title)
    self._title_label_sdf = love.graphics.newTextBatch(self._title_font_scale:get_native(font_size, rt.FontStyle.REGULAR, true), title)

    local native = self._title_font_scale:get_native(font_size)
    self._title_w, self._title_h = native:getWidth(title), native:getHeight()

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

    if self._state == mn.TitleScreenSceneState.TITLE_SCREEN then
        if self._player:get_world() ~= self._world then
            self._player:move_to_world(self._world)
        end

        self._player:disable()
        self._player:teleport_to(0, 0)
        self._player:set_velocity(0, 0)
        self._player:set_gravity(0)
        self._player:set_is_bubble(true)
        self._player:set_jump_allowed(true)
        self._player_velocity_x, self._player_velocity_y = -1, -1
    end
end

--- @brief
function mn.TitleScreenScene:exit()
    self._input:deactivate()
end

--- @brief
function mn.TitleScreenScene:_select()
    if self._selected_item_i == 1 then -- level select
        self._player:set_gravity(1)
        self._player:set_is_bubble(false)

        self:set_state(mn.TitleScreenSceneState.FALLING)
    end
end

--- @brief
function mn.TitleScreenScene:update(delta)
    self._world:update(delta)

    if self._state == mn.TitleScreenSceneState.TITLE_SCREEN then
        self._camera:set_position(0, 0)
        local magnitude = 200
        self._player:set_velocity(self._player_velocity_x * magnitude, self._player_velocity_y * magnitude)
    elseif self._state == mn.TitleScreenSceneState.FALLING then
        local px, py = self._player:get_predicted_position()
        self._fallspeed = math.min(py / 2000, 1)
        self._shader_fraction = py / 2000
        self._player:set_flow(self._fallspeed)

        local vx, vy = self._player:get_velocity()
        local max_velocity = rt.settings.menu.title_screen_scene.max_velocity
        vx = math.min(vx * rt.settings.menu.title_screen_scene.x_damping, max_velocity)
        vy = math.min(vy, max_velocity)
        self._player:set_velocity(vx, vy)

        local x_offset = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(self._shader_fraction) * 1 / 3 * love.graphics.getWidth()
        self._shader_fraction = math.clamp(self._shader_fraction, 0, 1)

        self._camera:move_to(px + x_offset, py)
    end

    self._camera:update(delta)
    self._player:update(delta)

    self._shader_elapsed = self._shader_elapsed + delta
    self._shader_camera_offset = { self._camera:get_offset() }
    self._shader_camera_scale = self._camera:get_scale()
end

local _black =  { rt.Palette.BLACK:unpack() }

--- @brief
function mn.TitleScreenScene:draw()
    love.graphics.clear()

    -- draw background
    love.graphics.push()
    love.graphics.origin()
    _background_shader:bind()
    _background_shader:send("black", _black)
    _background_shader:send("elapsed", self._shader_elapsed)
    _background_shader:send("camera_offset", self._shader_camera_offset)
    _background_shader:send("camera_scale", self._shader_camera_scale)
    _background_shader:send("fraction", self._shader_fraction)
    _background_shader:send("hue", self._player:get_hue())

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    _background_shader:unbind()
    love.graphics.pop()

    -- draw text, affected by camera translation but not scale

    love.graphics.push()
    love.graphics.translate(self._camera:get_offset())
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

    for i, item in ipairs(self._menu_items) do
        if i == self._selected_item_i then
            item.selected_label:draw()
        else
            item.unselected_label:draw()
        end
    end

    self._control_indicator:draw()
    love.graphics.pop()

    self._camera:bind()
    self._player:draw()
    self._camera:unbind()
end

--- @brief
function mn.TitleScreenScene:get_camera()
    return self._camera
end

--- @brief
function mn.TitleScreenScene:set_state(next)
    local before = self._state
    self._state = next

    if next == mn.TitleScreenSceneState.FALLING then
        for boundary in values(self._boundaries) do
            boundary:set_is_sensor(true)
        end
    end
end